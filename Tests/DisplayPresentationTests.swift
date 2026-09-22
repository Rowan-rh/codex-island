import Foundation
import Combine

@main
struct DisplayPresentationTests {
    static var failures = 0

    static func expect(_ value: Bool, _ label: String) {
        if value { print("PASS \(label)") }
        else { failures += 1; print("FAIL \(label)") }
    }

    static func main() {
        expect(DisplayPresentationStore.automaticMode(
            targetIsBuiltInNotched: true, hasExternalDisplay: false
        ) == .notch, "automatic mode uses the built-in notch")
        expect(DisplayPresentationStore.automaticMode(
            targetIsBuiltInNotched: true, hasExternalDisplay: true
        ) == .menuBar, "automatic mode uses the menu bar with an external display")
        expect(DisplayPresentationStore.automaticMode(
            targetIsBuiltInNotched: false, hasExternalDisplay: false
        ) == .menuBar, "automatic mode falls back to the menu bar without a notch")

        let store = DisplayPresentationStore.shared
        store.mode = .notch
        var observedMode: DisplayPresentationStore.Mode?
        let modeSubscription = store.$mode.dropFirst()
            .receive(on: RunLoop.main)
            .sink { _ in observedMode = store.mode }
        store.mode = .menuBar
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        expect(observedMode == .menuBar, "presentation subscriber reconciles from the newly stored mode")
        modeSubscription.cancel()

        var lifecycle = DisplayPresentationLifecycle()
        lifecycle.showIsland()
        expect(lifecycle.restoresIslandAfterUnlock, "visible island restores after unlock")
        lifecycle.hideIsland()
        expect(!lifecycle.restoresIslandAfterUnlock, "menu bar mode keeps the hidden island hidden after unlock")

        if failures > 0 { exit(1) }
    }
}
