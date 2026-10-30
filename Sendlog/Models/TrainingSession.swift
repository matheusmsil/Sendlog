import Foundation
import SwiftData

enum SessionKind: String, CaseIterable, Identifiable {
    case climbing, strength, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .climbing: "Escalada"
        case .strength: "Musculação"
        case .other: "Outro"
        }
    }

    var systemImage: String {
        switch self {
        case .climbing: "figure.climbing"
        case .strength: "dumbbell.fill"
        case .other: "figure.mixed.cardio"
        }
    }
}

// Every stored property has a default and every relationship is optional: iCloud sync (CloudKit) requires it.
@Model
final class TrainingSession {
    /// Stable identity across devices; links the session to its local-only Apple Health data.
    var uid: UUID = UUID()
    var date: Date = Date.now
    var kindRaw: String = SessionKind.other.rawValue
    var title: String = ""
    var notes: String = ""
    /// Perceived effort (RPE) from 1 to 10; 0 means not rated.
    var effort: Int = 0
    var durationMinutes: Int?

    // Templates are sessions written once (e.g. from a coach) and started with one tap.
    var isTemplate: Bool = false
    /// Identifies a template; sessions started from it store the same value in `fromTemplateID`.
    var templateID: UUID?
    var fromTemplateID: UUID?
    /// Instructions from the coach, copied from the template into each session.
    var coachNotes: String = ""
    /// Days a plan is scheduled on, as comma-separated `Calendar` weekdays (1 = Sunday … 7 = Saturday).
    var scheduledWeekdaysRaw: String = ""
    /// Where the session took place.
    var gymName: String = ""

    @Relationship(deleteRule: .cascade, originalName: "exercises", inverse: \StrengthExercise.session)
    var exerciseList: [StrengthExercise]? = []

    @Relationship(deleteRule: .cascade, originalName: "climbingBlocks", inverse: \ClimbingBlock.session)
    var climbingBlockList: [ClimbingBlock]? = []

    @Relationship(deleteRule: .cascade, originalName: "routineBlocks", inverse: \RoutineBlock.session)
    var routineBlockList: [RoutineBlock]? = []

    init(date: Date = .now, kind: SessionKind, title: String = "") {
        self.date = date
        self.kindRaw = kind.rawValue
        self.title = title
    }

    var exercises: [StrengthExercise] {
        get { exerciseList ?? [] }
        set { exerciseList = newValue }
    }

    var climbingBlocks: [ClimbingBlock] {
        get { climbingBlockList ?? [] }
        set { climbingBlockList = newValue }
    }

    var routineBlocks: [RoutineBlock] {
        get { routineBlockList ?? [] }
        set { routineBlockList = newValue }
    }

    var kind: SessionKind {
        get { SessionKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var scheduledWeekdays: Set<Int> {
        get { Set(scheduledWeekdaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { scheduledWeekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    var displayTitle: String { title.isEmpty ? kind.title : title }

    // SwiftData doesn't preserve the order of to-many relationships, so children carry an explicit `order`.
    var sortedExercises: [StrengthExercise] { exercises.sorted { $0.order < $1.order } }
    var sortedBlocks: [ClimbingBlock] { climbingBlocks.sorted { $0.order < $1.order } }
    var sortedRoutineBlocks: [RoutineBlock] { routineBlocks.sorted { $0.order < $1.order } }

    func hasRoutine(_ kind: RoutineKind) -> Bool { routineBlocks.contains { $0.kind == kind } }

    var summary: String {
        switch kind {
        case .strength:
            let sets = exercises.reduce(0) { $0 + $1.sets.count }
            return "\(Self.count(exercises.count, "exercício", "exercícios")) · \(Self.count(sets, "série", "séries"))"
        case .climbing:
            let boulders = climbingBlocks.reduce(0) { $0 + $1.boulders.count }
            var parts: [String] = []
            if isTemplate {
                parts.append(Self.count(climbingBlocks.count, "bloco", "blocos"))
                if boulders > 0 { parts.append("\(boulders) boulders") }
            } else {
                let ascents = climbingBlocks.reduce(0) { $0 + $1.completedAscents }
                parts.append("\(boulders) boulders · \(Self.count(ascents, "subida", "subidas"))")
            }
            if !exercises.isEmpty { parts.append(Self.count(exercises.count, "exercício", "exercícios")) }
            return parts.joined(separator: " · ")
        case .other:
            return durationMinutes.map { "\($0) min" } ?? ""
        }
    }

    private static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }

    @discardableResult
    func addExercise(named name: String) -> StrengthExercise {
        let exercise = StrengthExercise(name: name, order: (exercises.map(\.order).max() ?? -1) + 1)
        exercises.append(exercise)
        exercise.addSet()
        return exercise
    }

    @discardableResult
    func addClimbingBlock(style: ClimbingStyle, variation: String, boulderCount: Int, repsPerBoulder: Int) -> ClimbingBlock {
        let block = ClimbingBlock(
            order: (climbingBlocks.map(\.order).max() ?? -1) + 1,
            style: style,
            variation: variation,
            repsPerBoulder: repsPerBoulder
        )
        climbingBlocks.append(block)
        for _ in 0..<boulderCount { block.addBoulder() }
        return block
    }

    @discardableResult
    func addRoutineBlock(_ kind: RoutineKind) -> RoutineBlock {
        let block = RoutineBlock(order: (routineBlocks.map(\.order).max() ?? -1) + 1, kind: kind)
        routineBlocks.append(block)
        return block
    }

    /// Starts today's session from this template.
    func startSession(in context: ModelContext) -> TrainingSession {
        let session = makeCopy(in: context)
        session.fromTemplateID = templateID
        session.gymName = Self.lastGym(in: context)
        return session
    }

    /// The gym of the most recent session that has one, to prefill new sessions.
    static func lastGym(in context: ModelContext) -> String {
        var recent = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { !$0.isTemplate && $0.gymName != "" },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        recent.fetchLimit = 1
        return (try? context.fetch(recent).first?.gymName) ?? ""
    }

    /// Saves this session's structure as a reusable template.
    func makeTemplate(in context: ModelContext) -> TrainingSession {
        let template = makeCopy(in: context)
        template.title = displayTitle
        template.gymName = ""
        template.isTemplate = true
        template.templateID = UUID()
        return template
    }

    /// Deletes the session along with its Apple Health data, which lives in a separate local store.
    func delete(in context: ModelContext) {
        if let health = healthData(in: context) { context.delete(health) }
        context.delete(self)
    }

    /// Creates a fresh session with the same structure (exercises, weights, boulders) but no progress or watch data.
    func makeCopy(in context: ModelContext) -> TrainingSession {
        let copy = TrainingSession(kind: kind, title: title)
        context.insert(copy)
        copy.coachNotes = coachNotes
        copy.gymName = gymName
        for block in sortedRoutineBlocks {
            let newBlock = RoutineBlock(order: block.order, kind: block.kind)
            copy.routineBlocks.append(newBlock)
            for item in block.sortedItems {
                let newItem = RoutineItem(order: item.order, name: item.name, sets: item.sets, amount: item.amount, measure: item.measure)
                newBlock.items.append(newItem)
                newItem.prescription = item.prescription
                newItem.videoURL = item.videoURL
            }
        }
        for exercise in sortedExercises {
            let newExercise = StrengthExercise(name: exercise.name, order: exercise.order)
            copy.exercises.append(newExercise)
            newExercise.prescription = exercise.prescription
            newExercise.videoURL = exercise.videoURL
            for set in exercise.sortedSets {
                newExercise.sets.append(ExerciseSet(order: set.order, reps: set.reps, weight: set.weight))
            }
        }
        for block in sortedBlocks {
            let newBlock = ClimbingBlock(order: block.order, style: block.style, variation: block.variation, repsPerBoulder: block.repsPerBoulder)
            copy.climbingBlocks.append(newBlock)
            newBlock.notes = block.notes
            for boulder in block.sortedBoulders {
                let newBoulder = Boulder(order: boulder.order, name: boulder.name, grade: boulder.grade)
                newBlock.boulders.append(newBoulder)
                newBoulder.angleRaw = boulder.angleRaw
                newBoulder.holdTypesRaw = boulder.holdTypesRaw
            }
        }
        return copy
    }
}
