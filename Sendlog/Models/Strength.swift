import Foundation
import SwiftData

@Model
final class StrengthExercise {
    var name: String = ""
    var order: Int = 0
    /// The coach's prescription, e.g. "3 × 4 a 6 · 120\" · PSE 9".
    var prescription: String = ""
    /// An optional link to a video showing how the exercise is done.
    var videoURL: String = ""
    var session: TrainingSession?

    @Relationship(deleteRule: .cascade, originalName: "sets", inverse: \ExerciseSet.exercise)
    var setList: [ExerciseSet]? = []

    /// Suggested strength exercises.
    static let presets = [
        "Barra Fixa com Carga", "Apoio de Frente", "Remada Unilateral com Halter",
        "Extensão de Punho com Halter", "Rotação Externa de Punho", "Finger Pull",
        "Salto no Caixote Partida Sentado", "Agachamento Búlgaro", "Stiff com Barra", "Ponte Alternada no Step",
        "Hangboard", "Agachamento", "Levantamento Terra", "Supino", "Desenvolvimento",
    ]

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }

    var sets: [ExerciseSet] {
        get { setList ?? [] }
        set { setList = newValue }
    }

    var video: URL? { URL(string: videoURL) }

    var sortedSets: [ExerciseSet] { sets.sorted { $0.order < $1.order } }

    var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }

    var totalVolume: Double { sets.reduce(0) { $0 + Double($1.reps) * $1.weight } }

    /// Adds a set that repeats the previous one, which is what you usually do next.
    func addSet() {
        let last = sortedSets.last
        sets.append(ExerciseSet(order: (last?.order ?? -1) + 1, reps: last?.reps ?? 10, weight: last?.weight ?? 0))
    }
}

@Model
final class ExerciseSet {
    var order: Int = 0
    var reps: Int = 0
    /// Weight in kilograms.
    var weight: Double = 0
    var exercise: StrengthExercise?

    init(order: Int, reps: Int, weight: Double) {
        self.order = order
        self.reps = reps
        self.weight = weight
    }
}
