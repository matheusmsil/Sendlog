import Foundation
import SwiftData

/// Warm-up and accessory work that can be added to any session.
enum RoutineKind: String, CaseIterable, Identifiable {
    case activation, mobility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activation: "Ativação"
        case .mobility: "Mobilidade"
        }
    }

    var systemImage: String {
        switch self {
        case .activation: "bolt.fill"
        case .mobility: "figure.flexibility"
        }
    }

    /// Suggested exercises with their usual prescription.
    var presets: [RoutinePreset] {
        switch self {
        case .mobility: [
            RoutinePreset("Tronco em 3 Apoios", sets: 1, amount: 10),
            RoutinePreset("Tronco em Quatro Apoios", sets: 1, amount: 10),
            RoutinePreset("Punhos Girando", sets: 1, amount: 10),
            RoutinePreset("Dedos em Três Pontos", sets: 1, amount: 10),
            RoutinePreset("Dedos em Pinça", sets: 1, amount: 10),
            RoutinePreset("Ombros com Bastão", sets: 1, amount: 10),
            RoutinePreset("Quadril 90 / 90", sets: 2, amount: 10),
            RoutinePreset("Quadril Sobre Perna Cruzada", sets: 2, amount: 10),
            RoutinePreset("Quadril e Posterior Semiajoelhado", sets: 2, amount: 10),
            RoutinePreset("Quadril Lateral Semiajoelhado", sets: 2, amount: 10),
        ]
        case .activation: [
            RoutinePreset("Escápulas com Elástico", sets: 1, amount: 10),
            RoutinePreset("Escápulas em Suspensão", sets: 1, amount: 10),
            RoutinePreset("Desenvolvimento de Ombros com Miniband", sets: 2, amount: 8, prescription: "2 × 8 a 10"),
            RoutinePreset("Finger Curl com Elástico", sets: 1, amount: 10),
            RoutinePreset("Abdominal Vela", sets: 2, amount: 8, prescription: "2 × 8 a 10"),
            RoutinePreset("Face Pull com Elástico", sets: 1, amount: 10),
            RoutinePreset("ITWY Curvado", sets: 1, amount: 5),
            RoutinePreset("Flexão de Joelhos Alternada no TRX", sets: 2, amount: 6, prescription: "2 × 6 a 10"),
            RoutinePreset("Crucifixo Inverso com Halteres", sets: 1, amount: 5, prescription: "1 × 5 a 7"),
            RoutinePreset("Hollow Hold", sets: 2, amount: 20, measure: .seconds, prescription: "2 × 20 a 30\""),
            RoutinePreset("Cossack Squat Sem Carga", sets: 2, amount: 8, prescription: "2 × 8 a 10"),
            RoutinePreset("Stiff Unilateral", sets: 2, amount: 8, prescription: "2 × 8 a 10"),
            RoutinePreset("Agachamento com Salto", sets: 2, amount: 8, prescription: "2 × 8 a 10"),
            RoutinePreset("L Sit em Suspensão", sets: 2, amount: 15, measure: .seconds, prescription: "2 × 15 a 25\""),
        ]
        }
    }
}

struct RoutinePreset {
    let name: String
    let sets: Int
    let amount: Int
    let measure: RoutineMeasure
    /// The coach's original wording when it's a range, e.g. "2 × 8 a 10".
    let prescription: String

    init(_ name: String, sets: Int, amount: Int, measure: RoutineMeasure = .reps, prescription: String = "") {
        self.name = name
        self.sets = sets
        self.amount = amount
        self.measure = measure
        self.prescription = prescription
    }
}

enum RoutineMeasure: String, CaseIterable, Identifiable {
    case reps, seconds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reps: "Repetições"
        case .seconds: "Tempo"
        }
    }

    var step: Int { self == .seconds ? 5 : 1 }

    func format(_ amount: Int) -> String {
        switch self {
        case .reps: return "\(amount) reps"
        case .seconds: return amount >= 60 && amount % 60 == 0 ? "\(amount / 60) min" : amount >= 60 ? "\(amount / 60)min \(amount % 60)s" : "\(amount)\""
        }
    }
}

@Model
final class RoutineBlock {
    var order: Int = 0
    var kindRaw: String = RoutineKind.mobility.rawValue
    var session: TrainingSession?

    @Relationship(deleteRule: .cascade, originalName: "items", inverse: \RoutineItem.block)
    var itemList: [RoutineItem]? = []

    init(order: Int, kind: RoutineKind) {
        self.order = order
        self.kindRaw = kind.rawValue
    }

    var items: [RoutineItem] {
        get { itemList ?? [] }
        set { itemList = newValue }
    }

    var kind: RoutineKind {
        get { RoutineKind(rawValue: kindRaw) ?? .mobility }
        set { kindRaw = newValue.rawValue }
    }

    var sortedItems: [RoutineItem] { items.sorted { $0.order < $1.order } }

    var completedCount: Int { items.filter(\.isDone).count }

    func addItem(name: String, measure: RoutineMeasure, amount: Int, sets: Int = 1, prescription: String = "") {
        let item = RoutineItem(
            order: (items.map(\.order).max() ?? -1) + 1,
            name: name,
            sets: sets,
            amount: amount,
            measure: measure
        )
        items.append(item)
        item.prescription = prescription
    }

    func addItem(_ preset: RoutinePreset) {
        addItem(name: preset.name, measure: preset.measure, amount: preset.amount, sets: preset.sets, prescription: preset.prescription)
    }
}

@Model
final class RoutineItem {
    var order: Int = 0
    var name: String = ""
    var sets: Int = 1
    /// Reps or seconds, depending on `measure`.
    var amount: Int = 0
    var measureRaw: String = RoutineMeasure.reps.rawValue
    var isDone: Bool = false
    var prescription: String = ""
    /// An optional link to a video showing how the exercise is done.
    var videoURL: String = ""
    var block: RoutineBlock?

    init(order: Int, name: String, sets: Int, amount: Int, measure: RoutineMeasure) {
        self.order = order
        self.name = name
        self.sets = sets
        self.amount = amount
        self.measureRaw = measure.rawValue
    }

    var measure: RoutineMeasure {
        get { RoutineMeasure(rawValue: measureRaw) ?? .reps }
        set { measureRaw = newValue.rawValue }
    }

    var video: URL? { URL(string: videoURL) }
}
