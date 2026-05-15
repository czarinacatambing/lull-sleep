import Foundation

// Snapshot of a routine promotion waiting to be celebrated on the next app open.
// Built in `AppState.advanceExperiment()` when an experiment graduates, and
// cleared by `acknowledgePromotion()` after the user dismisses the big screen.
struct PendingPromotion: Codable, Equatable, Identifiable {
    // Identifiable lets SwiftUI's `fullScreenCover(item:)` drive presentation:
    // setting `state.pendingPromotion = nil` dismisses the modal.
    var id: Date { promotedAt }

    let variable: String
    let remedyId: RemedyID?
    let nights: Int           // number of scored test nights for this variable
    let averageLift: Double   // experiment avg − baseline avg (score delta)
    let sparkline: [SparkBar] // exactly 7 columns, oldest first
    let promotedAt: Date

    struct SparkBar: Codable, Equatable {
        let score: Int        // 0 = no data (skeleton bar), 1–5 = rated
        let onExperiment: Bool // true = part of the promoted variable's tests
    }
}
