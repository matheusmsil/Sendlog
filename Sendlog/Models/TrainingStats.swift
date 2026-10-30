import Foundation

struct WeekValue: Identifiable {
    let week: Date
    let value: Double
    var id: Date { week }
}

struct WeekKindCount: Identifiable {
    let week: Date
    let kind: SessionKind
    let count: Int
    var id: String { "\(week.timeIntervalSinceReferenceDate)-\(kind.rawValue)" }
}

struct ExercisePoint: Identifiable {
    let date: Date
    let topWeight: Double
    let estimatedOneRepMax: Double
    let volume: Double
    var id: Date { date }
}

struct StrengthToWeightPoint: Identifiable {
    let date: Date
    let series: String
    let percent: Double
    let added: Double
    var id: String { "\(date.timeIntervalSinceReferenceDate)-\(series)" }
}

/// Aggregates logged sessions over the last `weekCount` weeks (including the current one).
struct TrainingStats {
    let weeks: [Date]
    let sessions: [TrainingSession]
    let allSessions: [TrainingSession]
    let calendar: Calendar
    let currentWeek: Date

    init(sessions all: [TrainingSession], weekCount: Int, now: Date = .now, calendar: Calendar = .current) {
        self.calendar = calendar
        allSessions = all
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        self.currentWeek = currentWeek
        weeks = (0..<weekCount).reversed().compactMap {
            calendar.date(byAdding: .weekOfYear, value: -$0, to: currentWeek)
        }
        let start = weeks.first ?? currentWeek
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek) ?? now
        sessions = all.filter { $0.date >= start && $0.date < end }
    }

    func week(of date: Date) -> Date { calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date }

    var xDomain: ClosedRange<Date> {
        (weeks.first ?? currentWeek)...(calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek) ?? currentWeek)
    }

    private func perWeek(_ value: ([TrainingSession]) -> Double) -> [WeekValue] {
        let grouped = Dictionary(grouping: sessions) { week(of: $0.date) }
        return weeks.map { WeekValue(week: $0, value: value(grouped[$0] ?? [])) }
    }

    // MARK: Overview

    var sessionsPerWeek: [WeekKindCount] {
        let grouped = Dictionary(grouping: sessions) { week(of: $0.date) }
        return weeks.flatMap { week in
            SessionKind.allCases.map { kind in
                WeekKindCount(week: week, kind: kind, count: grouped[week]?.filter { $0.kind == kind }.count ?? 0)
            }
        }
    }

    var totalMinutes: Int { sessions.compactMap(\.durationMinutes).reduce(0, +) }

    var averageEffort: Double? {
        let rated = sessions.map(\.effort).filter { $0 > 0 }
        return rated.isEmpty ? nil : Double(rated.reduce(0, +)) / Double(rated.count)
    }

    /// Consecutive weeks with at least one session. The current week doesn't break the streak until it's over.
    var weekStreak: Int {
        let trainedWeeks = Set(allSessions.map { week(of: $0.date) })
        var week = trainedWeeks.contains(currentWeek)
            ? currentWeek
            : calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek) ?? currentWeek
        var streak = 0
        while trainedWeeks.contains(week) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = previous
        }
        return streak
    }

    // MARK: Climbing

    var climbingSessions: [TrainingSession] { sessions.filter { $0.kind == .climbing } }

    var totalAscents: Int { climbingSessions.flatMap(\.climbingBlocks).reduce(0) { $0 + $1.completedAscents } }

    var ascentsPerWeek: [WeekValue] {
        perWeek { Double($0.flatMap(\.climbingBlocks).reduce(0) { $0 + $1.completedAscents }) }
    }

    var hardestSend: Int? { Self.hardestSend(in: sessions) }

    /// Only weeks where a graded boulder was sent.
    var hardestSendPerWeek: [WeekValue] {
        perWeek { Self.hardestSend(in: $0).map(Double.init) ?? .nan }.filter { !$0.value.isNaN }
    }

    private static func hardestSend(in sessions: [TrainingSession]) -> Int? {
        sessions.flatMap(\.climbingBlocks).flatMap(\.boulders)
            .filter { $0.completedReps > 0 }
            .compactMap { Grade.vScale($0.grade) }
            .max()
    }

    // MARK: Strength

    /// Exercise names in this range, most frequently logged first.
    var exerciseNames: [String] {
        let names = sessions.flatMap(\.exercises).map(\.name).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return Dictionary(grouping: names, by: Self.normalized)
            .sorted { $0.value.count > $1.value.count || ($0.value.count == $1.value.count && $0.key < $1.key) }
            .compactMap(\.value.first)
    }

    func progress(for exercise: String) -> [ExercisePoint] {
        sessions.sorted { $0.date < $1.date }.compactMap { session in
            let sets = matchingSets(exercise, in: session)
            guard let top = sets.map(\.weight).max() else { return nil }
            return ExercisePoint(
                date: session.date,
                topWeight: top,
                estimatedOneRepMax: sets.map(Self.estimatedOneRepMax).max() ?? top,
                volume: sets.reduce(0) { $0 + Double($1.reps) * $1.weight }
            )
        }
    }

    /// The heaviest set ever logged for an exercise, across all history.
    func personalBest(for exercise: String) -> ExerciseSet? {
        allSessions.flatMap { matchingSets(exercise, in: $0) }
            .max { ($0.weight, $0.reps) < ($1.weight, $1.reps) }
    }

    func bestEstimatedOneRepMax(for exercise: String) -> Double? {
        allSessions.flatMap { matchingSets(exercise, in: $0) }.map(Self.estimatedOneRepMax).max()
    }

    private func matchingSets(_ exercise: String, in session: TrainingSession) -> [ExerciseSet] {
        let key = Self.normalized(exercise)
        return session.exercises
            .filter { Self.normalized($0.name) == key }
            .flatMap(\.sets)
            .filter { $0.reps > 0 }
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Epley formula.
    private static func estimatedOneRepMax(_ set: ExerciseSet) -> Double {
        set.reps == 1 ? set.weight : set.weight * (1 + Double(set.reps) / 30)
    }

    // MARK: Strength-to-weight

    /// Series name and the texts an exercise name can contain to belong to it.
    static let strengthToWeightSeries = [
        ("Hangboard", ["hang"]),
        ("Barra fixa com carga", ["barra fixa", "pull-up", "pull up", "pullup"]),
    ]

    /// Per session, (bodyweight + heaviest added weight) as a percentage of bodyweight.
    func strengthToWeight(bodyWeight: Double) -> [StrengthToWeightPoint] {
        guard bodyWeight > 0 else { return [] }
        return sessions.sorted { $0.date < $1.date }.flatMap { session in
            Self.strengthToWeightSeries.compactMap { series, matches -> StrengthToWeightPoint? in
                let added = session.exercises
                    .filter { exercise in matches.contains { exercise.name.lowercased().contains($0) } }
                    .flatMap(\.sets)
                    .filter { $0.reps > 0 }
                    .map(\.weight)
                    .max()
                return added.map { StrengthToWeightPoint(date: session.date, series: series, percent: (bodyWeight + $0) / bodyWeight * 100, added: $0) }
            }
        }
    }

    // MARK: Activation & mobility

    func sessionCount(with kind: RoutineKind) -> Int { sessions.filter { $0.hasRoutine(kind) }.count }

    var prepSessionsPerWeek: [WeekValue] {
        perWeek { Double($0.filter { !$0.routineBlocks.isEmpty }.count) }
    }
}
