import Foundation
import HealthKit
import Observation
import SwiftData

/// A workout recorded in Apple Health (typically by Apple Watch), reduced to what Sendlog shows.
struct WatchWorkout: Identifiable {
    let id: UUID
    let activityType: HKWorkoutActivityType
    let start: Date
    let duration: TimeInterval
    let activeEnergyKcal: Double?
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let sourceName: String

    init(_ workout: HKWorkout) {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let heartRate = workout.statistics(for: HKQuantityType(.heartRate))

        id = workout.uuid
        activityType = workout.workoutActivityType
        start = workout.startDate
        duration = workout.duration
        activeEnergyKcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
        averageHeartRate = heartRate?.averageQuantity()?.doubleValue(for: bpm)
        maxHeartRate = heartRate?.maximumQuantity()?.doubleValue(for: bpm)
        sourceName = workout.sourceRevision.source.name
    }

    var suggestedKind: SessionKind {
        switch activityType {
        case .climbing: .climbing
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining: .strength
        default: .other
        }
    }

    var activityName: String {
        switch activityType {
        case .climbing: "Escalada"
        case .traditionalStrengthTraining: "Musculação tradicional"
        case .functionalStrengthTraining: "Treino funcional"
        case .coreTraining: "Treino de core"
        case .highIntensityIntervalTraining: "HIIT"
        case .crossTraining: "Cross training"
        case .running: "Corrida"
        case .walking: "Caminhada"
        case .hiking: "Trilha"
        case .cycling: "Ciclismo"
        case .swimming: "Natação"
        case .yoga: "Yoga"
        case .flexibility: "Flexibilidade"
        case .cooldown: "Desaquecimento"
        default: "Treino"
        }
    }
}

@Observable
@MainActor
final class HealthKitManager {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Asks for read access. The system only prompts for types it hasn't asked about before.
    /// If the user denies access, HealthKit queries return no data rather than an error.
    private func authorize() async throws {
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.bodyMass),
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func recentWorkouts(days: Int = 30) async throws -> [WatchWorkout] {
        try await authorize()

        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 200
        )
        return try await query.result(for: store).map(WatchWorkout.init)
    }

    /// The most recent bodyweight in Apple Health, in kilograms.
    func latestBodyMass() async throws -> Double? {
        try await authorize()
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try await query.result(for: store).first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }
}

extension TrainingSession {
    /// The Apple Watch data linked to this session, if any.
    func healthData(in context: ModelContext) -> WorkoutHealthData? {
        let id = uid
        var descriptor = FetchDescriptor<WorkoutHealthData>(predicate: #Predicate { $0.sessionID == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Takes the workout's date and duration, and keeps its Health stats in the local-only store.
    func apply(_ workout: WatchWorkout, in context: ModelContext) {
        date = workout.start
        durationMinutes = Int((workout.duration / 60).rounded())
        let health = healthData(in: context) ?? {
            let new = WorkoutHealthData(sessionID: uid)
            context.insert(new)
            return new
        }()
        health.healthWorkoutID = workout.id
        health.sourceName = workout.sourceName
        health.activeEnergyKcal = workout.activeEnergyKcal
        health.averageHeartRate = workout.averageHeartRate
        health.maxHeartRate = workout.maxHeartRate
    }

    func unlinkWatchWorkout(in context: ModelContext) {
        if let health = healthData(in: context) { context.delete(health) }
    }
}
