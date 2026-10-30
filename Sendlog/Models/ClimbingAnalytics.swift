import Foundation

/// One boulder tried in one session, flattened for analysis.
struct ClimbRecord {
    let date: Date
    let session: TrainingSession
    let name: String
    let grade: Int?
    let gradeText: String
    let sent: Bool
    let flash: Bool
    let attempts: Int
    let isProjecting: Bool
    let angle: WallAngle?
    let holds: Set<HoldType>
}

struct GradeCount: Identifiable {
    enum Kind: String { case flash = "Flash", worked = "Trabalhado" }
    let grade: Int
    let kind: Kind
    let count: Int
    var id: String { "\(grade)-\(kind.rawValue)" }
}

struct GradeTrendPoint: Identifiable {
    enum Series: String { case hardest = "Mais difícil", typical = "Típico" }
    let week: Date
    let series: Series
    let grade: Double
    var id: String { "\(week.timeIntervalSinceReferenceDate)-\(series.rawValue)" }
}

struct GradeAttempts: Identifiable {
    let grade: Int
    let averageAttempts: Double
    let sends: Int
    var id: Int { grade }
}

struct TagStat: Identifiable {
    let label: String
    let tried: Int
    let sent: Int
    let hardest: Int?
    var rate: Double { tried == 0 ? 0 : Double(sent) / Double(tried) }
    var id: String { label }
}

struct ProjectSummary: Identifiable {
    let name: String
    let gradeText: String
    let sessions: Int
    let attempts: Int
    let lastTried: Date
    let sentDate: Date?
    var id: String { name.lowercased() }
}

/// Performance analysis of the climbing logged in a `TrainingStats` range.
struct ClimbingAnalytics {
    let records: [ClimbRecord]
    let previousRecords: [ClimbRecord]
    private let stats: TrainingStats

    /// A climb needs this many sends at a grade for the grade to count as consolidated.
    static let consolidationSends = 3

    init(stats: TrainingStats) {
        self.stats = stats
        records = Self.records(in: stats.sessions)
        let start = stats.weeks.first ?? stats.currentWeek
        let previousStart = stats.calendar.date(byAdding: .weekOfYear, value: -stats.weeks.count, to: start) ?? start
        previousRecords = Self.records(in: stats.allSessions.filter { $0.date >= previousStart && $0.date < start })
    }

    static func records(in sessions: [TrainingSession]) -> [ClimbRecord] {
        sessions.flatMap { session in
            session.climbingBlocks.flatMap { block in
                block.boulders.compactMap { boulder -> ClimbRecord? in
                    // An untouched projecting boulder wasn't really tried.
                    if block.style == .projecting && boulder.attempts == 0 && !boulder.isSent { return nil }
                    return ClimbRecord(
                        date: session.date,
                        session: session,
                        name: boulder.name.trimmingCharacters(in: .whitespaces),
                        grade: Grade.vScale(boulder.grade),
                        gradeText: boulder.grade,
                        sent: boulder.isSent,
                        flash: boulder.isFlash,
                        attempts: boulder.attempts,
                        isProjecting: block.style == .projecting,
                        angle: boulder.angle,
                        holds: boulder.holdTypes
                    )
                }
            }
        }
    }

    var isEmpty: Bool { records.isEmpty }

    var sends: [ClimbRecord] { records.filter(\.sent) }

    // MARK: Headline grades

    var maxGrade: Int? { Self.maxGrade(records) }
    var previousMaxGrade: Int? { Self.maxGrade(previousRecords) }

    var flashGrade: Int? { sends.filter(\.flash).compactMap(\.grade).max() }

    /// The hardest grade you've sent at least `consolidationSends` times.
    var consolidatedGrade: Int? {
        Dictionary(grouping: sends.compactMap(\.grade), by: { $0 })
            .filter { $0.value.count >= Self.consolidationSends }
            .keys.max()
    }

    var sendRate: Double? { records.isEmpty ? nil : Double(sends.count) / Double(records.count) }

    private static func maxGrade(_ records: [ClimbRecord]) -> Int? {
        records.filter(\.sent).compactMap(\.grade).max()
    }

    // MARK: Pyramid & progression

    /// Sends per grade, split into flashes and worked sends, hardest grade first.
    var pyramid: [GradeCount] {
        let graded = sends.filter { $0.grade != nil }
        let grades = Set(graded.compactMap(\.grade)).sorted(by: >)
        return grades.flatMap { grade in
            let atGrade = graded.filter { $0.grade == grade }
            return [
                GradeCount(grade: grade, kind: .flash, count: atGrade.filter(\.flash).count),
                GradeCount(grade: grade, kind: .worked, count: atGrade.filter { !$0.flash }.count),
            ]
        }
    }

    /// Per week: the hardest send and the median send grade.
    var gradeTrend: [GradeTrendPoint] {
        let byWeek = Dictionary(grouping: sends.filter { $0.grade != nil }) { stats.week(of: $0.date) }
        return stats.weeks.flatMap { week -> [GradeTrendPoint] in
            let grades = (byWeek[week] ?? []).compactMap(\.grade).sorted()
            guard let hardest = grades.last else { return [] }
            let median = Double(grades[(grades.count - 1) / 2] + grades[grades.count / 2]) / 2
            return [
                GradeTrendPoint(week: week, series: .hardest, grade: Double(hardest)),
                GradeTrendPoint(week: week, series: .typical, grade: median),
            ]
        }
    }

    /// Average attempts per send, by grade. Only projecting blocks count attempts.
    var attemptsByGrade: [GradeAttempts] {
        let counted = sends.filter { $0.isProjecting && $0.attempts > 0 && $0.grade != nil }
        return Dictionary(grouping: counted) { $0.grade! }
            .map { GradeAttempts(grade: $0.key, averageAttempts: Double($0.value.reduce(0) { $0 + $1.attempts }) / Double($0.value.count), sends: $0.value.count) }
            .sorted { $0.grade < $1.grade }
    }

    // MARK: Style & weaknesses

    /// Climbs near your limit, so easy warm-ups don't flatter the send rates.
    /// Falls back to everything when there are too few graded climbs near the top.
    var climbsAtYourLevel: (records: [ClimbRecord], floor: Int?) {
        guard let max = maxGrade else { return (records, nil) }
        let floor = max - 2
        let nearLimit = records.filter { ($0.grade ?? .min) >= floor }
        return nearLimit.count >= 8 ? (nearLimit, floor) : (records, nil)
    }

    var byAngle: [TagStat] {
        let pool = climbsAtYourLevel.records
        return WallAngle.allCases.compactMap { angle in
            Self.tagStat(angle.title, pool.filter { $0.angle == angle })
        }
    }

    var byHold: [TagStat] {
        let pool = climbsAtYourLevel.records
        return HoldType.allCases.compactMap { hold in
            Self.tagStat(hold.plural, pool.filter { $0.holds.contains(hold) })
        }
    }

    var hasTags: Bool { records.contains { $0.angle != nil || !$0.holds.isEmpty } }

    /// The tag with the lowest send rate (at least 3 climbs), worth targeting in training.
    var focusArea: TagStat? {
        (byAngle + byHold).filter { $0.tried >= 3 }.min { $0.rate < $1.rate }
    }

    /// The tag with the highest send rate (at least 3 climbs).
    var strongestArea: TagStat? {
        (byAngle + byHold).filter { $0.tried >= 3 }.max { $0.rate < $1.rate }
    }

    private static func tagStat(_ label: String, _ records: [ClimbRecord]) -> TagStat? {
        guard !records.isEmpty else { return nil }
        return TagStat(label: label, tried: records.count, sent: records.filter(\.sent).count, hardest: maxGrade(records))
    }

    // MARK: Projects

    /// Named boulders from projecting blocks across all history, open projects first.
    var projects: [ProjectSummary] {
        let all = Self.records(in: stats.allSessions).filter { $0.isProjecting && !$0.name.isEmpty }
        let grouped = Dictionary(grouping: all) { $0.name.lowercased() }
        let summaries = grouped.values.map { tries -> ProjectSummary in
            let sorted = tries.sorted { $0.date < $1.date }
            return ProjectSummary(
                name: sorted.last!.name,
                gradeText: sorted.last { !$0.gradeText.isEmpty }?.gradeText ?? "",
                sessions: Set(sorted.map { ObjectIdentifier($0.session) }).count,
                attempts: sorted.reduce(0) { $0 + $1.attempts },
                lastTried: sorted.last!.date,
                sentDate: sorted.first(where: \.sent)?.date
            )
        }
        return summaries.sorted {
            switch ($0.sentDate, $1.sentDate) {
            case (nil, nil): $0.lastTried > $1.lastTried
            case (nil, _): true
            case (_, nil): false
            case let (a?, b?): a > b
            }
        }
    }
}
