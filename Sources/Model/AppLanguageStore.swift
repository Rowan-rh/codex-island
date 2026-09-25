import AppKit
import Foundation

enum AppLanguage: String, CaseIterable, Hashable {
    case auto
    case en
    case zhHans = "zh-Hans"

    var resourceName: String? {
        switch self {
        case .auto: nil
        default: rawValue
        }
    }

    var localeIdentifier: String {
        switch self {
        case .auto: Locale.current.identifier
        case .en: "en"
        case .zhHans: "zh-Hans"
        }
    }

    var menuLabel: String {
        switch self {
        case .auto: L10n.tr("Auto")
        case .en: "English"
        case .zhHans: "简体中文"
        }
    }

    var subtitle: String {
        switch self {
        case .auto: L10n.tr("Follows macOS")
        default: menuLabel
        }
    }
}

enum AppLanguageResolver {
    static let key = "MacIsland.appLanguage"

    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        return AppLanguage(rawValue: raw) ?? .auto
    }

    static var locale: Locale {
        Locale(identifier: current.localeIdentifier)
    }

    static var bundle: Bundle? {
        current.resourceName.flatMap { lprojBundles[$0] }
    }

    static var englishBundle: Bundle? { lprojBundles["en"] }

    // Resolved once: L10n.tr runs per heatmap cell, and a path lookup per call
    // showed up as main-thread time when the panel opens.
    private static let lprojBundles: [String: Bundle] = Dictionary(
        uniqueKeysWithValues: AppLanguage.allCases.compactMap(\.resourceName).compactMap { name in
            Bundle.main.path(forResource: name, ofType: "lproj").flatMap(Bundle.init(path:)).map { (name, $0) }
        }
    )
}

@MainActor
final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: AppLanguageResolver.key) }
    }

    private init() {
        language = AppLanguageResolver.current
    }

    @discardableResult
    func select(_ newLanguage: AppLanguage) -> Bool {
        guard language != newLanguage else { return false }
        language = newLanguage
        return true
    }

    func restartApp() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundleURL.path]
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            NSLog("CodexIsland: failed to restart app: %@", error.localizedDescription)
        }
    }
}
