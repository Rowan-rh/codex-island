import Foundation

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

        if failures > 0 { exit(1) }
    }
}
