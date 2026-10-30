import Foundation
import SwiftData

/// Where the app's data lives: training in a store synced to the user's iCloud (private database),
/// Apple Health stats in a store that never leaves the iPhone.
enum DataStore {
    static let cloudContainerID = "iCloud.com.matheus.Sendlog"

    /// Whether this build is signed with iCloud. Set by the `SENDLOG_ICLOUD` build setting (YES needs a paid
    /// Apple Developer Program team). Without the entitlement, touching CloudKit terminates the app.
    static var isSyncConfigured: Bool {
        Bundle.main.object(forInfoDictionaryKey: "SendlogICloudSync") as? String == "YES"
    }

    /// False when iCloud sync isn't configured or couldn't be set up, so the app runs with local data only.
    private(set) static var isSyncEnabled = false

    /// True when the data couldn't be opened at all and the app is running on an empty, unsaved store.
    private(set) static var isTemporary = false

    private static let syncedModels: [any PersistentModel.Type] = [
        TrainingSession.self, StrengthExercise.self, ExerciseSet.self,
        ClimbingBlock.self, Boulder.self, RoutineBlock.self, RoutineItem.self,
    ]

    static func makeContainer() -> ModelContainer {
        if isSyncConfigured, let container = makeContainer(syncing: true) {
            isSyncEnabled = true
            return container
        }
        if let container = makeContainer(syncing: false) { return container }
        // Last resort: an in-memory store, so the app opens and can explain the problem instead of crashing.
        isTemporary = true
        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Schema(syncedModels + [WorkoutHealthData.self]), configurations: memory)
    }

    private static func makeContainer(syncing: Bool) -> ModelContainer? {
        let synced = ModelConfiguration(
            "Sendlog",
            schema: Schema(syncedModels),
            // The same file the app used before sync existed, so earlier data is kept.
            url: URL.applicationSupportDirectory.appending(path: "default.store"),
            cloudKitDatabase: syncing ? .private(cloudContainerID) : .none
        )
        let local = ModelConfiguration(
            "Local",
            schema: Schema([WorkoutHealthData.self]),
            url: URL.applicationSupportDirectory.appending(path: "health.store"),
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: Schema(syncedModels + [WorkoutHealthData.self]), configurations: synced, local)
    }

    /// Fixes up data after launch and whenever iCloud may have delivered changes.
    @MainActor
    static func tidyUp(_ context: ModelContext) {
        giveSessionsUniqueIDs(context)
        try? context.save()
    }

    /// Sessions saved before `uid` existed all received the same default value when the store was upgraded.
    @MainActor
    private static func giveSessionsUniqueIDs(_ context: ModelContext) {
        guard let sessions = try? context.fetch(FetchDescriptor<TrainingSession>()) else { return }
        var seen = Set<UUID>()
        for session in sessions {
            if seen.contains(session.uid) { session.uid = UUID() }
            seen.insert(session.uid)
        }
    }
}
