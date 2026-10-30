import SwiftData
import SwiftUI

enum LogPeriod: String, CaseIterable, Identifiable {
    case week, month, quarter, year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Semana"
        case .month: "Mês"
        case .quarter: "3 meses"
        case .year: "Ano"
        }
    }

    /// The period `offset` steps back from the current one (0 = current, -1 = previous, …).
    func interval(offset: Int, now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        let (component, length): (Calendar.Component, Int) = switch self {
        case .week: (.weekOfYear, 1)
        case .month: (.month, 1)
        case .quarter: (.month, 3)
        case .year: (.year, 1)
        }
        let unit: Calendar.Component = self == .week ? .weekOfYear : self == .year ? .year : .month
        let currentStart = calendar.dateInterval(of: unit, for: now)?.start ?? now
        // "3 meses" ends with the current month.
        let latestStart = self == .quarter ? calendar.date(byAdding: .month, value: -2, to: currentStart)! : currentStart
        let start = calendar.date(byAdding: component, value: offset * length, to: latestStart)!
        let end = calendar.date(byAdding: component, value: length, to: start)!
        return DateInterval(start: start, end: end)
    }

    func label(offset: Int) -> String {
        switch (self, offset) {
        case (.week, 0): return "Esta semana"
        case (.week, -1): return "Semana passada"
        case (.month, 0): return "Este mês"
        case (.month, -1): return "Mês passado"
        case (.quarter, 0): return "Últimos 3 meses"
        case (.year, 0): return "Este ano"
        case (.year, -1): return "Ano passado"
        default:
            let interval = interval(offset: offset)
            let last = interval.end.addingTimeInterval(-1)
            switch self {
            case .week: return "\(interval.start.formatted(.dateTime.day().month())) – \(last.formatted(.dateTime.day().month()))"
            case .month: return interval.start.formatted(.dateTime.month(.wide).year())
            case .quarter: return "\(interval.start.formatted(.dateTime.month(.abbreviated))) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
            case .year: return interval.start.formatted(.dateTime.year())
            }
        }
    }

    var previousName: String {
        switch self {
        case .week: "na semana anterior"
        case .month: "no mês anterior"
        case .quarter: "nos 3 meses anteriores"
        case .year: "no ano anterior"
        }
    }
}

struct SessionListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<TrainingSession> { !$0.isTemplate }, sort: \TrainingSession.date, order: .reverse)
    private var sessions: [TrainingSession]
    @Query(filter: #Predicate<TrainingSession> { $0.isTemplate }, sort: \TrainingSession.title)
    private var templates: [TrainingSession]
    @Query private var healthData: [WorkoutHealthData]
    @AppStorage("logPeriod") private var period: LogPeriod = .month
    @State private var offset = 0
    @State private var showingImport = false
    @State private var showingSettings = false

    var body: some View {
        @Bindable var router = router
        let interval = period.interval(offset: offset)
        let inPeriod = sessions.filter { interval.contains($0.date) }
        let healthBySession = Dictionary(healthData.map { ($0.sessionID, $0) }, uniquingKeysWith: { first, _ in first })

        NavigationStack(path: $router.logPath) {
            List {
                TodaySection(templates: templates, sessions: sessions)
                Section {
                    PeriodSummaryView(
                        period: $period,
                        offset: $offset,
                        sessions: inPeriod,
                        previous: sessions.filter { period.interval(offset: offset - 1).contains($0.date) }
                    )
                }
                ForEach(sessionsByMonth(inPeriod), id: \.month) { group in
                    Section(group.month.formatted(.dateTime.month(.wide).year())) {
                        ForEach(group.sessions) { session in
                            NavigationLink(value: session) {
                                SessionRow(session: session, health: healthBySession[session.uid])
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    session.delete(in: context)
                                } label: {
                                    Label("Apagar", systemImage: "trash")
                                }
                                Button {
                                    router.logPath.append(session.makeCopy(in: context))
                                } label: {
                                    Label("Repetir", systemImage: "arrow.clockwise")
                                }
                                .tint(.accentColor)
                            }
                        }
                    }
                }
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Nenhum treino ainda",
                        systemImage: "figure.climbing",
                        description: Text("Toque em + para registrar um treino, começar um dos seus planos ou importar um treino do Apple Watch.")
                    )
                    .listRowBackground(Color.clear)
                }
                if inPeriod.isEmpty && !sessions.isEmpty {
                    Text("Nenhum treino neste período.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .onChange(of: period) { offset = 0 }
            .navigationTitle("Treinos")
            .navigationDestination(for: TrainingSession.self) { SessionDetailView(session: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape").accessibilityLabel("Ajustes")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if !templates.isEmpty {
                            Menu {
                                ForEach(templates) { template in
                                    Button {
                                        router.open(template.startSession(in: context))
                                    } label: {
                                        Label(template.displayTitle, systemImage: template.kind.systemImage)
                                    }
                                }
                            } label: {
                                Label("Começar um plano", systemImage: "list.clipboard")
                            }
                            Divider()
                        }
                        ForEach(SessionKind.allCases) { kind in
                            Button {
                                newSession(kind)
                            } label: {
                                Label("Treino de \(kind.title.lowercased())", systemImage: kind.systemImage)
                            }
                        }
                        Divider()
                        Button {
                            showingImport = true
                        } label: {
                            Label("Importar do Apple Watch", systemImage: "applewatch")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingImport) {
                HealthImportView { workout in
                    let session = TrainingSession(kind: workout.suggestedKind)
                    context.insert(session)
                    session.apply(workout, in: context)
                    router.logPath.append(session)
                }
            }
        }
    }

    private func sessionsByMonth(_ sessions: [TrainingSession]) -> [(month: Date, sessions: [TrainingSession])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sessions) { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
        return groups
            .map { (month: $0.key, sessions: $0.value) }
            .sorted { $0.month > $1.month }
    }

    private func newSession(_ kind: SessionKind) {
        let session = TrainingSession(kind: kind)
        session.gymName = TrainingSession.lastGym(in: context)
        context.insert(session)
        router.logPath.append(session)
    }
}

private struct SessionRow: View {
    let session: TrainingSession
    let health: WorkoutHealthData?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.kind.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.15), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayTitle).font(.headline)
                Text([session.date.formatted(.dateTime.weekday(.abbreviated).day().month()), session.gymName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if !session.summary.isEmpty {
                        Text(session.summary)
                    }
                    ForEach(RoutineKind.allCases.filter(session.hasRoutine)) { kind in
                        Image(systemName: kind.systemImage).accessibilityLabel(kind.title)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let health {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "applewatch").foregroundStyle(.secondary)
                    if let kcal = health.activeEnergyKcal {
                        Text("\(Int(kcal)) kcal").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// The plans scheduled for today, each one tap away from becoming today's session.
private struct TodaySection: View {
    let templates: [TrainingSession]
    let sessions: [TrainingSession]
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router

    var body: some View {
        let today = Weekday.today
        let planned = templates.filter { $0.scheduledWeekdays.contains(today) }
        let hasSchedule = templates.contains { !$0.scheduledWeekdays.isEmpty }

        if !planned.isEmpty || hasSchedule {
            Section {
                if planned.isEmpty {
                    Label("Hoje é dia de descanso", systemImage: "moon.zzz")
                        .foregroundStyle(.secondary)
                }
                ForEach(planned) { plan in
                    let done = sessions.first { $0.fromTemplateID == plan.templateID && Calendar.current.isDateInToday($0.date) }
                    HStack(spacing: 12) {
                        Image(systemName: plan.kind.systemImage)
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 40, height: 40)
                            .background(.tint.opacity(0.15), in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.displayTitle).font(.headline)
                            Text(done == nil ? plan.summary : "Já começou hoje")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let done {
                            Button("Abrir") { router.open(done) }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Começar") { router.open(plan.startSession(in: context)) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .buttonBorderShape(.capsule)
                }
            } header: {
                Text("Treino de hoje · \(Weekday.long(today))")
            }
        }
    }
}

/// Totals for the selected period, with a period-size picker and arrows to step back in time.
private struct PeriodSummaryView: View {
    @Binding var period: LogPeriod
    @Binding var offset: Int
    let sessions: [TrainingSession]
    let previous: [TrainingSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Período", selection: $period) {
                ForEach(LogPeriod.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    offset -= 1
                } label: {
                    Image(systemName: "chevron.left").accessibilityLabel("Período anterior")
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(period.label(offset: offset)).font(.headline)
                    Text(comparison).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    offset += 1
                } label: {
                    Image(systemName: "chevron.right").accessibilityLabel("Próximo período")
                }
                .disabled(offset >= 0)
            }
            .buttonStyle(.borderless)

            HStack {
                stat("\(sessions.count)", "treinos")
                stat("\(sessions.filter { $0.kind == .climbing }.count)", "escalada")
                stat("\(sessions.filter { $0.kind == .strength }.count)", "musculação")
                stat(hours, "de treino")
            }

            let ascents = sessions.flatMap(\.climbingBlocks).reduce(0) { $0 + $1.completedAscents }
            let hardest = ClimbingAnalytics.records(in: sessions).filter(\.sent).compactMap(\.grade).max()
            if ascents > 0 {
                HStack {
                    stat("\(ascents)", "subidas")
                    stat(hardest.map(Grade.label) ?? "–", "maior grau")
                    stat("\(Set(sessions.map { Calendar.current.startOfDay(for: $0.date) }).count)", "dias de treino")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var hours: String {
        let minutes = sessions.compactMap(\.durationMinutes).reduce(0, +)
        switch minutes {
        case ..<60: return "\(minutes)m"
        case ..<600 where minutes % 60 != 0: return "\(minutes / 60)h \(minutes % 60)m"
        default: return "\(minutes / 60)h"
        }
    }

    private var comparison: String {
        let difference = sessions.count - previous.count
        switch difference {
        case 0: return "Mesmo número de treinos que \(period.previousName)"
        case 1...: return "\(difference) treino\(difference == 1 ? "" : "s") a mais que \(period.previousName)"
        default: return "\(-difference) treino\(difference == -1 ? "" : "s") a menos que \(period.previousName)"
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.title2.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
