import Foundation

/// A single billable unit of token consumption parsed from a local session log.
/// Both `ClaudeLogReader` and `CodexLogReader` emit these so the cost pipeline
/// downstream is provider-agnostic.
struct TokenEvent {
    enum Provider: String, Codable {
        case claude
        case codex
        case grok
        case antigravity
        case minimaxCN = "minimax-cn"
        case deepseek
        case jev
    }

    let provider: Provider
    let timestamp: Date
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    /// Tokens written to the prompt cache during this turn. Anthropic-only.
    let cacheCreationTokens: Int
    /// Tokens served from the prompt cache during this turn. Both providers
    /// (Codex calls these "cached_input_tokens" — they are billed at a
    /// discount but still draw from the input bucket).
    let cacheReadTokens: Int
    var recordID: String? = nil
    var recordAliases: [String] = []
    /// Provider of the tool whose log recorded this event, when `provider`
    /// was re-attributed from the model name. Ledger identity, persistence,
    /// and whole-day recovery totals stay keyed on the recording tool.
    var origin: Provider? = nil

    var recordingProvider: Provider { origin ?? provider }

    /// Claude Code and Codex can be pointed at third-party models (e.g. via
    /// CC Switch), so a MiniMax or DeepSeek call logged by either CLI is
    /// credited to the model's provider rather than the tool's. OpenCode
    /// records carry an explicit provider ID and are left alone.
    func attributedByModel() -> TokenEvent {
        guard provider == .claude || provider == .codex,
              let inferred = Provider.inferred(fromModel: model), inferred != provider else { return self }
        return TokenEvent(provider: inferred, timestamp: timestamp, model: model,
                          inputTokens: inputTokens, outputTokens: outputTokens,
                          cacheCreationTokens: cacheCreationTokens, cacheReadTokens: cacheReadTokens,
                          recordID: recordID, recordAliases: recordAliases, origin: recordingProvider)
    }
}

extension TokenEvent.Provider {
    static func inferred(fromModel model: String) -> Self? {
        let name = model.lowercased()
        let bare = name.split(separator: "/").last.map(String.init) ?? name
        if bare.hasPrefix("minimax") { return .minimaxCN }
        if bare.hasPrefix("deepseek") { return .deepseek }
        return nil
    }
}
