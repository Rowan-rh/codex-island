import Foundation
import Combine

@MainActor
final class DisplayPresentationStore: ObservableObject {
    static let shared = DisplayPresentationStore()

    enum Mode: String, CaseIterable, Identifiable {
        case automatic
        case notch
        case menuBar

        var id: String { rawValue }

        var label: String {
            switch self {
            case .automatic: return "Automatic"
            case .notch: return "Notch"
            case .menuBar: return "Menu Bar"
            }
        }
    }

    private static let key = "MacIsland.displayPresentation"

    @Published var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.key) }
    }

    var resolvedMode: Mode {
        guard mode == .automatic else { return mode }
        let displays = DisplayInfo.all()
        let target = DisplayInfo.currentTarget()
        return Self.automaticMode(
            targetIsBuiltInNotched: target?.isBuiltin == true && target?.notch.hasNotch == true,
            hasExternalDisplay: displays.contains { !$0.isBuiltin }
        )
    }

    nonisolated static func automaticMode(targetIsBuiltInNotched: Bool,
                                          hasExternalDisplay: Bool) -> Mode {
        if hasExternalDisplay { return .menuBar }
        return targetIsBuiltInNotched ? .notch : .menuBar
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        self.mode = Mode(rawValue: raw ?? "") ?? .automatic
    }
}
