import Foundation
import SwiftData

/// Apple Health stats for a session linked to an Apple Watch workout.
/// Kept in a local-only store, never synced: Apple doesn't allow health data in iCloud.
@Model
final class WorkoutHealthData {
    /// The `uid` of the session this belongs to (the two live in different stores, so no relationship).
    var sessionID: UUID = UUID()
    var healthWorkoutID: UUID?
    var sourceName: String = ""
    var activeEnergyKcal: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?

    init(sessionID: UUID) {
        self.sessionID = sessionID
    }
}
