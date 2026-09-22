import Foundation

/// Reads the MiniMax China Token Plan quota without refreshing or writing
/// credentials. The `mmx` CLI owns OAuth refresh and config persistence.
enum MiniMaxConnection {
    struct Credential {
        let apiKey: String
    }

    private static let configDirectoryEnvironment = "MMX_CONFIG_DIR"
    private static let apiKeyEnvironment = "MINIMAX_CN_API_KEY"
    private static let endpoint = "https://api.minimaxi.com/v1/token_plan/remains"

    static func fetch() async throws -> ConnectedUsage {
        let credential = try await Task.detached(priority: .utility) {
            try credentialFromEnvironmentOrConfig()
        }.value
        try Task.checkCancellation()
        return try await fetch(credential: credential, send: send)
    }

    static func credential(from data: Data) throws -> Credential {
        guard data.count <= 1_048_576 else { throw ProviderConnectionError.invalidResponse }
        let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty, !trimmed.hasPrefix("{") {
            return try credential(apiKey: trimmed)
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderConnectionError.invalidResponse
        }
        let candidates: [Any?] = [
            object["api_key"], object["apiKey"], object["access_token"], object["accessToken"],
            object["token"], (object["auth"] as? [String: Any])?["api_key"],
            (object["auth"] as? [String: Any])?["access_token"],
            (object["oauth"] as? [String: Any])?["api_key"],
            (object["oauth"] as? [String: Any])?["access_token"]
        ]
        for candidate in candidates {
            if let value = candidate as? String, let credential = try? credential(apiKey: value) {
                return credential
            }
        }
        throw ProviderConnectionError.signIn
    }

    static func fetch(credential: Credential,
                      send: (URLRequest) async throws -> Data,
                      now: Date = Date()) async throws -> ConnectedUsage {
        let usage = try parse(try await send(request(credential: credential)), now: now)
        try Task.checkCancellation()
        return usage
    }

    static func parse(_ data: Data, now: Date = Date()) throws -> ConnectedUsage {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderConnectionError.invalidResponse
        }
        if let response = root["base_resp"] as? [String: Any],
           let status = number(response["status_code"]), status != 0 {
            if Int(status) == 1004 { throw ProviderConnectionError.signIn }
            throw ProviderConnectionError.http(Int(status))
        }

        guard let models = root["model_remains"] as? [[String: Any]],
              let general = models.first(where: { model in
                  let name = model["model_name"] as? String
                  return name == "general" || name?.hasPrefix("MiniMax-M") == true
              })
        else { throw ProviderConnectionError.invalidResponse }

        var limits: [ConnectedLimit] = []
        if let remaining = percentage(general["current_interval_remaining_percent"]) {
            limits.append(ConnectedLimit(id: "fiveHour", label: "5h",
                usedFraction: 1 - remaining,
                resetAt: resetDate(general, durationKey: "remains_time", endKey: "end_time", now: now),
                kind: .session))
        } else if let total = number(general["current_interval_total_count"]),
                  total > 0,
                  let remaining = number(general["current_interval_usage_count"]),
                  remaining >= 0 {
            limits.append(ConnectedLimit(id: "fiveHour", label: "5h",
                usedFraction: max(0, min(1, 1 - remaining / total)),
                resetAt: resetDate(general, durationKey: "remains_time", endKey: "end_time", now: now),
                kind: .session))
        }

        let weeklyStatus = number(general["current_weekly_status"]).map(Int.init)
        if weeklyStatus != 3, let remaining = percentage(general["current_weekly_remaining_percent"]) {
            limits.append(ConnectedLimit(id: "weekly", label: "week",
                usedFraction: 1 - remaining,
                resetAt: resetDate(general, durationKey: "weekly_remains_time", endKey: "weekly_end_time", now: now),
                kind: .weekly))
        }

        guard !limits.isEmpty else { throw ProviderConnectionError.invalidResponse }
        let plan = (root["plan_name"] as? String)
            ?? (root["subscription_type"] as? String)
            ?? (root["plan"] as? String)
        return ConnectedUsage(limits: limits, accountID: "minimax-cn", plan: plan, updatedAt: now)
    }

    private static func credentialFromEnvironmentOrConfig() throws -> Credential {
        let environment = ProcessInfo.processInfo.environment
        if let value = environment[apiKeyEnvironment], let credential = try? credential(apiKey: value) {
            return credential
        }

        let configDirectory = environment[configDirectoryEnvironment]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mmx", isDirectory: true)
        let config = configDirectory.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: config) else { throw ProviderConnectionError.signIn }
        return try credential(from: data)
    }

    private static func credential(apiKey: String) throws -> Credential {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ProviderConnectionError.signIn }
        return Credential(apiKey: value)
    }

    private static func request(credential: Credential) throws -> URLRequest {
        guard let url = URL(string: endpoint) else { throw ProviderConnectionError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let session = URLSession(configuration: .ephemeral, delegate: MiniMaxNoProviderRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ProviderConnectionError.invalidResponse }
        guard response.statusCode == 200 else { throw ProviderConnectionError.http(response.statusCode) }
        guard data.count <= 2_097_152 else { throw ProviderConnectionError.invalidResponse }
        return data
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value.isFinite ? value : nil }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func percentage(_ value: Any?) -> Double? {
        guard let value = number(value), value.isFinite, (0...100).contains(value) else { return nil }
        return value / 100
    }

    private static func resetDate(_ model: [String: Any], durationKey: String,
                                  endKey: String, now: Date) -> Date? {
        if let raw = number(model[endKey]) {
            let seconds = raw > 100_000_000_000 ? raw / 1_000 : raw
            return Date(timeIntervalSince1970: seconds)
        }
        guard let raw = number(model[durationKey]), raw >= 0 else { return nil }
        return now.addingTimeInterval(raw > 100_000 ? raw / 1_000 : raw)
    }
}

private final class MiniMaxNoProviderRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
