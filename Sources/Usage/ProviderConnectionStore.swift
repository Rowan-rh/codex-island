import AppKit
import Combine

@MainActor
final class ProviderConnectionStore: ObservableObject {
    static let shared = ProviderConnectionStore()
    @Published private(set) var snapshots: [IslandProvider: ConnectedUsage] = [:]
    @Published private(set) var loading: Set<IslandProvider> = []
    private var tasks: [IslandProvider: Task<Void, Never>] = [:]
    private var generations: [IslandProvider: UUID] = [:]
    private var lastAttempt: [IslandProvider: Date] = [:]
    private var cooldown: [IslandProvider: Date] = [:]
    private var selection: AnyCancellable?
    private var selectedProviders = Set(ProviderVisibilityStore.shared.selected)

    private init() {
        selection = ProviderVisibilityStore.shared.$selected
            .dropFirst().receive(on: RunLoop.main).sink { [weak self] selected in
                guard let self else { return }
                let next = Set(selected)
                guard next != self.selectedProviders else { return }
                for provider in self.selectedProviders.subtracting(next) {
                    self.tasks.removeValue(forKey: provider)?.cancel()
                    self.generations.removeValue(forKey: provider)
                    self.loading.remove(provider)
                    self.lastAttempt.removeValue(forKey: provider)
                }
                self.selectedProviders = next
                UsageStore.shared.refreshForSelectionChange()
            }
    }

    func snapshot(_ provider: IslandProvider) -> ConnectedUsage {
        snapshots[provider] ?? ConnectedUsage(message: {
            switch provider {
            case .grok: return "Sign in with Grok CLI to connect your subscription."
            case .minimaxCN: return "Set MINIMAX_CN_API_KEY or sign in with mmx CLI."
            case .deepseek: return "Set DEEPSEEK_API_KEY or add it to DeepSeek Harness."
            case .jev: return "Jev usage is read from local session records."
            default: return "Sign in with agy CLI to connect your subscription."
            }
        }(), needsLogin: provider != .jev)
    }

    func limits(_ provider: IslandProvider) -> [ConnectedLimit] {
        guard provider.usesConnectedQuota else { return [] }
        let usage = snapshot(provider)
        return ProviderQuotaPreferences.resolve(usage,
            selection: ProviderQuotaPreferences.shared.selection(for: usage.storageScope(provider: provider)))
    }

    func primary(_ provider: IslandProvider) -> ConnectedLimit? {
        guard provider.usesConnectedQuota else { return nil }
        let usage = snapshot(provider)
        return ProviderQuotaPreferences.primary(limits(provider),
            selection: ProviderQuotaPreferences.shared.selection(for: usage.storageScope(provider: provider)))
    }

    func refreshSelected() {
        for provider in ProviderVisibilityStore.shared.selected where provider.usesConnectedQuota {
            refresh(provider)
        }
    }

    /// A launch can race network startup or the CLI's config becoming
    /// readable. Give a provider with no reading one delayed retry without
    /// weakening the normal five-minute polling guard.
    func retrySelectedIfUnavailable() {
        for provider in ProviderVisibilityStore.shared.selected where provider.usesConnectedQuota {
            let current = snapshot(provider)
            guard !loading.contains(provider), current.updatedAt == nil, !current.needsLogin else { continue }
            refresh(provider, manually: true)
        }
    }

    func refresh(_ provider: IslandProvider, manually: Bool = false) {
        guard provider.usesConnectedQuota, !loading.contains(provider) else { return }
        if let until = cooldown[provider], until > Date() { return }
        if !manually, let previous = lastAttempt[provider], Date().timeIntervalSince(previous) < 300 { return }
        if AppEnvironment.isDemo {
            if provider == .deepseek {
                snapshots[provider] = ConnectedUsage(
                    balances: [ConnectedBalance(currency: "CNY", total: 86.42, granted: 6.42, toppedUp: 80)],
                    balanceAvailable: true,
                    updatedAt: Date()
                )
                return
            }
            snapshots[provider] = ConnectedUsage(limits: [
                ConnectedLimit(id: "demo", label: provider == .grok ? "Credits" : "5h",
                    usedFraction: 0.38, resetAt: Date().addingTimeInterval(7200),
                    groupLabel: provider == .grok ? nil : "Gemini Models",
                    kind: provider == .grok ? .credits : .session)
            ], plan: provider == .grok ? "SuperGrok" : "AI Pro", updatedAt: Date())
            if provider == .antigravity {
                snapshots[provider]?.limits.append(ConnectedLimit(id: "weekly", label: "week",
                    usedFraction: 0.62, resetAt: Date().addingTimeInterval(86400),
                    groupLabel: "Gemini Models", kind: .weekly))
                snapshots[provider]?.limits.append(ConnectedLimit(id: "model", label: "Usage",
                    usedFraction: 0.21, resetAt: Date().addingTimeInterval(14400),
                    groupID: "claude", groupLabel: "Claude Models"))
            }
            return
        }
        loading.insert(provider)
        lastAttempt[provider] = Date()
        let generation = UUID()
        generations[provider] = generation
        tasks[provider] = Task {
            defer {
                if generations[provider] == generation {
                    loading.remove(provider)
                    tasks[provider] = nil
                    generations[provider] = nil
                }
            }
            do {
                let fetched: ConnectedUsage
                if provider == .grok {
                    fetched = try await ProviderSessionRecovery.fetch(operation: GrokConnection.fetch,
                        renew: { try await ProviderSessionRecovery.renew("grok") })
                } else if provider == .minimaxCN {
                    fetched = try await MiniMaxConnection.fetch()
                } else if provider == .deepseek {
                    fetched = try await DeepSeekConnection.fetch()
                } else {
                    fetched = try await ProviderSessionRecovery.fetch(operation: AntigravityConnection.fetch,
                        renew: { try await ProviderSessionRecovery.renew("agy") })
                }
                guard !Task.isCancelled else { return }
                snapshots[provider] = fetched
                if fetched.accountID != nil || fetched.account != nil {
                    for limit in fetched.limits {
                        UsageHistoryStore.shared.record(key: fetched.historyKey(provider: provider, limit: limit),
                                                        window: limit.window, at: fetched.updatedAt ?? Date())
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                var message: String
                var needsLogin = false
                switch error {
                case ProviderConnectionError.signIn, ProviderConnectionError.expired,
                     ProviderConnectionError.http(401):
                    needsLogin = true
                    message = {
                        switch provider {
                        case .grok: return "Run grok login, then refresh the connection."
                        case .minimaxCN: return "Run mmx auth login --recommend --region=cn, then refresh the connection."
                        case .deepseek: return "Set DEEPSEEK_API_KEY or add it to DeepSeek Harness, then refresh."
                        default: return "Open agy CLI to restore your session, then refresh the connection."
                        }
                    }()
                case ProviderConnectionError.http(429):
                    cooldown[provider] = Date().addingTimeInterval(900)
                    message = "Rate limited. Retrying in 15 minutes."
                default:
                    message = {
                        switch provider {
                        case .grok: return "Could not read Grok usage. Try refreshing the connection."
                        case .minimaxCN: return "Could not read MiniMax CN usage. Check your Token Plan key, then refresh."
                        case .deepseek: return "Could not read the DeepSeek wallet balance. Check your API key, then refresh."
                        default: return "Could not read Antigravity usage. Check your agy CLI login, then refresh."
                        }
                    }()
                }
                snapshots[provider] = ConnectedUsage(message: message, needsLogin: needsLogin)
            }
        }
    }

    func connect(_ provider: IslandProvider) {
        guard provider == .grok || provider == .antigravity || provider == .minimaxCN
                || provider == .deepseek else { return }
        if provider == .deepseek {
            if let url = URL(string: "https://platform.deepseek.com/api_keys") { NSWorkspace.shared.open(url) }
            return
        }
        let command: String = {
            switch provider {
            case .grok: return "grok"
            case .minimaxCN: return "mmx"
            default: return "agy"
            }
        }()
        guard let binary = ProviderSessionRecovery.binary(command) else {
            let installURL: String = {
                switch provider {
                case .grok: return "https://grok.com/build"
                case .minimaxCN: return "https://platform.minimaxi.com/subscribe/token-plan"
                default: return "https://antigravity.google/docs/cli/install/"
                }
            }()
            if let url = URL(string: installURL) { NSWorkspace.shared.open(url) }
            return
        }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("CodexIsland-\(command)-\(UUID().uuidString).command")
        let quoted = "'" + binary.replacingOccurrences(of: "'", with: "'\\''") + "'"
        do {
            let arguments: String = {
                switch provider {
                case .grok: return " login"
                case .minimaxCN: return " auth login --recommend --region=cn"
                default: return ""
                }
            }()
            try ("#!/bin/sh\n" + quoted + arguments + "\n").write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
            NSWorkspace.shared.open(file)
        } catch {
            let message: String = {
                switch provider {
                case .grok: return "Run grok login in Terminal, then refresh the connection."
                case .minimaxCN: return "Run mmx auth login --recommend --region=cn, then refresh the connection."
                default: return "Open agy CLI to restore your session, then refresh the connection."
                }
            }()
            snapshots[provider] = ConnectedUsage(message: message, needsLogin: true)
        }
    }
}
