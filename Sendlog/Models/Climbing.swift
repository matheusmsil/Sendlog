import Foundation
import SwiftData

enum ClimbingStyle: String, CaseIterable, Identifiable {
    case circuit, repeats, projecting, free

    var id: String { rawValue }

    var title: String {
        switch self {
        case .circuit: "Circuito"
        case .repeats: "Repetições"
        case .projecting: "Boulder máximo"
        case .free: "Escalada livre"
        }
    }

    var explanation: String {
        switch self {
        case .circuit: "Suba cada boulder uma vez, em sequência."
        case .repeats: "Suba cada boulder um número fixo de vezes."
        case .projecting: "Trabalhe um boulder no seu limite e conte as entradas."
        case .free: "Escale o que quiser e registre o que mandou."
        }
    }

    var defaultRepsPerBoulder: Int { self == .repeats ? 2 : 1 }
}

@Model
final class ClimbingBlock {
    var order: Int = 0
    var styleRaw: String = ClimbingStyle.free.rawValue
    /// A constraint applied to every climb in the block, e.g. "Um pé só". Empty means none.
    var variation: String = ""
    var repsPerBoulder: Int = 1
    var notes: String = ""
    var session: TrainingSession?

    @Relationship(deleteRule: .cascade, originalName: "boulders", inverse: \Boulder.block)
    var boulderList: [Boulder]? = []

    static let variationPresets = [
        "Hover hands", "Um pé só", "Um braço só", "Sem pés", "Pé silencioso", "Downclimb", "Flash",
    ]

    init(order: Int, style: ClimbingStyle, variation: String = "", repsPerBoulder: Int) {
        self.order = order
        self.styleRaw = style.rawValue
        self.variation = variation
        self.repsPerBoulder = repsPerBoulder
    }

    var boulders: [Boulder] {
        get { boulderList ?? [] }
        set { boulderList = newValue }
    }

    var style: ClimbingStyle {
        get { ClimbingStyle(rawValue: styleRaw) ?? .free }
        set { styleRaw = newValue.rawValue }
    }

    var title: String { variation.isEmpty ? style.title : "\(style.title) · \(variation)" }

    var sortedBoulders: [Boulder] { boulders.sorted { $0.order < $1.order } }

    var completedAscents: Int { boulders.reduce(0) { $0 + $1.completedReps } }

    var targetAscents: Int { boulders.count * repsPerBoulder }

    func addBoulder() {
        boulders.append(Boulder(order: (boulders.map(\.order).max() ?? -1) + 1))
    }
}

enum WallAngle: String, CaseIterable, Identifiable {
    case slab, vertical, overhang, roof

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum HoldType: String, CaseIterable, Identifiable {
    case jug, crimp, sloper, pinch, pocket, volume

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var plural: String { self == .pinch ? "Pinches" : "\(title)s" }
}

@Model
final class Boulder {
    var order: Int = 0
    var name: String = ""
    var grade: String = ""
    var completedReps: Int = 0
    /// Used mainly when projecting.
    var attempts: Int = 0
    // Optional tags that power the style and weakness analysis.
    var angleRaw: String = ""
    /// Comma-separated `HoldType` raw values.
    var holdTypesRaw: String = ""
    var flashed: Bool = false
    var block: ClimbingBlock?

    init(order: Int, name: String = "", grade: String = "") {
        self.order = order
        self.name = name
        self.grade = grade
    }

    var angle: WallAngle? {
        get { WallAngle(rawValue: angleRaw) }
        set { angleRaw = newValue?.rawValue ?? "" }
    }

    var holdTypes: Set<HoldType> {
        get { Set(holdTypesRaw.split(separator: ",").compactMap { HoldType(rawValue: String($0)) }) }
        set { holdTypesRaw = HoldType.allCases.filter(newValue.contains).map(\.rawValue).joined(separator: ",") }
    }

    var isSent: Bool { completedReps > 0 }

    /// Sent first try: marked as flashed, or sent with exactly one counted attempt.
    var isFlash: Bool { isSent && (flashed || attempts == 1) }

    var tagSummary: String {
        var parts: [String] = []
        if let angle { parts.append(angle.title) }
        let holds = HoldType.allCases.filter(holdTypes.contains).map(\.title)
        if !holds.isEmpty { parts.append(holds.joined(separator: ", ")) }
        if isFlash { parts.append("Flash") }
        return parts.joined(separator: " · ")
    }
}
