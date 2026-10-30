import Charts
import SwiftUI

/// Chart colors, validated for color-blind separation in light and dark mode.
/// Each entity keeps its color on every chart (climbing is always blue, strength always orange).
enum ChartPalette {
    static let climbing = Color(light: 0x2A78D6, dark: 0x3987E5)
    static let strength = Color(light: 0xEB6834, dark: 0xD95926)
    static let other = Color(light: 0x1BAF7A, dark: 0x199E70)
    static let prep = Color(light: 0x6250D6, dark: 0x9085E9)
    static let flash = Color(light: 0xEDA100, dark: 0xC98500)
    /// A neutral reference series, e.g. a median next to a maximum.
    static let reference = Color(light: 0x8A8984, dark: 0x9C9B96)
    static let rest = Color(light: 0xF0EFEC, dark: 0x383835)
    /// Sequential blue, light to heavy load (flipped toward brighter in dark mode).
    static let loadLevels = [
        Color(light: 0x86B6EF, dark: 0x184F95),
        Color(light: 0x5598E7, dark: 0x2A78D6),
        Color(light: 0x2A78D6, dark: 0x5598E7),
        Color(light: 0x184F95, dark: 0x9EC5F4),
    ]
    // Status colors are reserved for zones and always paired with an icon and label.
    static let good = Color(light: 0x0CA30C, dark: 0x0CA30C)
    static let warning = Color(light: 0xFAB219, dark: 0xFAB219)
    static let critical = Color(light: 0xD03B3B, dark: 0xD03B3B)
    /// The List row background, used to ring points so they stay legible over lines.
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

extension SessionKind {
    var chartColor: Color {
        switch self {
        case .climbing: ChartPalette.climbing
        case .strength: ChartPalette.strength
        case .other: ChartPalette.other
        }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

extension TrainingStats {
    /// Bars stay thin: at most 24pt, narrower as more weeks are shown.
    var barWidth: MarkDimension { .fixed(min(24, 200 / CGFloat(max(weeks.count, 1)))) }
}

extension View {
    /// A week-based x axis showing about five date labels.
    func weekAxis(_ stats: TrainingStats) -> some View {
        chartXScale(domain: stats.xDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: max(1, stats.weeks.count / 5))) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                }
            }
    }
}

/// A chart title that shows details for the selected mark, or a default subtitle.
struct ChartHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}

extension View {
    /// A y axis labelled with V grades.
    func gradeAxis(_ grades: [Double]) -> some View {
        let low = (grades.min() ?? 0) - 1
        let high = (grades.max() ?? 0) + 1
        return chartYScale(domain: low...high)
            .chartYAxis {
                AxisMarks(values: .stride(by: max(1, ((high - low) / 4).rounded()))) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let grade = value.as(Double.self) { Text(Grade.label(Int(grade))) }
                    }
                }
            }
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A single-series bar chart of one value per week, with tap-to-inspect.
struct WeeklyBarChart: View {
    let title: String
    let stats: TrainingStats
    let values: [WeekValue]
    let color: Color
    let format: (Double) -> String
    @State private var selection: Date?

    var body: some View {
        let selected = selection.flatMap { date in values.first { $0.week == stats.week(of: date) } }

        VStack(alignment: .leading, spacing: 10) {
            ChartHeader(
                title: title,
                detail: selected.map { "Semana de \($0.week.formatted(.dateTime.day().month())): \(format($0.value))" }
                    ?? "Toque numa barra para ver detalhes"
            )
            Chart {
                ForEach(values) { item in
                    BarMark(x: .value("Semana", item.week, unit: .weekOfYear), y: .value(title, item.value), width: stats.barWidth)
                        .foregroundStyle(color.opacity(selected == nil || selected?.week == item.week ? 1 : 0.35))
                        .cornerRadius(4)
                }
            }
            .chartXSelection(value: $selection)
            .weekAxis(stats)
            .frame(height: 160)
        }
        .padding(.vertical, 6)
    }
}
