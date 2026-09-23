import Foundation

enum LocalCostRefresh {
    static let openCodeProviderMappingVersionKey = "MacIsland.openCodeProviderMappingVersion"
    static let openCodeProviderMappingVersion = 1

    static func openCodeLookbackDays(
        hasCompletedScan: Bool,
        providerMappingVersion: Int = openCodeProviderMappingVersion
    ) -> Int? {
        hasCompletedScan && providerMappingVersion >= openCodeProviderMappingVersion ? 30 : nil
    }

    static func canCompleteOpenCodeProviderBackfill(scanCompleted: Bool, saveError: String?) -> Bool {
        scanCompleted && saveError == nil
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
