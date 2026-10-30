import Foundation

struct DayValue: Identifiable {
    let day: Date
    let value: Double
    var id: Date { day }
}

struct WeekKindLoad: Identifiable {
    let week: Date
    let kind: SessionKind
    let load: Double
    var id: String { "\(week.timeIntervalSinceReferenceDate)-\(kind.rawValue)" }
}

struct CalendarCell: Identifiable {
    let day: Date
    let week: Date
    /// 1 = first day of the week in the user's calendar.
    let weekdayIndex: Int
    let load: Double
    /// 0 = rest, 1...4 = increasing load.
    let level: Int
    var id: Date { day }
}

/// Acute:chronic workload ratio zones, from sports-science guidance on injury risk.
enum LoadZone {
    case low, sweetSpot, caution, danger

    init(ratio: Double) {
        switch ratio {
        case ..<0.8: self = .low
        case ..<1.3: self = .sweetSpot
        case ..<1.5: self = .caution
        default: self = .danger
        }
    }

    var title: String {
        switch self {
        case .low: "Destreino"
        case .sweetSpot: "Zona ideal"
        case .caution: "Subindo rápido"
        case .danger: "Risco alto de lesão"
        }
    }

    var advice: String {
        switch self {
        case .low: "Você está treinando menos que a sua média recente. Tudo bem numa semana de descarga, mas o condicionamento cai se durar muito."
        case .sweetSpot: "Sua carga está de acordo com o que seu corpo está acostumado. Continue aumentando aos poucos."
        case .caution: "A carga está subindo mais rápido que o normal. Cuide dos dedos e do sono."
        case .danger: "Esta semana está bem acima da sua média de 4 semanas. Picos assim estão ligados a lesões de dedos e ombros."
        }
    }

    var systemImage: String {
        switch self {
        case .low: "arrow.down.circle"
        case .sweetSpot: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .danger: "xmark.octagon.fill"
        }
    }
}

/// Training load (session RPE × minutes) and how it changes, for spotting overtraining.
struct LoadAnalytics {
    private let stats: TrainingStats
    private let dailyLoad: [Date: Double]
    private let firstTrainingDay: Date?
    /// Every day in the range, up to today.
    let days: [Date]

    init(stats: TrainingStats, now: Date = .now) {
        self.stats = stats
        let calendar = stats.calendar
        dailyLoad = Dictionary(grouping: stats.allSessions) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + Self.load(of: $1) } }
        firstTrainingDay = stats.allSessions.map(\.date).min().map(calendar.startOfDay(for:))
        let start = stats.weeks.first ?? stats.currentWeek
        let today = calendar.startOfDay(for: now)
        var days: [Date] = []
        var day = start
        while day <= today {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(86_400)
        }
        self.days = days
    }

    /// Session RPE load (Foster): effort (1–10) × minutes. Zero when either is missing.
    static func load(of session: TrainingSession) -> Double {
        Double((session.durationMinutes ?? 0) * session.effort)
    }

    var sessionsMissingLoad: Int { stats.sessions.filter { Self.load(of: $0) == 0 }.count }

    var totalLoad: Double { stats.sessions.reduce(0) { $0 + Self.load(of: $1) } }

    var weeklyLoad: [WeekKindLoad] {
        let grouped = Dictionary(grouping: stats.sessions) { stats.week(of: $0.date) }
        return stats.weeks.flatMap { week in
            SessionKind.allCases.map { kind in
                WeekKindLoad(week: week, kind: kind, load: (grouped[week] ?? []).filter { $0.kind == kind }.reduce(0) { $0 + Self.load(of: $1) })
            }
        }
    }

    var trainingDays: Int { days.filter { (dailyLoad[$0] ?? 0) > 0 || hasSession(on: $0) }.count }
    var restDays: Int { days.count - trainingDays }

    private func hasSession(on day: Date) -> Bool {
        stats.sessions.contains { stats.calendar.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: Acute:chronic workload ratio

    private func sum(endingOn day: Date, days count: Int) -> Double {
        (0..<count).reduce(0) { total, offset in
            guard let d = stats.calendar.date(byAdding: .day, value: -offset, to: day) else { return total }
            return total + (dailyLoad[d] ?? 0)
        }
    }

    /// Last 7 days of load divided by the weekly average of the last 28 days.
    /// Needs 4 weeks of history, otherwise the average is artificially low.
    func ratio(on day: Date) -> Double? {
        guard let first = firstTrainingDay, let ready = stats.calendar.date(byAdding: .day, value: 27, to: first), day >= ready else { return nil }
        let chronic = sum(endingOn: day, days: 28) / 4
        guard chronic > 0 else { return nil }
        return sum(endingOn: day, days: 7) / chronic
    }

    var ratioSeries: [DayValue] { days.compactMap { day in ratio(on: day).map { DayValue(day: day, value: $0) } } }

    var currentRatio: Double? { days.last.flatMap(ratio(on:)) }

    // MARK: Calendar

    var calendarCells: [CalendarCell] {
        let maxLoad = days.compactMap { dailyLoad[$0] }.max() ?? 0
        return days.map { day in
            let load = dailyLoad[day] ?? 0
            let trained = load > 0 || hasSession(on: day)
            let level = !trained ? 0 : maxLoad > 0 ? max(1, Int((load / maxLoad * 4).rounded(.up))) : 1
            let weekday = stats.calendar.component(.weekday, from: day)
            let index = (weekday - stats.calendar.firstWeekday + 7) % 7 + 1
            return CalendarCell(day: day, week: stats.week(of: day), weekdayIndex: index, load: load, level: level)
        }
    }
}
