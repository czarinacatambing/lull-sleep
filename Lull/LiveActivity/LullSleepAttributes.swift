import ActivityKit
import Foundation

// Shared between the main app and widget extension.
// Both targets compile this file directly.
struct LullSleepAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public enum Phase: String, Codable {
            case sleeping
            case awaitingRating
            case rated
        }

        public var phase: Phase
        public var bedtime: Date
        public var wakeTime: Date
        public var rating: Int?
        public var score: Double?
        public var deltaVsBaseline: Double?
        public var baselineLabel: String?
        public var experimentLabel: String?

        public init(
            phase: Phase,
            bedtime: Date,
            wakeTime: Date,
            rating: Int? = nil,
            score: Double? = nil,
            deltaVsBaseline: Double? = nil,
            baselineLabel: String? = nil,
            experimentLabel: String? = nil
        ) {
            self.phase = phase
            self.bedtime = bedtime
            self.wakeTime = wakeTime
            self.rating = rating
            self.score = score
            self.deltaVsBaseline = deltaVsBaseline
            self.baselineLabel = baselineLabel
            self.experimentLabel = experimentLabel
        }
    }

    public var startedAt: Date

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }
}
