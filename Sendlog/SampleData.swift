#if DEBUG
import Foundation
import SwiftData

/// Fills an empty database with ~12 weeks of plausible training, for trying the app in the simulator.
/// Enabled by launching with the `-seedSampleData` argument (Xcode: Scheme › Run › Arguments).
enum SampleData {
    static var isRequested: Bool { CommandLine.arguments.contains("-seedSampleData") }

    private static let weeks = 24

    @MainActor
    static func seedIfEmpty(_ context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<TrainingSession>())) == 0 else { return }
        if UserDefaults.standard.double(forKey: "bodyWeightKg") == 0 {
            UserDefaults.standard.set(68.0, forKey: "bodyWeightKg")
        }
        let calendar = Calendar.current
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)!.start

        for weeksAgo in (0..<weeks).reversed() {
            let progress = Double(weeks - 1 - weeksAgo) / Double(weeks - 1)
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeek) else { continue }
            let day = { (offset: Int, hour: Int) in weekStart.addingTimeInterval(Double(offset) * 86_400 + Double(hour) * 3600) }

            addClimbing(context, date: day(1, 18), weeksAgo: weeksAgo, progress: progress)
            addStrength(context, date: day(3, 7), weeksAgo: weeksAgo, progress: progress)
            // A second climbing day most weeks, and a big extra week two weeks ago to show a load spike.
            if weeksAgo % 3 != 2 || weeksAgo == 2 {
                addClimbing(context, date: day(5, 10), weeksAgo: weeksAgo, progress: progress, isWeekend: true)
            }
            if weeksAgo == 1 {
                addClimbing(context, date: day(6, 10), weeksAgo: weeksAgo, progress: progress, isWeekend: true)
            }
        }
        addPlans(context)
    }

    /// Three generic weekly plans made from the latest sessions, linked to the past sessions they match.
    @MainActor
    private static func addPlans(_ context: ModelContext) {
        let sessions = (try? context.fetch(FetchDescriptor<TrainingSession>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        let groups: [(title: String, weekday: Int, notes: String, matches: (TrainingSession) -> Bool)] = [
            ("Técnica e limite", 2, "Aqueça bem. Repetições com pé silencioso; no limite, descanse 3 min entre as entradas.", { $0.kind == .climbing && $0.durationMinutes == 90 }),
            ("Força A", 4, "Última repetição de cada série com 1 a 2 de reserva.", { $0.kind == .strength }),
            ("Projeto e volume", 6, "Comece pelo projeto com a cabeça fresca e termine com volume em graus de conforto.", { $0.kind == .climbing && $0.durationMinutes == 120 }),
        ]
        for group in groups {
            let matching = sessions.filter(group.matches)
            guard let latest = matching.first else { continue }
            let plan = latest.makeTemplate(in: context)
            plan.title = group.title
            plan.coachNotes = group.notes
            plan.scheduledWeekdays = [group.weekday]
            for session in matching {
                session.fromTemplateID = plan.templateID
                session.title = group.title
                session.coachNotes = group.notes
            }
        }
    }

    @MainActor
    private static func addClimbing(_ context: ModelContext, date: Date, weeksAgo: Int, progress: Double, isWeekend: Bool = false) {
        guard date <= .now else { return }
        let session = TrainingSession(date: date, kind: .climbing)
        context.insert(session)
        session.gymName = isWeekend ? "Ginásio Zona Sul" : "Ginásio Centro"
        session.durationMinutes = isWeekend ? 120 : 90
        session.effort = isWeekend ? 8 : 6 + (weeksAgo % 3)

        let activation = session.addRoutineBlock(.activation)
        activation.addItem(name: "Escápulas em Suspensão", measure: .reps, amount: 10, sets: 2)
        activation.addItem(name: "Finger Curl com Elástico", measure: .reps, amount: 10)
        activation.items.forEach { $0.isDone = true }

        // Base grade rises from V3 to V5 over the period.
        let base = 3 + Int((progress * 2).rounded())
        let angles: [WallAngle] = [.vertical, .overhang, .slab, .overhang, .roof, .vertical]
        let holds: [[HoldType]] = [[.crimp], [.jug, .pinch], [.sloper], [.crimp, .pocket], [.sloper, .pinch], [.crimp]]

        // Circuit: easier boulders, mostly flashed.
        let circuit = session.addClimbingBlock(style: .circuit, variation: "", boulderCount: 6, repsPerBoulder: 1)
        for (index, boulder) in circuit.sortedBoulders.enumerated() {
            boulder.grade = "V\(base - 2 + index / 2)"
            boulder.angle = angles[index]
            boulder.holdTypes = Set(holds[index])
            // Slopers on slab are the weak spot.
            let weak = boulder.holdTypes.contains(.sloper) && (index + weeksAgo).isMultiple(of: 2)
            boulder.completedReps = weak ? 0 : 1
            boulder.flashed = !weak && index < 4
        }

        // One-leg repeats: technique drill.
        let repeats = session.addClimbingBlock(style: .repeats, variation: "Um pé só", boulderCount: 5, repsPerBoulder: 2)
        for (index, boulder) in repeats.sortedBoulders.enumerated() {
            boulder.grade = "V\(base - 3 + index / 2)"
            boulder.angle = index.isMultiple(of: 2) ? .vertical : .slab
            boulder.completedReps = index < 3 + Int(progress * 2) ? 2 : 1
        }

        // Limit bouldering near max grade.
        let limit = session.addClimbingBlock(style: .free, variation: "", boulderCount: 4, repsPerBoulder: 1)
        for (index, boulder) in limit.sortedBoulders.enumerated() {
            boulder.grade = "V\(base + index / 2)"
            boulder.angle = [WallAngle.overhang, .roof, .vertical, .slab][index]
            boulder.holdTypes = [[HoldType.crimp], [.pinch], [.crimp, .pocket], [.sloper]][index]
            boulder.completedReps = (index + weeksAgo) % 4 == 3 || index == 3 && weeksAgo % 2 == 0 ? 0 : 1
        }

        // Projects followed across sessions by name.
        if isWeekend || weeksAgo < 6 {
            let project = session.addClimbingBlock(style: .projecting, variation: "", boulderCount: 0, repsPerBoulder: 1)
            if weeksAgo >= 4 {
                project.addBoulder()
                let blueRoof = project.sortedBoulders.last!
                blueRoof.name = "Teto azul"
                blueRoof.grade = "V6"
                blueRoof.angle = .roof
                blueRoof.holdTypes = [.pinch]
                blueRoof.attempts = 4 + weeksAgo % 3
                blueRoof.completedReps = weeksAgo == 4 ? 1 : 0
            }
            if weeksAgo < 5 {
                project.addBoulder()
                let crimps = project.sortedBoulders.last!
                crimps.name = "Crimps amarelos"
                crimps.grade = "V7"
                crimps.angle = .vertical
                crimps.holdTypes = [.crimp]
                crimps.attempts = 5 + weeksAgo % 4
            }
            if weeksAgo == 1 {
                project.addBoulder()
                let flashed = project.sortedBoulders.last!
                flashed.name = "Aresta verde"
                flashed.grade = "V5"
                flashed.angle = .vertical
                flashed.attempts = 1
                flashed.completedReps = 1
            }
        }

        if weeksAgo.isMultiple(of: 2) {
            let mobility = session.addRoutineBlock(.mobility)
            mobility.addItem(name: "Quadril 90 / 90", measure: .reps, amount: 10, sets: 2)
            mobility.addItem(name: "Quadril Sobre Perna Cruzada", measure: .reps, amount: 10, sets: 2)
        }
    }

    @MainActor
    private static func addStrength(_ context: ModelContext, date: Date, weeksAgo: Int, progress: Double) {
        guard date <= .now else { return }
        let session = TrainingSession(date: date, kind: .strength)
        context.insert(session)
        session.gymName = "Ginásio Centro"
        session.durationMinutes = 60
        session.effort = 7 + weeksAgo % 2

        let exercises: [(String, Double, Double, Int)] = [
            ("Hangboard", 10, 12, 1),
            ("Barra Fixa com Carga", 5, 12.5, 4),
            ("Agachamento Búlgaro", 20, 10, 6),
            ("Stiff com Barra", 60, 20, 4),
        ]
        for (name, start, gain, reps) in exercises {
            let exercise = StrengthExercise(name: name, order: session.exercises.count)
            session.exercises.append(exercise)
            let weight = ((start + gain * progress) / 2.5).rounded() * 2.5
            for order in 0..<(name == "Hangboard" ? 5 : 4) {
                exercise.sets.append(ExerciseSet(order: order, reps: reps, weight: weight))
            }
        }
        if weeksAgo % 3 != 1 {
            session.addRoutineBlock(.mobility).addItem(name: "Ombros com Bastão", measure: .reps, amount: 10)
        }
    }
}
#endif
