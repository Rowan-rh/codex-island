import Foundation
import Combine

@MainActor
final class WeeklyCardHistoryStore: ObservableObject {
    @Published private(set) var buckets: [IslandProvider: [DailyTokenBucket]]?
    @Published private(set) var isLoading = false
    @Published private(set) var partialProviders = Set<IslandProvider>()
    @Published private(set) var saveErrors: [IslandProvider: String] = [:]

    func loadIfNeeded() {
        if buckets == nil { refresh() }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            let result = await Task.detached(priority: .utility) {
                let now = Date()
                let openCodeScan = OpenCodeLogReader.scanResult(lookbackDays: nil)
                let openCode = UsageLedger.shared.retain(openCodeScan.events,
                                                        source: .openCode, now: now, observedAt: now,
                                                        markScanComplete: openCodeScan.completed)
                var partial = Set<IslandProvider>()
                let claude = UsageLedger.shared.retain(ClaudeLogReader.scan(lookbackDays: nil),
                                                       source: .claude, now: now, observedAt: now)
                let codex = UsageLedger.shared.retain(CodexLogReader.scan(lookbackDays: nil),
                                                      source: .codex, now: now, observedAt: now)
                var sources: [(snapshot: UsageLedger.Snapshot, owner: TokenEvent.Provider?)] = [
                    (claude, .claude), (codex, .codex), (openCode, nil)
                ]
                for provider in [IslandProvider.antigravity, .grok] {
                    let scan = provider == .antigravity
                        ? AntigravityLogReader.scan(lookbackDays: nil, now: now)
                        : GrokLogReader.scan(lookbackDays: nil, now: now)
                    let saved = UsageLedger.shared.retain(scan.events,
                                                          source: provider == .antigravity ? .antigravity : .grok,
                                                          now: now, observedAt: now)
                    sources.append((saved, provider.costProvider))
                    if scan.notice?.hasPrefix("Some") == true { partial.insert(provider) }
                }
                // Events are credited by model (a MiniMax call made through
                // Claude Code lands on MiniMax); whole-day recovered totals
                // stay with the tool that recorded them.
                let allEvents = sources.flatMap(\.snapshot.events)
                let allDays = sources.flatMap(\.snapshot.historicalDays)
                var buckets: [IslandProvider: [DailyTokenBucket]] = [:]
                var saveErrors: [IslandProvider: String] = [:]
                for provider in IslandProvider.allCases {
                    let target = provider.costProvider
                    buckets[provider] = CostSummary.summarize(
                        events: allEvents.filter { $0.provider == target },
                        now: now, includeAllHistory: true,
                        historicalDays: allDays.filter { $0.provider == target },
                        recordedEvents: allEvents.filter { $0.recordingProvider == target || $0.provider == target }
                    ).dailyTokens
                    saveErrors[provider] = sources.filter { source in
                        source.owner == nil || source.owner == target
                            || source.snapshot.events.contains { $0.provider == target }
                    }.compactMap(\.snapshot.saveError).first
                }
                return (buckets, partial, saveErrors)
            }.value
            buckets = result.0
            partialProviders = result.1
            saveErrors = result.2
            isLoading = false
        }
    }
}
