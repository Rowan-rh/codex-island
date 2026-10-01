import SwiftUI

@MainActor
final class TokenUsageDetailsModel: ObservableObject {
    @Published private(set) var events: [TokenEvent] = []
    @Published private(set) var loading = false
    @Published private(set) var error: String?

    func load() {
        guard !loading else { return }
        loading = true
        error = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let events = try UsageLedger.Source.allCases.flatMap {
                    try UsageLedger.shared.savedSnapshot(source: $0).events
                }
                await self?.finish(events: events)
            } catch {
                await self?.fail()
            }
        }
    }

    private func finish(events: [TokenEvent]) {
        self.events = events
        loading = false
    }

    private func fail() {
        error = L10n.tr("Token usage details could not be loaded.")
        loading = false
    }
}

struct TokenUsageDetailsView: View {
    enum RangePreset: String, CaseIterable {
        case today, sevenDays, thirtyDays, custom

        var label: String {
            switch self {
            case .today: "Today"
            case .sevenDays: "7 days"
            case .thirtyDays: "30 days"
            case .custom: "Custom"
            }
        }
    }

    @StateObject private var model = TokenUsageDetailsModel()
    @State private var preset = RangePreset.sevenDays
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEnd = Date()

    private var interval: (Date, Date) {
        let now = Date()
        switch preset {
        case .today:
            return (Calendar.current.startOfDay(for: now), now)
        case .sevenDays:
            return (now.addingTimeInterval(-7 * 86400), now)
        case .thirtyDays:
            return (now.addingTimeInterval(-30 * 86400), now)
        case .custom:
            return (min(customStart, customEnd), max(customStart, customEnd))
        }
    }

    private var summary: TokenUsageDetailSummary {
        TokenUsageDetails.summarize(events: model.events, from: interval.0, through: interval.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(.white.opacity(0.08))
            rangeControls
            summaryCards
            table
        }
        .frame(minWidth: 780, minHeight: 520)
        .background(Color(red: 0.020, green: 0.020, blue: 0.027))
        .preferredColorScheme(.dark)
        .onAppear { model.load() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("Token usage details"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text(L10n.tr("Local call records grouped by model."))
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
            Button {
                model.load()
            } label: {
                Label(L10n.tr(model.loading ? "Loading…" : "Refresh"), systemImage: "arrow.clockwise")
            }
            .disabled(model.loading)
        }
        .padding(.horizontal, 22)
        .padding(.top, 30)
        .padding(.bottom, 16)
    }

    private var rangeControls: some View {
        HStack(spacing: 12) {
            Picker(L10n.tr("Time range"), selection: $preset) {
                ForEach(RangePreset.allCases, id: \.self) { item in
                    Text(L10n.tr(item.label)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 330)

            if preset == .custom {
                DatePicker("", selection: $customStart, in: ...customEnd,
                           displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                Text("–").foregroundStyle(.white.opacity(0.4))
                DatePicker("", selection: $customEnd, in: customStart...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            } else {
                Text(Self.rangeFormatter.string(from: interval.0, to: interval.1))
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            metricCard("Tokens", value: Self.compact(summary.totalTokens), tint: IslandColor.codex)
            metricCard("Calls", value: summary.callCount.formatted(), tint: IslandColor.claude)
            metricCard("Average rate", value: "\(Self.rate(summary.tokensPerSecond)) tok/s", tint: .cyan)
            metricCard("Cache hit rate", value: summary.cacheHitRate.formatted(.percent.precision(.fractionLength(1))), tint: .green)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    private func metricCard(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr(title))
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.46))
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
    }

    private var table: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider().overlay(.white.opacity(0.07))
            if let error = model.error {
                emptyState(error)
            } else if model.loading && model.events.isEmpty {
                Spacer()
                ProgressView().controlSize(.small)
                Spacer()
            } else if summary.rows.isEmpty {
                emptyState(L10n.tr("No token calls in this time range."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(summary.rows) { row in
                            detailRow(row)
                            Divider().overlay(.white.opacity(0.045))
                        }
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.025)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            tableLabel("Model", width: 180, alignment: .leading)
            tableLabel("Calls", width: 60)
            tableLabel("Tokens", width: 90)
            tableLabel("Input / output", width: 130)
            tableLabel("Rate", width: 90)
            tableLabel("Cache hit", width: 90)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func detailRow(_ row: TokenUsageDetailRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName).foregroundStyle(.white.opacity(0.88)).lineLimit(1)
                Text(Self.providerName(row.provider)).font(Typography.micro).foregroundStyle(.white.opacity(0.34))
            }
            .frame(width: 180, alignment: .leading)
            tableValue(row.callCount.formatted(), width: 60)
            tableValue(Self.compact(row.totalTokens), width: 90)
            tableValue("\(Self.compact(row.inputTokens)) / \(Self.compact(row.outputTokens))", width: 130)
            tableValue("\(Self.rate(row.tokensPerSecond)) tok/s", width: 90)
            tableValue(row.cacheHitRate.formatted(.percent.precision(.fractionLength(1))), width: 90)
        }
        .font(Typography.label.monospacedDigit())
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func tableLabel(_ text: String, width: CGFloat, alignment: Alignment = .trailing) -> some View {
        Text(L10n.tr(text))
            .font(Typography.micro)
            .foregroundStyle(.white.opacity(0.38))
            .frame(width: width, alignment: alignment)
    }

    private func tableValue(_ text: String, width: CGFloat) -> some View {
        Text(text).foregroundStyle(.white.opacity(0.68)).frame(width: width, alignment: .trailing)
    }

    private func emptyState(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message).font(Typography.label).foregroundStyle(.white.opacity(0.4))
            Spacer()
        }
    }

    private static func compact(_ value: Int) -> String {
        let amount = Double(value)
        if value >= 1_000_000_000 { return String(format: "%.1fB", amount / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", amount / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", amount / 1_000) }
        return value.formatted()
    }

    private static func rate(_ value: Double) -> String {
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        if value >= 10 { return String(format: "%.1f", value) }
        if value > 0 { return String(format: "%.2f", value) }
        return "0"
    }

    private static func providerName(_ provider: TokenEvent.Provider) -> String {
        switch provider {
        case .claude: "Claude"
        case .codex: "Codex"
        case .grok: "Grok"
        case .antigravity: "Antigravity"
        case .minimaxCN: "MiniMax CN"
        case .deepseek: "DeepSeek"
        case .jev: "Jev"
        }
    }

    private static let rangeFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.locale = L10n.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
