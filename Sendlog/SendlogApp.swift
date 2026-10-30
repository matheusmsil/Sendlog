import SwiftData
import SwiftUI

@main
struct SendlogApp: App {
    @State private var health = HealthKitManager()
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        container = DataStore.makeContainer()
        #if DEBUG
        if SampleData.isRequested { SampleData.seedIfEmpty(container.mainContext) }
        #endif
        DataStore.tidyUp(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(health)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) {
            if scenePhase == .active { DataStore.tidyUp(container.mainContext) }
        }
    }
}
