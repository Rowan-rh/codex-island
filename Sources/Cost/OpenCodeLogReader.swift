import Foundation
import SQLite3

/// Walks local OpenCode session storage and emits TokenEvents for every
/// assistant message that recorded token usage.
///
/// OpenCode stores messages in two formats:
///   - SQLite databases at ~/.local/share/opencode/opencode*.db (1.2+)
///   - Legacy JSON files at ~/.local/share/opencode/storage/message/ses_*/msg_*.json
///
/// Both sources are read and deduplicated by message ID. Token data maps to
/// the shared TokenEvent structure used by CostSummary and Pricing. Provider
/// is inferred from the message's `providerID` field: "anthropic" → .claude,
/// "openai" → .codex, "deepseek" → .deepseek, "minimax"/"minimax-cn" → .minimaxCN,
/// and Jev/TypeSafe IDs → .jev.
enum OpenCodeLogReader {
    struct ScanResult {
        let events: [TokenEvent]
        let completed: Bool
    }

    static func provider(for providerID: String) -> TokenEvent.Provider? {
        switch providerID {
        case "anthropic": return .claude
        case "openai": return .codex
        case "deepseek": return .deepseek
        case "minimax", "minimax-cn", "minimaxi": return .minimaxCN
        case "jev", "jev-agent", "typesafe", "typesafe-ai": return .jev
        default: return nil
        }
    }

    // MARK: - Public

    static func scan(lookbackDays: Int? = 30) -> [TokenEvent] {
        scanResult(lookbackDays: lookbackDays).events
    }

    static func scanResult(lookbackDays: Int? = 30) -> ScanResult {
        let cutoff = lookbackDays.map { Date().addingTimeInterval(-Double($0) * 86400) } ?? .distantPast
        var seenIds = Set<String>()
        var seenFingerprints = Set<String>()
        var out: [TokenEvent] = []
        var completed = true

        let emit: (ParsedEvent) -> Void = { ev in
            guard ev.timestamp >= cutoff else { return }
            if !ev.messageId.isEmpty {
                guard seenIds.insert(ev.messageId).inserted else { return }
            }
            // Forked subagent sessions can log the same API call under
            // different message IDs. Deduplicate by content fingerprint
            // so cost totals match tokscale's hash-based dedup.
            let fp = "\(Int64(ev.timestamp.timeIntervalSince1970 * 1000)):\(ev.model):\(ev.inputTokens):\(ev.outputTokens):\(ev.cacheReadTokens):\(ev.cacheCreationTokens)"
            guard seenFingerprints.insert(fp).inserted else { return }
            guard var token = ev.tokenEvent() else { return }
            token.recordID = ev.messageId.isEmpty ? "fingerprint:\(fp)" : ev.messageId
            token.recordAliases = ["fingerprint:\(fp)"]
            out.append(token)
        }

        // SQLite databases take precedence (OpenCode 1.2+).
        let databases = discoverDatabases()
        completed = completed && databases.completed
        for dbPath in databases.urls {
            guard let events = queryDatabase(at: dbPath, cutoff: cutoff) else {
                completed = false
                continue
            }
            for ev in events {
                emit(ev)
            }
        }

        // Supplement with legacy JSON files for pre-migration messages.
        let legacy = scanLegacyJSON(cutoff: cutoff)
        completed = completed && legacy.completed
        for ev in legacy.events {
            emit(ev)
        }

        return ScanResult(events: out, completed: completed)
    }

    // MARK: - Path resolution

    private static func dataRoot() -> URL {
        let xdgData: String
        if let env = ProcessInfo.processInfo.environment["XDG_DATA_HOME"], !env.isEmpty {
            xdgData = env
        } else {
            xdgData = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/share").path
        }
        return URL(fileURLWithPath: xdgData)
            .appendingPathComponent("opencode", isDirectory: true)
    }

    private static func legacyRoot() -> URL {
        dataRoot().appendingPathComponent("storage/message", isDirectory: true)
    }

    // MARK: - SQLite (OpenCode 1.2+)

    private static func discoverDatabases() -> (urls: [URL], completed: Bool) {
        let root = dataRoot()
        guard FileManager.default.fileExists(atPath: root.path) else { return ([], true) }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else { return ([], false) }
        return (contents.filter {
            $0.lastPathComponent.hasPrefix("opencode") &&
            $0.pathExtension == "db"
        }, true)
    }

    private static func queryDatabase(at url: URL, cutoff: Date) -> [ParsedEvent]? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(
            url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil
        ) == SQLITE_OK, let db = db else { return nil }
        defer { sqlite3_close(db) }

        let cutoffMs = Int64(cutoff.timeIntervalSince1970 * 1000)
        let sql = """
            SELECT m.id, m.data
            FROM message m
            WHERE json_extract(m.data, '$.role') = 'assistant'
              AND json_extract(m.data, '$.tokens') IS NOT NULL
              AND CAST(json_extract(m.data, '$.time.created') AS INTEGER) >= ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt = stmt else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, cutoffMs)

        var out: [ParsedEvent] = []
        while true {
            let status = sqlite3_step(stmt)
            if status == SQLITE_DONE { return out }
            guard status == SQLITE_ROW else { return nil }
            guard let idPtr = sqlite3_column_text(stmt, 0),
                  let dataPtr = sqlite3_column_text(stmt, 1) else { continue }
            let messageId = String(cString: idPtr)
            let jsonData = Data(String(cString: dataPtr).utf8)

            guard let msg = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let ev = parseMessage(msg, messageId: messageId) else { continue }
            out.append(ev)
        }
    }

    // MARK: - Legacy JSON

    private static func scanLegacyJSON(cutoff: Date) -> (events: [ParsedEvent], completed: Bool) {
        let root = legacyRoot()
        guard FileManager.default.fileExists(atPath: root.path) else { return ([], true) }

        var cache = LogParseCache.loadCache(
            filename: "opencode-parse-cache.v1.json",
            version: cacheVersion,
            eventType: CachedEvent.self
        )
        var visited = Set<String>()
        var cacheChanged = false
        var out: [ParsedEvent] = []
        var completed = true

        guard let files = jsonFiles(under: root, modifiedAfter: cutoff) else { return ([], false) }
        for entry in files {
            let path = entry.url.path
            visited.insert(path)

            let events: [CachedEvent]
            if let hit = cache.files[path],
               hit.matches(mtime: entry.mtime, size: entry.size) {
                events = hit.events
            } else {
                let parsed = parseJSONFile(at: entry.url)
                guard let parsed else {
                    completed = false
                    continue
                }
                events = parsed
                cache.files[path] = LogParseCache.CachedFile(
                    mtime: entry.mtime, size: entry.size, events: events
                )
                cacheChanged = true
            }
            for ev in events where ev.timestamp >= cutoff {
                out.append(ev.parsed())
            }
        }

        let preCount = cache.files.count
        cache.files = cache.files.filter { visited.contains($0.key) }
        if cache.files.count != preCount { cacheChanged = true }
        if cacheChanged { LogParseCache.saveCache(cache, filename: "opencode-parse-cache.v1.json") }

        return (out, completed)
    }

    /// Mirror of `LogParseCache.jsonlFiles` for `.json` files.
    private static func jsonFiles(
        under root: URL,
        modifiedAfter cutoff: Date
    ) -> [LogParseCache.FileEntry]? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isRegularFileKey, .contentModificationDateKey, .fileSizeKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        var hits: [LogParseCache.FileEntry] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "json" else { continue }
            let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey, .contentModificationDateKey, .fileSizeKey
            ])
            guard values?.isRegularFile == true,
                  let mtime = values?.contentModificationDate,
                  let size = values?.fileSize else { continue }
            if mtime < cutoff { continue }
            hits.append(LogParseCache.FileEntry(url: url, mtime: mtime, size: Int64(size)))
        }
        return hits
    }

    private static func parseJSONFile(at url: URL) -> [CachedEvent]? {
        guard let data = try? Data(contentsOf: url),
              let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        guard let ev = parseMessage(msg, messageId: url.deletingPathExtension().lastPathComponent) else {
            return []
        }
        return [CachedEvent(
            messageId: ev.messageId,
            timestamp: ev.timestamp,
            model: ev.model,
            provider: ev.provider,
            inputTokens: ev.inputTokens,
            outputTokens: ev.outputTokens,
            cacheCreationTokens: ev.cacheCreationTokens,
            cacheReadTokens: ev.cacheReadTokens
        )]
    }

    // MARK: - Shared parsing

    /// Extracts token usage from an OpenCode message dictionary. Returns nil
    /// for non-assistant messages, zero-usage entries, and unparseable blobs.
    private static func parseMessage(
        _ msg: [String: Any],
        messageId: String
    ) -> ParsedEvent? {
        guard (msg["role"] as? String) == "assistant",
              let tokens = msg["tokens"] as? [String: Any],
              let time = msg["time"] as? [String: Any],
              let created = time["created"] as? Double
        else { return nil }

        let model = (msg["modelID"] as? String) ?? "unknown"
        guard let provider = msg["providerID"] as? String else { return nil }

        let cache = tokens["cache"] as? [String: Any]
        let input = (tokens["input"] as? Int) ?? 0
        let output = (tokens["output"] as? Int) ?? 0
        let reasoning = (tokens["reasoning"] as? Int) ?? 0
        let cacheRead = (cache?["read"] as? Int) ?? 0
        let cacheWrite = (cache?["write"] as? Int) ?? 0

        if input == 0 && output == 0 && reasoning == 0
            && cacheRead == 0 && cacheWrite == 0 { return nil }

        return ParsedEvent(
            messageId: messageId,
            // OpenCode's time.created is milliseconds since epoch.
            timestamp: Date(timeIntervalSince1970: created / 1000.0),
            model: model,
            provider: provider,
            inputTokens: input,
            // Reasoning tokens are billed at the output rate (tokscale parity).
            outputTokens: output + reasoning,
            cacheCreationTokens: cacheWrite,
            cacheReadTokens: cacheRead
        )
    }

    // MARK: - Internal types

    private struct ParsedEvent {
        let messageId: String
        let timestamp: Date
        let model: String
        let provider: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationTokens: Int
        let cacheReadTokens: Int

        func tokenEvent() -> TokenEvent? {
            guard let mapped = OpenCodeLogReader.provider(for: provider) else { return nil }
            return TokenEvent(
                provider: mapped,
                timestamp: timestamp,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreationTokens,
                cacheReadTokens: cacheReadTokens
            )
        }
    }

    // MARK: - Per-file cache

    private static let cacheVersion = 1

    private struct CachedEvent: Codable {
        let messageId: String
        let timestamp: Date
        let model: String
        let provider: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationTokens: Int
        let cacheReadTokens: Int

        func parsed() -> ParsedEvent {
            ParsedEvent(
                messageId: messageId,
                timestamp: timestamp,
                model: model,
                provider: provider,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreationTokens,
                cacheReadTokens: cacheReadTokens
            )
        }
    }
}
