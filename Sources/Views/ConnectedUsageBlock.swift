import SwiftUI

struct ConnectedUsageBlock: View {
    let provider: IslandProvider
    @ObservedObject private var connections = ProviderConnectionStore.shared
    @ObservedObject private var costStore = CostStore.shared
    @ObservedObject private var preferences = ProviderQuotaPreferences.shared
    @ObservedObject private var style = StylePref.shared

    var body: some View {
        let snapshot = connections.snapshot(provider)
        let limits = connections.limits(provider)
        Group {
            if provider.usesLocalUsageOnly {
                LocalUsageBlock(cost: costStore.cost(for: provider), loading: costStore.isLoading(provider),
                                color: provider.color)
            } else if provider == .deepseek, !snapshot.needsLogin, !snapshot.balances.isEmpty {
                WalletBalanceView(snapshot: snapshot, color: provider.color)
            } else if !snapshot.needsLogin && limits.contains(where: { $0.usedFraction != nil }) {
                UsageChartsRow(color: provider.color, style: style.style,
                    seed: provider == .grok ? 5 : provider == .minimaxCN ? 9 : 7,
                    metrics: limits.map { limit in
                        UsageChartMetric(id: limit.id, label: limit.label, window: limit.window,
                                         historyKey: snapshot.historyKey(provider: provider, limit: limit))
                    })
                    .help(limits.first?.groupLabel ?? provider.name)
            } else {
                ProviderUsageEmptyState(provider: provider, snapshot: snapshot,
                                        loading: connections.loading.contains(provider))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, IslandPanelLayout.columnInset)
    }
}

private struct LocalUsageBlock: View {
    let cost: ProviderCost
    let loading: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 18) {
            usageTile(cost.today)
            usageTile(cost.month)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, IslandPanelLayout.columnInset)
    }

    private func usageTile(_ window: CostWindow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr(window.label))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
            if loading && window.error != nil {
                ProgressView().controlSize(.small)
            } else if window.error != nil {
                Text("—")
                    .font(Typography.chartValue)
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                Text(Self.formatTokens(window.tokens))
                    .font(Typography.bigNumber)
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(L10n.tr("Tokens"))
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(window.label)
        .accessibilityValue(window.error ?? "\(window.tokens) tokens")
    }

    private static func formatTokens(_ tokens: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: tokens)) ?? "\(tokens)"
    }
}

private struct WalletBalanceView: View {
    let snapshot: ConnectedUsage
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "wallet.pass")
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(L10n.tr("Wallet balance"))
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.lowercase)
                Spacer(minLength: 0)
            }
            ForEach(snapshot.balances) { balance in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(balance.formattedTotal)
                        .font(Typography.bigNumber)
                        .foregroundStyle(color)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                    Spacer(minLength: 0)
                    Text(balance.currency)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            Text(L10n.tr(snapshot.balanceAvailable == false
                ? "DeepSeek reports that this wallet cannot make API calls."
                : "Available for DeepSeek API calls."))
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.46))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }
}

struct ProviderUsageEmptyState: View {
    let provider: IslandProvider
    let snapshot: ConnectedUsage
    var loading = false

    private var message: String {
        if let message = snapshot.message { return message }
        if provider == .deepseek {
            return snapshot.needsLogin ? "Add a DeepSeek API key to see your wallet balance."
                : "DeepSeek did not report a wallet balance."
        }
        if snapshot.hasNoActiveSubscription {
            return "Connect a subscribed account or choose another provider."
        }
        return snapshot.needsLogin ? "Sign in to see your usage limits."
            : "This provider hasn't reported usage limits."
    }

    var body: some View {
        VStack(spacing: 5) {
            if loading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: snapshot.hasNoActiveSubscription ? "creditcard" : "chart.bar.xaxis")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(provider.color.opacity(0.85))
                    .accessibilityHidden(true)
            }
            Text(L10n.tr(provider == .deepseek
                ? snapshot.needsLogin ? "Connect your wallet" : "Wallet balance unavailable"
                : snapshot.hasNoActiveSubscription ? "No active subscription"
                : snapshot.needsLogin ? "Connect your account" : "Usage unavailable"))
                .font(Typography.rowTitle).foregroundStyle(.white.opacity(0.85))
            Text(L10n.tr(message))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(L10n.tr("Open provider settings")) {
                UserDefaults.standard.set("providers", forKey: "Settings.activeTab")
                SettingsWindowController.shared.show()
            }
            .font(Typography.label)
            .foregroundStyle(.white.opacity(0.8))
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct ProviderDataUnavailable: View {
    let message: String
    var body: some View {
        Text(L10n.tr(message))
            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
            .multilineTextAlignment(.center)
            .padding(.horizontal, IslandPanelLayout.columnInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
