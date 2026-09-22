import Foundation

@main
struct UpdateFeedConfigurationTests {
    static func main() {
        var failures = 0
        func expect(_ condition: Bool, _ label: String) {
            if condition { print("PASS \(label)") }
            else { failures += 1; print("FAIL \(label)") }
        }

        expect(!UpdateFeedConfiguration.isAvailable(infoDictionary: nil), "missing feed disables updates")
        expect(!UpdateFeedConfiguration.isAvailable(infoDictionary: ["SUFeedURL": ""]), "empty feed disables updates")
        expect(!UpdateFeedConfiguration.isAvailable(infoDictionary: ["SUFeedURL": "  "]), "blank feed disables updates")
        expect(UpdateFeedConfiguration.isAvailable(infoDictionary: ["SUFeedURL": "https://example.com/appcast.xml"]),
               "nonempty feed enables updates")
        exit(failures == 0 ? 0 : 1)
    }
}
