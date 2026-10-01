import Foundation

@main
struct TokenUsageDetailsTests {
    static func expect(_ result: Bool, _ label: String) {
        guard result else { print("FAIL \(label)"); exit(1) }
        print("PASS \(label)")
    }

    static func main() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = start.addingTimeInterval(2 * 3600)
        let events = [
            TokenEvent(provider: .claude, timestamp: start.addingTimeInterval(60), model: "claude-sonnet-4-6-20260101",
                       inputTokens: 100, outputTokens: 20, cacheCreationTokens: 30, cacheReadTokens: 150,
                       generationDurationSeconds: 2),
            TokenEvent(provider: .claude, timestamp: start.addingTimeInterval(120), model: "claude-sonnet-4-6",
                       inputTokens: 50, outputTokens: 10, cacheCreationTokens: 0, cacheReadTokens: 50,
                       generationDurationSeconds: 3),
            TokenEvent(provider: .codex, timestamp: end.addingTimeInterval(1), model: "gpt-5.4",
                       inputTokens: 9_999, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0),
        ]
        let summary = TokenUsageDetails.summarize(events: events, from: start, through: end)
        expect(summary.rows.count == 1, "filters events to the selected interval and groups canonical models")
        expect(summary.callCount == 2 && summary.totalTokens == 410, "sums calls and all token categories")
        expect(summary.rows[0].inputTokens == 150 && summary.rows[0].outputTokens == 30,
               "keeps input and output metrics separate")
        expect(abs((summary.tokensPerSecond ?? 0) - 6) < 0.000001,
               "computes output tokens per measured generation second")
        expect(abs(summary.cacheHitRate - (200.0 / 380.0)) < 0.0001,
               "computes cache hits against cacheable prompt tokens")
        let unavailable = TokenUsageDetails.summarize(
            events: [events[2]], from: start, through: end.addingTimeInterval(2))
        expect(unavailable.tokensPerSecond == nil, "leaves generation rate unavailable without measured duration")
    }
}
