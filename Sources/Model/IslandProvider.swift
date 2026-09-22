import Foundation

enum IslandProvider: String, CaseIterable, Identifiable, Codable {
    case claude, codex, grok, antigravity, minimaxCN, deepseek, jev

    var id: String { rawValue }
    var name: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .grok: return "Grok"
        case .antigravity: return "Antigravity"
        case .minimaxCN: return "MiniMax CN"
        case .deepseek: return "DeepSeek"
        case .jev: return "Jev"
        }
    }
    var usesLegacyUsage: Bool { self == .claude || self == .codex }
    /// Jev has no supported account-quota endpoint. Its usage is read from
    /// local session records instead of being modeled as a percentage window.
    var usesLocalUsageOnly: Bool { self == .jev }
    var usesConnectedQuota: Bool { !usesLegacyUsage && !usesLocalUsageOnly }
}
