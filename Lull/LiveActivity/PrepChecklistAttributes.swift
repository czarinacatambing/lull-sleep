import ActivityKit
import Foundation

// Shared between main app (Lull) and widget extension (LullActivities).
// Both targets compile this file directly.
struct PrepChecklistAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // UUID strings — Codable-friendly alternative to Set<UUID>
        var doneIds: [String]
        var updatedAt: Date
    }

    struct Item: Codable, Hashable, Identifiable {
        var id: String            // UUID string of the RoutineStep
        var label: String
        var scheduledTime: Date   // when the prep reminder fires
    }

    var items: [Item]
    var bedtime: Date
}
