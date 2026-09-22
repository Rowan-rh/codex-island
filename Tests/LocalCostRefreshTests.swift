import Foundation

@main
struct LocalCostRefreshTests {
    final class LockedCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func increment() {
            lock.lock()
            value += 1
            lock.unlock()
        }

        func read() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    static func waitForSignal(_ semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now() + 1) == .success
    }

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

        let localStarted = DispatchSemaphore(value: 0)
        let shared = Task.detached { waitForSignal(localStarted) }
        let gathered = await LocalCostRefresh.gather(local: {
            localStarted.signal()
            return 42
        }, shared: shared)
        expect(gathered.local == 42 && gathered.shared == true,
               "provider scan starts before waiting for the shared OpenCode scan")

        let sharedRuns = LockedCounter()
        let oneSharedTask = Task.detached {
            sharedRuns.increment()
            return 7
        }
        async let first = LocalCostRefresh.gather(local: { 1 }, shared: oneSharedTask)
        async let second = LocalCostRefresh.gather(local: { 2 }, shared: oneSharedTask)
        let results = await (first, second)
        expect(sharedRuns.read() == 1 && results.0.shared == 7 && results.1.shared == 7,
               "multiple providers share one OpenCode scan")

        exit(failures == 0 ? 0 : 1)
    }
}
