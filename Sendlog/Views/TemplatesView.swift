import SwiftData
import SwiftUI

/// Training templates (e.g. the sessions a coach sends), each started with one tap.
struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<TrainingSession> { $0.isTemplate }, sort: \TrainingSession.title)
    private var templates: [TrainingSession]
    @Query(filter: #Predicate<TrainingSession> { !$0.isTemplate && $0.fromTemplateID != nil })
    private var startedSessions: [TrainingSession]
    @State private var path: [TrainingSession] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(sortedTemplates) { template in
                    NavigationLink(value: template) {
                        TemplateRow(template: template, history: history(of: template)) {
                            router.open(template.startSession(in: context))
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            template.delete(in: context)
                        } label: {
                            Label("Apagar", systemImage: "trash")
                        }
                        Button {
                            path.append(template.makeTemplate(in: context))
                        } label: {
                            Label("Duplicar", systemImage: "plus.square.on.square")
                        }
                        .tint(.accentColor)
                    }
                }
            }
            .overlay {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label("Nenhum plano ainda", systemImage: "list.clipboard")
                    } description: {
                        Text("Escreva uma vez os treinos que seu treinador manda e comece cada um com um toque. Você também pode salvar qualquer treino registrado como plano pelo menu •••.")
                    } actions: {
                        newTemplateMenu { Text("Novo plano") }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Planos")
            .navigationDestination(for: TrainingSession.self) { SessionDetailView(session: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    newTemplateMenu { Image(systemName: "plus") }
                }
            }
        }
    }

    private func newTemplateMenu(@ViewBuilder label: () -> some View) -> some View {
        Menu {
            ForEach(SessionKind.allCases) { kind in
                Button {
                    let template = TrainingSession(kind: kind, title: "")
                    template.isTemplate = true
                    template.templateID = UUID()
                    context.insert(template)
                    path.append(template)
                } label: {
                    Label("Plano de \(kind.title.lowercased())", systemImage: kind.systemImage)
                }
            }
        } label: {
            label()
        }
    }

    /// Scheduled plans in week order (Monday first), then unscheduled ones by name.
    private var sortedTemplates: [TrainingSession] {
        func firstDay(_ plan: TrainingSession) -> Int {
            Weekday.mondayFirst.firstIndex(where: plan.scheduledWeekdays.contains) ?? 7
        }
        return templates.sorted { (firstDay($0), $0.title) < (firstDay($1), $1.title) }
    }

    private func history(of template: TrainingSession) -> [TrainingSession] {
        startedSessions.filter { $0.fromTemplateID == template.templateID }
    }
}

private struct TemplateRow: View {
    let template: TrainingSession
    let history: [TrainingSession]
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.kind.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.15), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.displayTitle).font(.headline)
                if !template.scheduledWeekdays.isEmpty {
                    Text(Weekday.list(template.scheduledWeekdays))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                if !template.summary.isEmpty || !template.routineBlocks.isEmpty {
                    HStack(spacing: 6) {
                        if !template.summary.isEmpty { Text(template.summary) }
                        ForEach(RoutineKind.allCases.filter(template.hasRoutine)) { kind in
                            Image(systemName: kind.systemImage).accessibilityLabel(kind.title)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Text(lastDone).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Button("Começar", action: onStart)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
    }

    private var lastDone: String {
        guard let last = history.map(\.date).max() else { return "Ainda não feito" }
        let times = history.count == 1 ? "1 vez" : "\(history.count) vezes"
        return "Feito \(times) · último \(last.formatted(.relative(presentation: .named)))"
    }
}
