import SwiftUI

struct OverviewView: View {
    @ObservedObject private var costStore = CostStore.shared

    var body: some View {
        OverviewContent(
            allDays: OverviewContent.joinDays(buckets: Dictionary(uniqueKeysWithValues:
                IslandProvider.allCases.map { ($0, costStore.cost(for: $0).dailyTokens) }
            )),
            loading: costStore.loading
        )
    }
}

/// Minimal contribution-style view. Powered by the same local log scan as
/// the cost page, but framed as usage history: cell intensity is token
/// volume, and cell hue follows the dominant provider for that day.
private struct OverviewContent: View {
    let allDays: [OverviewDay]
    let loading: Bool
    @State private var selectedDate: Date?
    @State private var selectedProvider: IslandProvider?

    private var days: [OverviewDay] {
        guard let selectedProvider else { return allDays }
        return allDays.map { day in
            OverviewDay(date: day.date,
                        tokens: [selectedProvider: day.tokens[selectedProvider] ?? 0],
                        isFuture: day.isFuture)
        }
    }

    private var totalTokens: Int { days.reduce(0) { $0 + $1.totalTokens } }
    private var activeDays: Int { days.filter { $0.totalTokens > 0 }.count }

    private var displayedUsage: [ProviderTokenUsage] {
        let history = allDays
        let selected = selectedDate.flatMap { date in
            history.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        }
        return IslandProvider.allCases.compactMap { provider in
            let tokens = history.reduce(0) { $0 + ($1.tokens[provider] ?? 0) }
            guard tokens > 0 else { return nil }
            return ProviderTokenUsage(provider: provider,
                                      tokens: selected.map { $0.tokens[provider] ?? 0 } ?? tokens)
        }
    }

    private var selectedDay: OverviewDay? {
        guard let selectedDate else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return days.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var displayedTokens: Int {
        selectedDay?.totalTokens ?? totalTokens
    }

    var body: some View {
        overviewContent
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            summary

            ContributionGrid(days: days, selectedDate: $selectedDate)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let selectedDay {
                DayDetailStrip(day: selectedDay)
                .transition(.detailReveal)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .animation(.detailExpand, value: selectedDate)
        .onReceive(ScreenPref.shared.$screen.dropFirst()) { screen in
            guard screen != .overview else { return }
            if selectedDate != nil {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    selectedDate = nil
                }
            }
        }
    }

    private var summary: some View {
        HStack(alignment: .bottom, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summaryLabel)
                    .font(Typography.sectionLabel)
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.55))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Self.formatTokens(displayedTokens).value)
                        .font(Typography.chartValue)
                        .foregroundStyle(.white)
                    Text(Self.formatTokens(displayedTokens).unit)
                        .font(Typography.unit)
                        .foregroundStyle(.white.opacity(0.40))
                }
            }

            HStack(alignment: .center, spacing: 10) {
                Text(summarySubline)
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.50))
                if loading {
                    Text(L10n.tr("Syncing"))
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.36))
                }
            }
            .padding(.bottom, 5)

            Spacer(minLength: 0)

            ProviderSplitRow(usage: displayedUsage, selectedProvider: $selectedProvider)
                .padding(.bottom, 5)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(summaryAccessibilityLabel)
    }

    private var summaryLabel: String {
        guard let selectedDay else {
            let yearLabel = L10n.tr("%@ TOKENS", Self.currentYearString)
            return selectedProvider.map { "\($0.name.uppercased()) · \(yearLabel)" } ?? yearLabel
        }
        return Self.dayLabelFormatter.string(from: selectedDay.date).uppercased()
    }

    private var summarySubline: String {
        guard let selectedDay else { return L10n.tr("%d Active Days", activeDays) }
        return selectedDay.dominanceLabel
    }

    private var summaryAccessibilityLabel: String {
        let period = selectedDay.map { Self.dayLabelFormatter.string(from: $0.date) } ?? Self.currentYearString
        return "\(period): \(Self.formatTokensSpoken(displayedTokens)). " + displayedUsage.filter { selectedProvider == nil || $0.provider == selectedProvider }.map {
            "\($0.provider.name) \(Self.formatTokensSpoken($0.tokens))"
        }.joined(separator: ", ")
    }

    static func joinDays(buckets: [IslandProvider: [DailyTokenBucket]]) -> [OverviewDay] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(from: cal.dateComponents([.year], from: today)) ?? today
        let nextYear = cal.date(byAdding: .year, value: 1, to: start) ?? today
        let dayCount = cal.dateComponents([.day], from: start, to: nextYear).day ?? 365
        var totals: [Date: [IslandProvider: Int]] = [:]
        for (provider, history) in buckets {
            for bucket in history {
                let day = cal.startOfDay(for: bucket.dayStart)
                totals[day, default: [:]][provider, default: 0] += bucket.tokens
            }
        }
        return (0..<dayCount).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: start) ?? start
            return OverviewDay(date: day, tokens: totals[day] ?? [:], isFuture: day > today)
        }
    }

    fileprivate static func formatTokens(_ n: Int) -> (value: String, unit: String) {
        let v = Double(n)
        if n < 1_000 { return ("\(n)", "tok") }
        if n < 10_000 { return (String(format: "%.1f", v / 1_000), "k") }
        if n < 1_000_000 { return (String(format: "%.0f", v / 1_000), "k") }
        if n < 1_000_000_000 { return (String(format: "%.1f", v / 1_000_000), "M") }
        return (String(format: "%.1f", v / 1_000_000_000), "B")
    }

    fileprivate static func formatTokensSpoken(_ n: Int) -> String {
        let formatted = formatTokens(n)
        return L10n.tr("%@ %@ tokens", formatted.value, formatted.unit)
    }

    fileprivate static func formatExactTokens(_ n: Int) -> String {
        integerFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = L10n.locale
        return formatter
    }()

    fileprivate static var currentYearString: String {
        let year = Calendar.current.component(.year, from: Date())
        return "\(year)"
    }
}

private struct ProviderTokenUsage: Identifiable {
    let provider: IslandProvider
    let tokens: Int
    var id: IslandProvider { provider }
}

private struct OverviewDay: Identifiable {
    let date: Date
    let tokens: [IslandProvider: Int]
    var isFuture = false

    var id: Date { date }
    var totalTokens: Int { tokens.values.reduce(0, +) }
    var usage: [ProviderTokenUsage] {
        IslandProvider.allCases.compactMap { provider in
            let count = tokens[provider] ?? 0
            return count > 0 ? ProviderTokenUsage(provider: provider, tokens: count) : nil
        }
    }
    var leadingProvider: IslandProvider? {
        usage.max { $0.tokens < $1.tokens }?.provider
    }
    var dominantProvider: IslandProvider? {
        guard totalTokens > 0 else { return nil }
        return usage.first { Double($0.tokens) / Double(totalTokens) >= 0.60 }?.provider
    }
    var dominanceLabel: String {
        guard totalTokens > 0 else { return L10n.tr("No Activity") }
        return dominantProvider.map { "Mostly " + $0.name } ?? L10n.tr("Mixed Use")
    }
}

private struct ContributionGrid: View {
    let days: [OverviewDay]
    @Binding var selectedDate: Date?

    private var intensityScale: TokenIntensityScale {
        TokenIntensityScale(values: days.map(\.totalTokens))
    }

    var body: some View {
        let scale = intensityScale

        VStack(alignment: .leading, spacing: 7) {
            MonthRail(marks: monthMarks)
                .frame(width: gridWidth, height: 12, alignment: .leading)

            ContributionCanvas(weeks: weeks, scale: scale, cellSize: cellSize, spacing: gridSpacing,
                               selectedDate: selectedDate, calendar: calendar) { day in
                toggleSelection(day)
            }
            .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
        }
        .frame(width: gridWidth, height: gridHeight + 19, alignment: .topLeading)
        .frame(maxWidth: .infinity, minHeight: gridHeight + 19, maxHeight: gridHeight + 19, alignment: .leading)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.tr("Daily token usage in %@", OverviewContent.currentYearString))
    }

    private var weeks: [ContributionWeek] {
        guard let first = days.first?.date,
              let today = days.last?.date else { return [] }
        let cal = calendar
        let start = weekStart(containing: first, calendar: cal)
        let map = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        var out: [ContributionWeek] = []
        out.reserveCapacity(weekCount)

        for week in 0..<weekCount {
            guard let weekStartDate = cal.date(byAdding: .day, value: week * 7, to: start) else {
                continue
            }
            var slots: [ContributionSlot] = []
            slots.reserveCapacity(7)

            for row in 0..<7 {
                let offset = week * 7 + row
                guard let date = cal.date(byAdding: .day, value: offset, to: start) else {
                    slots.append(.spacer)
                    continue
                }
                if date < first || date > today {
                    slots.append(.spacer)
                } else if let day = map[date] {
                    slots.append(.day(day))
                }
            }
            out.append(ContributionWeek(id: weekStartDate, slots: slots))
        }
        return out
    }

    private var weekCount: Int {
        guard let first = days.first?.date,
              let last = days.last?.date else { return 1 }
        let cal = calendar
        let start = weekStart(containing: first, calendar: cal)
        let daySpan = cal.dateComponents([.day], from: start, to: last).day ?? 0
        return max(1, daySpan / 7 + 1)
    }

    private var cellSize: CGFloat {
        return 11.6
    }

    private var gridSpacing: CGFloat {
        return 2.35
    }

    private var gridWidth: CGFloat {
        CGFloat(weekCount) * cellSize + CGFloat(max(0, weekCount - 1)) * gridSpacing
    }

    private var gridHeight: CGFloat {
        CGFloat(7) * cellSize + CGFloat(6) * gridSpacing
    }

    private var monthMarks: [MonthMark] {
        guard let first = days.first?.date,
              let last = days.last?.date else { return [] }
        let cal = calendar
        let start = weekStart(containing: first, calendar: cal)
        var cursor = cal.date(from: cal.dateComponents([.year, .month], from: first)) ?? first
        var marks: [MonthMark] = []

        while cursor <= last {
            let dayOffset = cal.dateComponents([.day], from: start, to: cursor).day ?? 0
            let weekIndex = max(0, dayOffset / 7)
            marks.append(MonthMark(
                id: cursor,
                label: Self.monthFormatter.string(from: cursor),
                x: CGFloat(weekIndex) * (cellSize + gridSpacing)
            ))
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return marks
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }

    private func isSelected(_ day: OverviewDay) -> Bool {
        guard !day.isFuture else { return false }
        guard let selectedDate else { return false }
        return calendar.isDate(day.date, inSameDayAs: selectedDate)
    }

    private func toggleSelection(_ day: OverviewDay) {
        guard !day.isFuture else { return }
        if isSelected(day) {
            selectedDate = nil
        } else {
            selectedDate = day.date
        }
    }

    private func weekStart(containing date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: date) ?? date
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()
}

private struct ContributionWeek: Identifiable {
    let id: Date
    let slots: [ContributionSlot]
}

private enum ContributionSlot {
    case spacer
    case day(OverviewDay)
}

private struct MonthMark: Identifiable {
    let id: Date
    let label: String
    let x: CGFloat
}

private struct MonthRail: View {
    let marks: [MonthMark]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(marks) { mark in
                Text(mark.label)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.30))
                    .lineLimit(1)
                    .fixedSize()
                    .offset(x: mark.x, y: 0)
            }
        }
    }
}

/// Draws every day of the heatmap in one Canvas. Per-cell views (fill, clip,
/// border, provider stripe, hover and tooltip each) added thousands of display
/// list items that SwiftUI re-walked on every frame of a page swipe, so the
/// overview page slid at roughly 30fps. Hover, click, tooltip and per-day
/// accessibility elements are handled here for the whole grid.
private struct ContributionCanvas: View {
    let weeks: [ContributionWeek]
    let scale: TokenIntensityScale
    let cellSize: CGFloat
    let spacing: CGFloat
    let selectedDate: Date?
    let calendar: Calendar
    let onSelect: (OverviewDay) -> Void

    @State private var hoveredDate: Date?

    var body: some View {
        Canvas { context, _ in
            for (column, week) in weeks.enumerated() {
                for (row, slot) in week.slots.enumerated() {
                    guard case .day(let day) = slot else { continue }
                    draw(day, in: cellRect(column: column, row: row), context: context)
                }
            }
        }
        .frame(width: gridWidth, height: gridHeight)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location): hoveredDate = day(at: location).flatMap { $0.isFuture ? nil : $0.date }
            case .ended: hoveredDate = nil
            }
        }
        .onTapGesture(coordinateSpace: .local) { location in
            guard let day = day(at: location), !day.isFuture else { return }
            onSelect(day)
        }
        .overlay {
            // Re-identified per hovered day so macOS shows a fresh tooltip for
            // each cell, like the old per-cell `.help`.
            Color.clear
                .help(hoveredDay.map(Self.helpText) ?? "")
                .id(hoveredDate)
                .allowsHitTesting(hoveredDate != nil)
        }
        .accessibilityElement(children: .contain)
        .accessibilityChildren {
            ForEach(pastDays, id: \.date) { day in
                Rectangle()
                    .accessibilityLabel(Self.helpText(day))
                    .accessibilityAddTraits(isSelected(day) ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction { onSelect(day) }
            }
        }
    }

    private var cornerRadius: CGFloat { min(3, cellSize * 0.22) }
    private var gridWidth: CGFloat { CGFloat(weeks.count) * (cellSize + spacing) - spacing }
    private var gridHeight: CGFloat { 7 * cellSize + 6 * spacing }

    private var pastDays: [OverviewDay] {
        weeks.flatMap(\.slots).compactMap { slot in
            guard case .day(let day) = slot, !day.isFuture else { return nil }
            return day
        }
    }

    private var hoveredDay: OverviewDay? {
        guard let hoveredDate else { return nil }
        return pastDays.first { $0.date == hoveredDate }
    }

    private func cellRect(column: Int, row: Int) -> CGRect {
        CGRect(x: CGFloat(column) * (cellSize + spacing), y: CGFloat(row) * (cellSize + spacing),
               width: cellSize, height: cellSize)
    }

    private func day(at point: CGPoint) -> OverviewDay? {
        let pitch = cellSize + spacing
        let column = Int(floor(point.x / pitch)), row = Int(floor(point.y / pitch))
        guard weeks.indices.contains(column), (0..<7).contains(row),
              point.x - CGFloat(column) * pitch <= cellSize, point.y - CGFloat(row) * pitch <= cellSize,
              weeks[column].slots.indices.contains(row),
              case .day(let day) = weeks[column].slots[row] else { return nil }
        return day
    }

    private func isSelected(_ day: OverviewDay) -> Bool {
        guard !day.isFuture, let selectedDate else { return false }
        return calendar.isDate(day.date, inSameDayAs: selectedDate)
    }

    private func draw(_ day: OverviewDay, in rect: CGRect, context: GraphicsContext) {
        let shape = Path(roundedRect: rect, cornerRadius: cornerRadius)
        if day.isFuture {
            context.fill(shape, with: .color(.white.opacity(0.012)))
            strokeBorder(rect, color: .white.opacity(0.030), width: 0.5, context: context)
            return
        }
        let opacity = day.totalTokens > 0 ? scale.opacity(for: day.totalTokens) : 0.035
        var cell = context
        cell.clip(to: shape)
        if let provider = day.leadingProvider {
            cell.fill(shape, with: .color(provider.color.opacity(opacity)))
            if day.usage.count > 1 {
                let stripeHeight = max(2, cellSize * 0.20)
                var x = rect.minX
                for item in day.usage {
                    let width = cellSize * CGFloat(Double(item.tokens) / Double(day.totalTokens))
                    cell.fill(Path(CGRect(x: x, y: rect.maxY - stripeHeight, width: width, height: stripeHeight)),
                              with: .color(item.provider.color.opacity(max(0.35, opacity))))
                    x += width
                }
            }
        } else {
            cell.fill(shape, with: .color(.white.opacity(opacity)))
        }
        let selected = isSelected(day)
        strokeBorder(rect, color: strokeColor(for: day, selected: selected),
                     width: selected ? 1.2 : 0.5, context: context)
    }

    /// Matches `strokeBorder`: the stroke sits inside the cell's bounds.
    private func strokeBorder(_ rect: CGRect, color: Color, width: CGFloat, context: GraphicsContext) {
        let inset = rect.insetBy(dx: width / 2, dy: width / 2)
        context.stroke(Path(roundedRect: inset, cornerRadius: max(0, cornerRadius - width / 2)),
                       with: .color(color), lineWidth: width)
    }

    private func strokeColor(for day: OverviewDay, selected: Bool) -> Color {
        if selected { return .white.opacity(0.72) }
        if hoveredDate == day.date { return .white.opacity(0.22) }
        guard day.totalTokens > 0 else { return .white.opacity(0.04) }
        return .white.opacity(0.06 + Double(scale.level(for: day.totalTokens)) * 0.012)
    }

    private static func helpText(_ day: OverviewDay) -> String {
        L10n.tr(
            "%@: %@, %@",
            dayFormatter.string(from: day.date),
            OverviewContent.formatTokensSpoken(day.totalTokens),
            day.dominanceLabel
        ) + (day.usage.isEmpty ? "" : "\n" + day.usage.map { item in
            let percent = Double(item.tokens) / Double(day.totalTokens) * 100
            return "\(item.provider.name): \(String(format: "%.1f", percent))%"
        }.joined(separator: ", "))
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()
}

private struct TokenIntensityScale {
    private let values: [Int]

    init(values: [Int]) {
        self.values = values.filter { $0 > 0 }.sorted()
    }

    func level(for tokens: Int) -> Int {
        guard tokens > 0, !values.isEmpty else { return 0 }
        let rank = Double(upperBound(tokens)) / Double(values.count)
        switch rank {
        case ..<0.15: return 1
        case ..<0.35: return 2
        case ..<0.60: return 3
        case ..<0.80: return 4
        case ..<0.93: return 5
        default:      return 6
        }
    }

    func opacity(for tokens: Int) -> Double {
        switch level(for: tokens) {
        case 1:  return 0.14
        case 2:  return 0.26
        case 3:  return 0.42
        case 4:  return 0.62
        case 5:  return 0.82
        case 6:  return 0.98
        default: return 0.035
        }
    }

    private func upperBound(_ value: Int) -> Int {
        var low = 0
        var high = values.count
        while low < high {
            let mid = (low + high) / 2
            if values[mid] <= value {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}

private struct DayDetailStrip: View {
    let day: OverviewDay

    private var providerColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), alignment: .trailing),
              count: min(3, max(1, day.usage.count)))
    }

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(.white.opacity(0.075))
                .frame(height: 0.5)

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.detailFormatter.string(from: day.date).uppercased())
                        .font(Typography.sectionLabel)
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)

                    Text(L10n.tr("All Tokens"))
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.36))
                        .lineLimit(1)
                }
                .frame(width: 116, alignment: .leading)

                Spacer(minLength: 0)

                detailMetric(
                    label: L10n.tr("TOTAL"),
                    spokenLabel: L10n.tr("Total"),
                    value: day.totalTokens,
                    color: .white.opacity(0.78),
                    dimmed: true
                )
            }

            if !day.usage.isEmpty {
                LazyVGrid(columns: providerColumns, alignment: .trailing, spacing: 7) {
                    ForEach(day.usage) { item in
                        detailMetric(label: item.provider.name.uppercased(), spokenLabel: item.provider.name,
                                     value: item.tokens, color: item.provider.color)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func detailMetric(
        label: String,
        spokenLabel: String? = nil,
        value: Int,
        color: Color,
        dimmed: Bool = false
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(Typography.chip)
                .tracking(0.5)
                .foregroundStyle(color.opacity(dimmed ? 0.70 : 0.82))
                .lineLimit(1)

            Text(OverviewContent.formatExactTokens(value))
                .font(Typography.bodyNumber)
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
        }
        .frame(maxWidth: 112, alignment: .trailing)
        .help(L10n.tr("%@: %@ tokens", spokenLabel ?? label, OverviewContent.formatExactTokens(value)))
    }

    private var accessibilityLabel: String {
        "\(Self.detailFormatter.string(from: day.date)), all tokens. Total \(OverviewContent.formatTokensSpoken(day.totalTokens)), " + day.usage.map {
            "\($0.provider.name) \(OverviewContent.formatTokensSpoken($0.tokens))"
        }.joined(separator: ", ")
    }

    private static let detailFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter
    }()
}

private struct ProviderSplitRow: View {
    let usage: [ProviderTokenUsage]
    @Binding var selectedProvider: IslandProvider?
    private var total: Int { usage.reduce(0) { $0 + $1.tokens } }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 3) {
            ForEach(usage) { item in
                Button {
                    selectedProvider = selectedProvider == item.provider ? nil : item.provider
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(item.provider.color).frame(width: 5, height: 5)
                        Text("\(item.provider.name) \(share(item.tokens))")
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(selectedProvider == item.provider ? 0.95 : 0.46))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                    .background(selectedProvider == item.provider ? item.provider.color.opacity(0.18) : .clear,
                                in: RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(selectedProvider == item.provider ? "Show all providers" : "Show only \(item.provider.name)")
                .accessibilityLabel("\(item.provider.name), \(share(item.tokens)) of all tokens")
                .accessibilityAddTraits(selectedProvider == item.provider ? .isSelected : [])
            }
        }
        .frame(width: 230)
    }

    private func share(_ value: Int) -> String {
        guard total > 0 else { return "0%" }
        let percent = Double(value) / Double(total) * 100
        if value > 0 && percent < 1 { return "<1%" }
        return "\(Int(percent.rounded()))%"
    }
}
