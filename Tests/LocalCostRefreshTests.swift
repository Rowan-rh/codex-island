import Foundation

@main
struct LocalCostRefreshTests {
    static func main() async {
        var failures = 0
        func expect(_ condition: Bool, _ label: String) {
            if condition { print("PASS \(label)") }
            else { failures += 1; print("FAIL \(label)") }
        }

        expect(LocalCostRefresh.openCodeLookbackDays(hasCompletedScan: false) == nil,
               "the first OpenCode scan covers all history")
        expect(LocalCostRefresh.openCodeLookbackDays(hasCompletedScan: true) == 30,
               "later OpenCode scans use the overlap window")
        expect(LocalCostRefresh.openCodeLookbackDays(hasCompletedScan: true, providerMappingVersion: 1) == nil,
               "a newer OpenCode provider mapping triggers a full rescan")

        exit(failures == 0 ? 0 : 1)
    }
}
