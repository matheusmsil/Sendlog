import SwiftData
import SwiftUI

/// Edits a logged session, or a plan (template) when `session.isTemplate` is set.
struct SessionDetailView: View {
    @Bindable var session: TrainingSession
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<TrainingSession> { !$0.isTemplate && $0.gymName != "" })
    private var sessionsWithGym: [TrainingSession]
    @Query private var healthData: [WorkoutHealthData]
    @State private var showingImport = false
    @State private var savedAsPlan = false

    var body: some View {
        Form {
            if session.isTemplate {
                Section {
                    TextField("Nome do plano, ex.: Escalada 01", text: $session.title)
                    typePicker
                } footer: {
                    Text("Monte o treino uma vez: blocos, boulders, séries e cargas. Toque em Começar sempre que for fazê-lo.")
                }
                Section {
                    WeekdayPicker(selection: $session.scheduledWeekdays)
                } header: {
                    Text("Dias da semana")
                } footer: {
                    Text("Nesses dias, o plano aparece em \"Treino de hoje\" na tela Treinos.")
                }
                Section("Notas do treinador") {
                    TextField("Instruções, intervalos, foco…", text: $session.coachNotes, axis: .vertical)
                        .lineLimit(3...12)
                }
            } else {
                if !session.coachNotes.isEmpty {
                    Section("Notas do treinador") {
                        Text(session.coachNotes).font(.subheadline)
                    }
                }
                Section {
                    TextField("Título (opcional)", text: $session.title)
                    typePicker
                    DatePicker("Data", selection: $session.date)
                    gymField
                    LabeledContent("Duração") {
                        TextField("min", value: $session.durationMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Esforço (PSE)", selection: $session.effort) {
                        Text("–").tag(0)
                        ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                    }
                }

                watchSection
            }

            RoutineSections(session: session)

            switch session.kind {
            case .strength:
                StrengthSections(session: session)
            case .climbing:
                ClimbingSections(session: session)
                // Climbing days can include strength work such as Finger Pull.
                StrengthSections(session: session)
            case .other:
                EmptyView()
            }

            Section {
                AddRoutineBlockButtons(session: session)
            } footer: {
                Text("Blocos de ativação e mobilidade aparecem antes do treino principal.")
            }

            if !session.isTemplate {
                Section("Anotações") {
                    TextField("Como foi o treino?", text: $session.notes, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
        }
        .navigationTitle(session.isTemplate ? (session.title.isEmpty ? "Novo plano" : session.title) : session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if session.isTemplate {
                    Button("Começar") {
                        router.open(session.startSession(in: context))
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Menu {
                        Button {
                            _ = session.makeTemplate(in: context)
                            savedAsPlan = true
                        } label: {
                            Label("Salvar como plano", systemImage: "list.clipboard")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .alert("Salvo como plano", isPresented: $savedAsPlan) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ele está na aba Planos. Da próxima vez, é só tocar em Começar.")
        }
        .sheet(isPresented: $showingImport) {
            HealthImportView { session.apply($0, in: context) }
        }
    }

    private var typePicker: some View {
        Picker("Tipo", selection: $session.kind) {
            ForEach(SessionKind.allCases) { kind in
                Label(kind.title, systemImage: kind.systemImage).tag(kind)
            }
        }
    }

    /// Free text, with the gyms you've already used one tap away.
    private var gymField: some View {
        let gyms = Dictionary(grouping: sessionsWithGym.map(\.gymName)) { $0 }
            .sorted { $0.value.count > $1.value.count }
            .map(\.key)
            .filter { $0 != session.gymName }

        return LabeledContent("Ginásio") {
            HStack {
                TextField("Nome do ginásio", text: $session.gymName)
                    .multilineTextAlignment(.trailing)
                if !gyms.isEmpty {
                    Menu {
                        ForEach(gyms, id: \.self) { gym in
                            Button(gym) { session.gymName = gym }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down").accessibilityLabel("Ginásios usados")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder
    private var watchSection: some View {
        Section {
            if let health = healthData.first(where: { $0.sessionID == session.uid }) {
                if let kcal = health.activeEnergyKcal {
                    LabeledContent("Energia ativa", value: "\(Int(kcal)) kcal")
                }
                if let avg = health.averageHeartRate {
                    LabeledContent("Frequência cardíaca média", value: "\(Int(avg)) bpm")
                }
                if let max = health.maxHeartRate {
                    LabeledContent("Frequência cardíaca máxima", value: "\(Int(max)) bpm")
                }
                if !health.sourceName.isEmpty {
                    LabeledContent("Origem", value: health.sourceName)
                }
                Button("Desvincular treino", role: .destructive) { session.unlinkWatchWorkout(in: context) }
            } else {
                Button {
                    showingImport = true
                } label: {
                    Label("Vincular treino do Apple Watch", systemImage: "applewatch")
                }
            }
        } header: {
            Text("Apple Watch")
        } footer: {
            Text("Os dados do app Saúde ficam só neste iPhone e não vão para o backup no iCloud.")
        }
    }
}

/// Seven toggle chips, Monday first.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.mondayFirst, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(Weekday.short(day))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary), in: .rect(cornerRadius: 8))
                        .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
