import Foundation
import UserNotifications

/// Posts macOS notifications for limit crossings and resets, so the user
/// hears about them while the notch is out of sight (full screen, another
/// Space, an external display). Opt-in via `AlertThresholdStore.notificationsEnabled`.
@MainActor
final class SystemNotifier: ObservableObject {
    static let shared = SystemNotifier()

    enum Permission { case unknown, granted, denied }

    @Published private(set) var permission: Permission = .unknown

    /// UNUserNotificationCenter traps without a bundle identifier, which is
    /// the case for the bare test and benchmark binaries.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    private init() {}

    func refreshPermission() {
        guard let center else { return }
        center.getNotificationSettings { settings in
            let permission: Permission
            switch settings.authorizationStatus {
            case .authorized, .provisional: permission = .granted
            case .denied: permission = .denied
            default: permission = .unknown
            }
            Task { @MainActor in self.permission = permission }
        }
    }

    /// Asks once; reports whether notifications will be delivered.
    func requestPermission(completion: @escaping @MainActor (Bool) -> Void) {
        guard let center else { completion(false); return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                self.permission = granted ? .granted : .denied
                completion(granted)
            }
        }
    }

    struct Line {
        let provider: IslandProvider
        let percent: Int
        let resetAt: Date?
        let forecast: UsageForecast
    }

    func postCrossing(_ lines: [Line], severity: AlertEngine.Severity) {
        for line in lines {
            let title = L10n.tr(severity == .critical ? "%@ is nearly out: %d%% used" : "%@ is running low: %d%% used",
                                line.provider.name, line.percent)
            post(id: "crossing.\(line.provider.rawValue)", title: title, body: Self.detail(line))
        }
    }

    func postReset(_ lines: [Line]) {
        for line in lines {
            post(id: "reset.\(line.provider.rawValue)",
                 title: L10n.tr("%@ limit has reset", line.provider.name),
                 body: L10n.tr("Now at %d%% used.", line.percent))
        }
    }

    private static func detail(_ line: Line) -> String {
        if case .runsOut(let at) = line.forecast {
            return L10n.tr("Runs out around %@ at the current pace.", clock(at))
        }
        guard let resetAt = line.resetAt, resetAt > Date() else { return "" }
        return L10n.tr("Resets at %@.", clock(resetAt))
    }

    private static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: date)
    }

    private func post(id: String, title: String, body: String) {
        guard AlertThresholdStore.shared.notificationsEnabled, !AppEnvironment.isDemo, let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // A fixed id per provider and kind replaces the previous banner
        // instead of stacking one per poll.
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
