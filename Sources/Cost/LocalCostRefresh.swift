import Foundation

enum LocalCostRefresh {
    static func openCodeLookbackDays(hasCompletedScan: Bool) -> Int? {
        hasCompletedScan ? 30 : nil
    }

    static func gather<Local, Shared>(
        local: @escaping @Sendable () -> Local,
        shared: Task<Shared, Never>?
    ) async -> (local: Local, shared: Shared?) {
        let localTask = Task.detached(priority: .userInitiated, operation: local)
        let sharedResult = await shared?.value
        return (await localTask.value, sharedResult)
    }
}
