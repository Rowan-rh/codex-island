import AppKit
import Sparkle
import SwiftUI

/// Thin wrapper around `SPUStandardUpdaterController` so the rest of the app
/// can talk to Sparkle without importing it directly. Holds Sparkle's UI
/// driver (alert + download window) too — no extra delegate plumbing needed.
///
/// Auto-check cadence and the "automatically download" preference are stored
/// by Sparkle itself in NSUserDefaults under SU* keys, so we don't duplicate
/// that state here.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    private let controller: SPUStandardUpdaterController?
    let isAvailable: Bool

    @Published var automaticallyChecks: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    private init() {
        isAvailable = UpdateFeedConfiguration.isAvailable(infoDictionary: Bundle.main.infoDictionary)
        if isAvailable {
            let controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            self.controller = controller
            automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        } else {
            controller = nil
            automaticallyChecks = false
        }
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
