import Foundation

enum UpdateFeedConfiguration {
    static func isAvailable(infoDictionary: [String: Any]?) -> Bool {
        guard let feed = infoDictionary?["SUFeedURL"] as? String else { return false }
        return !feed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
