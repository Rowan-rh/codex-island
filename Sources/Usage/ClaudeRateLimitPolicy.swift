import Foundation

enum ClaudeRateLimitPolicy {
    static let cooldownDuration: TimeInterval = 900

    static func isRateLimited(_ usage: AppUsage) -> Bool {
        usage.fiveHour.error == ClaudeCredentials.rateLimitedMessage
            && usage.weekly.error == ClaudeCredentials.rateLimitedMessage
    }

    static func cooldownDeadline(for usage: AppUsage, now: Date) -> Date? {
        isRateLimited(usage) ? now.addingTimeInterval(cooldownDuration) : nil
    }

    static func shouldFetch(cooldownUntil: Date?, now: Date) -> Bool {
        cooldownUntil.map { now >= $0 } ?? true
    }
}
