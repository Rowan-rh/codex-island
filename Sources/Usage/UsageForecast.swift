import Foundation

/// Projects when a rate-limit window runs out at its recent pace, from the
/// readings `UsageHistoryStore` already records. Never estimates without
/// enough evidence: a thin or stale series yields `.unknown`.
enum UsageForecast: Equatable {
    case runsOut(at: Date)
    case lastsUntilReset
    case unknown

    /// Shortest span of readings that may set a pace. Below this, one poll's
    /// jitter would dominate the slope.
    static let minimumSpan: TimeInterval = 15 * 60
    /// A drop larger than this between consecutive readings marks a reset;
    /// earlier readings belong to the previous cycle.
    static let resetDrop = 0.02

    static func project(samples: [UsageSample], current: WindowUsage, now: Date = Date()) -> UsageForecast {
        guard current.error == nil, current.usedPercent < 0.999,
              let resetAt = current.resetAt, resetAt > now else { return .unknown }

        // Long windows (weekly) move in bursts; a day of readings keeps one
        // busy hour from reading as the weekly pace.
        let lookback: TimeInterval = resetAt.timeIntervalSince(now) > 86400 ? 86400 : 3600
        var cycle: [UsageSample] = []
        for sample in samples.reversed() where sample.at <= now {
            if let newer = cycle.last, sample.used - newer.used > resetDrop { break }
            if now.timeIntervalSince(sample.at) > lookback { break }
            cycle.append(sample)
        }
        guard let latest = cycle.first, let earliest = cycle.last,
              latest.at.timeIntervalSince(earliest.at) >= minimumSpan else { return .unknown }

        let perSecond = (latest.used - earliest.used) / latest.at.timeIntervalSince(earliest.at)
        guard perSecond > 0 else { return .lastsUntilReset }
        let exhaustion = latest.at.addingTimeInterval((1 - latest.used) / perSecond)
        return exhaustion < resetAt ? .runsOut(at: max(now, exhaustion)) : .lastsUntilReset
    }
}
