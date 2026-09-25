import Foundation

enum WeeklyCardMetric: String, CaseIterable, Identifiable {
    case apiValue, tokens
    var id: String { rawValue }
    var title: String { L10n.tr(self == .apiValue ? "API value" : "Tokens") }
}

struct WeeklyValueMilestone {
    let minimumDollars: Double
    let label: String
    let key: String

    private static let tiers: [Self] = [
        .init(minimumDollars: 1_000_000_000, label: "$1B", key: "billions"),
        .init(minimumDollars: 100_000_000, label: "$100M", key: "nineFigures"),
        .init(minimumDollars: 10_000_000, label: "$10M", key: "eightFigures"),
        .init(minimumDollars: 1_000_000, label: "$1M", key: "sevenFigures"),
        .init(minimumDollars: 100_000, label: "$100K", key: "sixFigures"),
        .init(minimumDollars: 10_000, label: "$10K", key: "fiveFigures"),
        .init(minimumDollars: 1_000, label: "$1K", key: "fourFigures"),
        .init(minimumDollars: 100, label: "$100", key: "threeFigures")
    ]

    static func earned(dollars: Double) -> Self? {
        guard dollars.isFinite else { return nil }
        return tiers.first { dollars >= $0.minimumDollars }
    }

    func headline(for period: WeeklyCardPeriod) -> String {
        L10n.tr("Weekly milestone.\(key).\(period.rawValue)")
    }
}

enum WeeklyCardPeriod: String, CaseIterable, Identifiable {
    case lastSevenDays, lastThirtyDays, lastThreeMonths, thisYear, allTime

    var id: String { rawValue }
    var title: String {
        switch self {
        case .lastSevenDays: return "Last 7 days"
        case .lastThirtyDays: return "Last 30 days"
        case .lastThreeMonths: return "Last 3 months"
        case .thisYear: return "This year"
        case .allTime: return "All time"
        }
    }

    var tokenHeadline: String {
        L10n.tr(tokenHeadlineKey)
    }

    var valueQualifier: String {
        L10n.tr(valueQualifierKey)
    }

    var tokenCallToAction: String {
        L10n.tr(tokenCallToActionKey)
    }

    private var tokenHeadlineKey: String {
        switch self {
        case .lastSevenDays: "My week with AI."
        case .lastThirtyDays: "30 days with AI."
        case .lastThreeMonths: "Three months with AI."
        case .thisYear: "My year with AI."
        case .allTime: "My AI journey."
        }
    }

    private var valueQualifierKey: String {
        switch self {
        case .lastSevenDays: "In just 7 days."
        case .lastThirtyDays: "In just 30 days."
        case .lastThreeMonths: "In just 3 months."
        case .thisYear: "This year so far."
        case .allTime: "All time."
        }
    }

    private var tokenCallToActionKey: String {
        switch self {
        case .lastSevenDays: "Your week. Your card."
        case .lastThirtyDays: "Your 30 days. Your card."
        case .lastThreeMonths, .allTime: "Your AI. Your card."
        case .thisYear: "Your year. Your card."
        }
    }

    func interval(now: Date, calendar: Calendar, earliestRecord: Date? = nil) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let start: Date
        switch self {
        case .lastSevenDays:
            start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .lastThirtyDays:
            start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        case .lastThreeMonths:
            start = calendar.date(byAdding: .month, value: -3, to: end) ?? today
        case .thisYear:
            start = calendar.dateInterval(of: .year, for: today)?.start ?? today
        case .allTime:
            start = min(today, calendar.startOfDay(for: earliestRecord ?? today))
        }
        return DateInterval(start: start, end: end)
    }

    func needsExtendedHistory(now: Date, calendar: Calendar) -> Bool {
        if self == .allTime { return true }
        guard self == .lastThirtyDays || self == .lastThreeMonths else { return false }
        let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
        return interval(now: now, calendar: calendar).start < yearStart
    }
}

struct WeeklyUsageSnapshot {
    struct Day: Identifiable {
        let date: Date
        let tokens: [IslandProvider: Int]
        let dollars: [IslandProvider: Double]
        var id: Date { date }
        var total: Int { tokens.values.reduce(0, +) }
        var totalDollars: Double { dollars.values.reduce(0, +) }

        func value(for provider: IslandProvider, metric: WeeklyCardMetric) -> Double {
            metric == .apiValue ? dollars[provider] ?? 0 : Double(tokens[provider] ?? 0)
        }
    }

    struct ProviderTotal: Identifiable {
        let provider: IslandProvider
        let tokens: Int
        let dollars: Double
        let unpricedTokens: Int
        var id: IslandProvider { provider }
    }

    let period: WeeklyCardPeriod
    let interval: DateInterval
    let days: [Day]
    let providers: [ProviderTotal]
    let calendar: Calendar
    let isDemo: Bool
    let hasPartialRecords: Bool
    let recoveredTokens: Int

    var totalTokens: Int { providers.reduce(0) { $0 + $1.tokens } }
    var totalDollars: Double { providers.reduce(0) { $0 + $1.dollars } }
    var valueMilestone: WeeklyValueMilestone? { .earned(dollars: totalDollars) }
    var valueHeadline: String { valueMilestone?.headline(for: period) ?? period.tokenHeadline }
    var valueChallenge: String {
        L10n.tr(valueMilestone == nil ? "What does yours look like?" : "Can you top this?")
    }
    var hasPartialPricing: Bool { providers.contains { $0.unpricedTokens > 0 } }
    var hasRecoveredHistory: Bool { recoveredTokens > 0 }
    var hasPricedUsage: Bool { providers.contains { $0.tokens > $0.unpricedTokens } }
    var valueSuffix: String { hasPartialPricing || hasPartialRecords ? "+" : "" }
    var activeDays: Int { days.filter { $0.total > 0 }.count }
    var activityLabel: String {
        L10n.tr(activeDays == 1 ? "%d active day" : "%d active days", activeDays)
    }
    var tokenLabel: String {
        let count = Self.compactTokens(totalTokens)
        return L10n.tr(totalTokens == 1 ? "%@ token" : "%@ tokens", "\(count.value)\(count.unit)")
    }
    var durationLabel: String { L10n.tr(days.count == 1 ? "%d day" : "%d days", days.count) }
    var peakDay: Day? { days.filter { $0.total > 0 }.max { $0.total < $1.total } }

    static func make(
        buckets: [IslandProvider: [DailyTokenBucket]],
        included: Set<IslandProvider> = Set(IslandProvider.allCases),
        period: WeeklyCardPeriod = .lastSevenDays,
        now: Date = Date(),
        calendar: Calendar = .current,
        isDemo: Bool = false,
        hasPartialRecords: Bool = false
    ) -> WeeklyUsageSnapshot {
        let earliestRecord = included.flatMap { buckets[$0] ?? [] }
            .filter { $0.tokens > 0 && $0.dayStart <= now }.map(\.dayStart).min()
        let interval = period.interval(now: now, calendar: calendar, earliestRecord: earliestRecord)
        var totals: [Date: [IslandProvider: Int]] = [:]
        var dollars: [Date: [IslandProvider: Double]] = [:]
        var unpriced: [IslandProvider: Int] = [:]
        var recoveredTokens = 0
        for provider in IslandProvider.allCases where included.contains(provider) {
            for bucket in buckets[provider] ?? [] {
                let day = calendar.startOfDay(for: bucket.dayStart)
                guard day >= interval.start, day < interval.end, day <= now else { continue }
                let tokens = max(0, bucket.tokens)
                recoveredTokens += min(tokens, max(0, bucket.recoveredTokens ?? 0))
                totals[day, default: [:]][provider, default: 0] += tokens
                if let amount = bucket.dollars, amount.isFinite, amount >= 0 {
                    dollars[day, default: [:]][provider, default: 0] += amount
                    unpriced[provider, default: 0] += min(tokens, max(0, bucket.unpricedTokens ?? 0))
                } else {
                    unpriced[provider, default: 0] += tokens
                }
            }
        }
        let dayCount = max(1, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
        let days = (0..<dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: interval.start) ?? interval.start
            return Day(date: date, tokens: totals[date] ?? [:], dollars: dollars[date] ?? [:])
        }
        let providers = IslandProvider.allCases.compactMap { provider -> ProviderTotal? in
            let tokens = days.reduce(0) { $0 + ($1.tokens[provider] ?? 0) }
            return tokens > 0 ? ProviderTotal(provider: provider, tokens: tokens,
                                               dollars: days.reduce(0) { $0 + ($1.dollars[provider] ?? 0) },
                                               unpricedTokens: unpriced[provider] ?? 0) : nil
        }.sorted {
            if $0.tokens == $1.tokens { return $0.provider.rawValue < $1.provider.rawValue }
            return $0.tokens > $1.tokens
        }
        return WeeklyUsageSnapshot(period: period, interval: interval, days: days, providers: providers,
                                   calendar: calendar, isDemo: isDemo,
                                   hasPartialRecords: hasPartialRecords, recoveredTokens: recoveredTokens)
    }

    var dateLabel: String {
        let end = days.last?.date ?? interval.start
        if days.count == 1 { return dateText(end, format: "MMM d, yyyy") }
        let sameYear = calendar.component(.year, from: interval.start) == calendar.component(.year, from: end)
        let startText = dateText(interval.start, format: sameYear ? "MMM d" : "MMM d, yyyy")
        return "\(startText) – \(dateText(end, format: "MMM d, yyyy"))"
    }

    var filenameDate: String { dateText(interval.start, format: "yyyy-MM-dd") }

    func dateText(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = format == "yyyy-MM-dd"
            ? Locale(identifier: "en_US_POSIX") : AppLanguageResolver.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        switch format {
        case "yyyy-MM-dd": formatter.dateFormat = format
        case "MMM d, yyyy": formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        case "MMM d": formatter.setLocalizedDateFormatFromTemplate("MMMd")
        case "EEE": formatter.setLocalizedDateFormatFromTemplate("EEE")
        case "MMM yy": formatter.setLocalizedDateFormatFromTemplate("yMMM")
        default: formatter.dateFormat = format
        }
        return formatter.string(from: date)
    }

    func rankedProviders(for metric: WeeklyCardMetric) -> [ProviderTotal] {
        guard metric == .apiValue else { return providers }
        return providers.sorted {
            if $0.dollars == $1.dollars { return $0.provider.rawValue < $1.provider.rawValue }
            return $0.dollars > $1.dollars
        }
    }

    func cumulativeValues(for provider: IslandProvider, metric: WeeklyCardMetric) -> [Double] {
        var total = 0.0
        return [0] + days.map { day in
            total += day.value(for: provider, metric: metric)
            return total
        }
    }

    var chartLabelDayIndices: [Int] {
        if days.count <= 7 { return Array(days.indices) }
        return (1...5).map { max(0, Int((Double(days.count) * Double($0) / 5).rounded()) - 1) }
    }

    var chartPointIndices: [Int] {
        guard days.count > 31 else { return Array(0...days.count) }
        let step = max(1, Int(ceil(Double(days.count) / 60)))
        return Set([0, days.count] + Array(stride(from: step, to: days.count, by: step))
            + chartLabelDayIndices.map { $0 + 1 }).sorted()
    }

    func chartLabel(for day: Day) -> String {
        let format = days.count <= 7 ? "EEE" : days.count <= 366 ? "MMM d" : "MMM yy"
        return dateText(day.date, format: format).uppercased()
    }

    func shareText(metric: WeeklyCardMetric = .tokens) -> String {
        let stack = providers.map(\.provider.name).joined(separator: " + ")
        let caveats = [
            hasPartialRecords ? L10n.tr("Some local records are missing.") : nil,
            hasRecoveredHistory ? L10n.tr("Includes recovered daily totals on their original dates.") : nil
        ].compactMap { $0 }.joined(separator: " ")
        if metric == .apiValue {
            let pricing = hasPartialPricing ? L10n.tr("Some tokens have no known price.") : nil
            let timeframe = period == .lastThreeMonths
                ? L10n.tr("over the last 3 months")
                : L10n.tr("during %@", durationLabel)
            let demo = isDemo ? L10n.tr("Demo: ") : ""
            let notes = ([L10n.tr("API-rate estimate in USD, not a bill. Tokens include cache."),
                          caveats, pricing].compactMap { $0 }.filter { !$0.isEmpty }).joined(separator: " ")
            return """
            \(demo)\(valueHeadline) \(L10n.tr("My AI usage: %@ at API rates %@.", Self.money(totalDollars) + valueSuffix, timeframe))
            \(L10n.tr("%@ · %@ · %@", tokenLabel, activityLabel, stack))
            \(dateLabel)
            \(notes)

            \(valueChallenge)
            https://codexisland.com
            """
        }
        let demo = isDemo ? L10n.tr("Demo: ") : ""
        let notes = ([L10n.tr("Includes cache tokens."), caveats].filter { !$0.isEmpty }).joined(separator: " ")
        let closing = L10n.tr(period == .lastSevenDays
            ? "What does your week look like?" : "What does your AI usage look like?")
        return """
        \(demo)\(period.tokenHeadline) \(L10n.tr("%@ across %@ in %@.", tokenLabel, activityLabel, durationLabel))
        \(stack)
        \(dateLabel) · \(notes)

        \(closing)
        \(L10n.tr("Make your card with CodexIsland → %@", "https://codexisland.com"))
        """
    }

    static func money(_ amount: Double, cents: Bool = true) -> String {
        if cents && amount > 0 && amount < 0.01 { return "<$0.01" }
        let formatter = NumberFormatter()
        formatter.locale = AppLanguageResolver.locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = cents ? 2 : 0
        formatter.maximumFractionDigits = cents ? 2 : 0
        let precision = cents ? 100.0 : 1.0
        let rounded = (amount * precision).rounded() / precision
        // Keep normal cent rounding except when it would imply an unearned milestone.
        if rounded.isFinite,
           WeeklyValueMilestone.earned(dollars: rounded)?.label != WeeklyValueMilestone.earned(dollars: amount)?.label {
            formatter.roundingMode = .down
        }
        return formatter.string(from: NSNumber(value: amount.isFinite ? max(0, amount) : 0)) ?? "$0.00"
    }

    static func compactTokens(_ tokens: Int) -> (value: String, unit: String) {
        let count = max(0, tokens)
        let units: [(Double, String)] = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
        for (divisor, unit) in units where Double(count) >= divisor * 0.99995 {
            let raw = Double(count) / divisor
            let value = (raw * 10).rounded() / 10
            let formatter = NumberFormatter()
            formatter.locale = AppLanguageResolver.locale
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return (formatter.string(from: NSNumber(value: value)) ?? "0", unit)
        }
        return (String(count), "")
    }

    func percentLabel(for tokens: Int) -> String {
        let percent = totalTokens > 0 ? Double(tokens) / Double(totalTokens) * 100 : 0
        if percent > 0 && percent < 1 { return "<1%" }
        let formatter = NumberFormatter()
        formatter.locale = AppLanguageResolver.locale
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: percent / 100)) ?? "\(Int(percent.rounded()))%"
    }
}
