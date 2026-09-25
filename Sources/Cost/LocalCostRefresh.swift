import Foundation

enum LocalCostRefresh {
    static let openCodeProviderMappingVersionKey = "MacIsland.openCodeProviderMappingVersion"
    static let openCodeProviderMappingVersion = 2

    static func openCodeLookbackDays(
        hasCompletedScan: Bool,
        providerMappingVersion: Int = openCodeProviderMappingVersion
    ) -> Int? {
        hasCompletedScan && providerMappingVersion >= openCodeProviderMappingVersion ? 30 : nil
    }

    static func canCompleteOpenCodeProviderBackfill(scanCompleted: Bool, saveError: String?) -> Bool {
        scanCompleted && saveError == nil
    }
}
