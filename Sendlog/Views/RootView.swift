import Observation
import SwiftUI

enum TabID: String { case log, plans, progress }

/// Shared navigation state, so starting a template from Plans can open the new session in Log.
@Observable
final class AppRouter {
    var tab: TabID
    var logPath: [TrainingSession] = []

    init(tab: TabID) { self.tab = tab }

    func open(_ session: TrainingSession) {
        tab = .log
        logPath = [session]
    }
}

struct RootView: View {
    @State private var router = AppRouter(tab: RootView.initialTab)
    @State private var showingStoreError = DataStore.isTemporary

    private static var initialTab: TabID {
        #if DEBUG
        // Launching with `-openProgress` or `-openPlans` picks the starting tab (handy for simulator screenshots).
        if CommandLine.arguments.contains("-openProgress") { return .progress }
        if CommandLine.arguments.contains("-openPlans") { return .plans }
        #endif
        return .log
    }

    var body: some View {
        TabView(selection: $router.tab) {
            Tab("Treinos", systemImage: "list.bullet", value: .log) {
                SessionListView()
            }
            Tab("Planos", systemImage: "list.clipboard", value: .plans) {
                TemplatesView()
            }
            Tab("Progresso", systemImage: "chart.bar.xaxis", value: .progress) {
                StatsView()
            }
        }
        .environment(router)
        .alert("Não foi possível abrir seus dados", isPresented: $showingStoreError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("O que você registrar agora não será salvo. Feche o app e abra de novo; se o problema continuar, escreva para o suporte.")
        }
    }
}
