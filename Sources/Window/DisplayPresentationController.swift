import AppKit
import Combine

@MainActor
final class DisplayPresentationController {
    private let menuBar = MenuBarController()
    private var island: IslandWindowController?
    private var subscriptions: Set<AnyCancellable> = []
    private var screenChangeObserver: NSObjectProtocol?

    init() {
        DisplayPresentationStore.shared.$mode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reconcile() }
            .store(in: &subscriptions)

        IslandTargetDisplayStore.shared.$choice
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reconcile() }
            .store(in: &subscriptions)

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reconcile() }
        }

        reconcile()
    }

    deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    private func reconcile() {
        switch DisplayPresentationStore.shared.resolvedMode {
        case .menuBar:
            island?.hide()
            menuBar.setVisible(true)
        case .automatic, .notch:
            menuBar.setVisible(false)
            if island == nil { island = IslandWindowController() }
            island?.show()
        }
    }
}
