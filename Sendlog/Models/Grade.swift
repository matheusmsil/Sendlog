import Foundation

/// Converts free-text boulder grades to the V-scale so they can be compared and charted.
/// Understands V-scale ("V4", "v4+", "VB") and Fontainebleau ("6B+", "7a").
enum Grade {
    private static let fontToV: [String: Int] = [
        "3": -1, "4": 0, "4+": 0, "5": 1, "5+": 2,
        "6A": 3, "6A+": 3, "6B": 4, "6B+": 4, "6C": 5, "6C+": 5,
        "7A": 6, "7A+": 7, "7B": 8, "7B+": 8, "7C": 9, "7C+": 10,
        "8A": 11, "8A+": 12, "8B": 13, "8B+": 14, "8C": 15, "8C+": 16, "9A": 17,
    ]

    /// Returns the V grade, with VB as -1, or nil if the text isn't a recognised grade.
    static func vScale(_ raw: String) -> Int? {
        let grade = raw.trimmingCharacters(in: .whitespaces).uppercased()
        if grade == "VB" { return -1 }
        if grade.hasPrefix("V") {
            // "V4-5" counts as V4.
            return Int(grade.dropFirst().prefix { $0.isNumber })
        }
        return fontToV[grade]
    }

    static func label(_ vScale: Int) -> String { vScale < 0 ? "VB" : "V\(vScale)" }
}
