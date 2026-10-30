import Foundation

/// Weekday names in Portuguese, using `Calendar` weekday numbers (1 = Sunday … 7 = Saturday).
enum Weekday {
    /// Monday first, the way training weeks are usually written.
    static let mondayFirst = [2, 3, 4, 5, 6, 7, 1]

    static func short(_ weekday: Int) -> String {
        ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"][weekday - 1]
    }

    static func long(_ weekday: Int) -> String {
        ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"][weekday - 1]
    }

    /// e.g. "Ter · Sáb", in Monday-first order.
    static func list(_ weekdays: Set<Int>) -> String {
        mondayFirst.filter(weekdays.contains).map(short).joined(separator: " · ")
    }

    static var today: Int { Calendar.current.component(.weekday, from: .now) }
}
