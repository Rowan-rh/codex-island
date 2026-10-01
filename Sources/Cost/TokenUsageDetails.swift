import Foundation

struct TokenUsageDetailRow: Identifiable {
    let provider: TokenEvent.Provider
    let model: String
    let displayName: String
    let callCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let tokensPerSecond: Double

    var id: String { "\(provider.rawValue):\(model)" }
    var totalTokens: Int { inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens }
    var promptTokens: Int { inputTokens + cacheCreationTokens + cacheReadTokens }
    var cacheHitRate: Double {
        promptTokens > 0 ? Double(cacheReadTokens) / Double(promptTokens) : 0
    }
}

struct TokenUsageDetailSummary {
    let rows: [TokenUsageDetailRow]
    let start: Date
    let end: Date

    var callCount: Int { rows.reduce(0) { $0 + $1.callCount } }
    var totalTokens: Int { rows.reduce(0) { $0 + $1.totalTokens } }
    var cacheReadTokens: Int { rows.reduce(0) { $0 + $1.cacheReadTokens } }
    var promptTokens: Int { rows.reduce(0) { $0 + $1.promptTokens } }
    var tokensPerSecond: Double {
        totalTokens > 0 ? Double(totalTokens) / max(end.timeIntervalSince(start), 1) : 0
    }
    var cacheHitRate: Double {
        promptTokens > 0 ? Double(cacheReadTokens) / Double(promptTokens) : 0
    }
}

enum TokenUsageDetails {
    private struct Accumulator {
        var callCount = 0
        var inputTokens = 0
        var outputTokens = 0
        var cacheCreationTokens = 0
        var cacheReadTokens = 0
    }

    static func summarize(events: [TokenEvent], from start: Date, through end: Date) -> TokenUsageDetailSummary {
        guard end > start else { return TokenUsageDetailSummary(rows: [], start: start, end: end) }
        var buckets: [String: (TokenEvent.Provider, String, Accumulator)] = [:]

        for rawEvent in events where rawEvent.timestamp >= start && rawEvent.timestamp <= end {
            let event = rawEvent.attributedByModel()
            let model = Pricing.canonicalModelName(event.model)
            let key = "\(event.provider.rawValue):\(model)"
            var bucket = buckets[key]?.2 ?? Accumulator()
            bucket.callCount += 1
            bucket.inputTokens += event.inputTokens
            bucket.outputTokens += event.outputTokens
            bucket.cacheCreationTokens += event.cacheCreationTokens
            bucket.cacheReadTokens += event.cacheReadTokens
            buckets[key] = (event.provider, model, bucket)
        }

        let seconds = max(end.timeIntervalSince(start), 1)
        let rows = buckets.values.map { provider, model, bucket in
            let total = bucket.inputTokens + bucket.outputTokens
                + bucket.cacheCreationTokens + bucket.cacheReadTokens
            return TokenUsageDetailRow(
                provider: provider,
                model: model,
                displayName: displayName(for: model),
                callCount: bucket.callCount,
                inputTokens: bucket.inputTokens,
                outputTokens: bucket.outputTokens,
                cacheCreationTokens: bucket.cacheCreationTokens,
                cacheReadTokens: bucket.cacheReadTokens,
                tokensPerSecond: Double(total) / seconds
            )
        }
        .sorted {
            if $0.totalTokens != $1.totalTokens { return $0.totalTokens > $1.totalTokens }
            if $0.provider != $1.provider { return $0.provider.rawValue < $1.provider.rawValue }
            return $0.model < $1.model
        }
        return TokenUsageDetailSummary(rows: rows, start: start, end: end)
    }

    private static func displayName(for canonical: String) -> String {
        if canonical.hasPrefix("claude-") {
            let trimmed = String(canonical.dropFirst("claude-".count))
            guard let dash = trimmed.firstIndex(of: "-") else { return trimmed.capitalized }
            let family = String(trimmed[..<dash]).capitalized
            let version = trimmed[trimmed.index(after: dash)...].replacingOccurrences(of: "-", with: ".")
            return "\(family) \(version)"
        }
        if canonical.hasPrefix("gpt-") {
            return canonical.replacingOccurrences(of: "gpt-", with: "GPT-")
        }
        if canonical.first == "o", canonical.dropFirst().first?.isNumber == true {
            return canonical.prefix(1).uppercased() + canonical.dropFirst()
        }
        return canonical.split(separator: "/").last.map(String.init) ?? canonical
    }

}
