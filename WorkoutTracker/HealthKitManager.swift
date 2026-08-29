//
//  HealthKitManager.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 25/08/2026.
//


import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    private let lastSyncErrorKey = "lastHealthSyncError"

    @Published var lastSyncErrorMessage: String?

    private init() {
        lastSyncErrorMessage = UserDefaults.standard.string(forKey: lastSyncErrorKey)
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private let bodyMassType = HKQuantityType(.bodyMass)
    private let workoutType = HKObjectType.workoutType()
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        let readTypes: Set<HKObjectType> = [bodyMassType]
        let writeTypes: Set<HKSampleType> = [workoutType, activeEnergyType]
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    func checkWorkoutAuthorizationStatus() -> HKAuthorizationStatus {
        store.authorizationStatus(for: workoutType)
    }

    func fetchLatestBodyweightKg() async -> Double? {
        guard isAvailable else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: bodyMassType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    func saveWorkout(start: Date, end: Date, workingSets: Int, totalVolumeKg: Double, bodyweightKg: Double? = nil) async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard hasWorkoutWriteAuthorization else { throw HealthKitError.notAuthorized }
        let status = store.authorizationStatus(for: workoutType)
        guard status == .sharingAuthorized else { throw HealthKitError.notAuthorized }

        let safeEnd = end > start ? end : start.addingTimeInterval(60)
        let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories(start: start, end: safeEnd, bodyweightKg: bodyweightKg))

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)

        let energySample = HKQuantitySample(type: activeEnergyType, quantity: energyBurned, start: start, end: safeEnd)
        try await builder.addSamples([energySample])
        try await builder.endCollection(at: safeEnd)
        _ = try await builder.finishWorkout()
    }

    /// Standard MET-based estimate: METs x bodyweight(kg) x duration(hours).
    /// 6.0 METs is a reasonable value for moderate-to-vigorous resistance
    /// training. Falls back to an average adult bodyweight when the user
    /// hasn't set one in Settings, since a rough estimate is still better
    /// than none, but a real bodyweight always takes priority when available.
    private func estimatedCalories(start: Date, end: Date, bodyweightKg: Double?) -> Double {
        let durationHours = max(end.timeIntervalSince(start), 60) / 3600
        let weight = (bodyweightKg ?? 0) > 0 ? bodyweightKg! : 75
        let metValue = 6.0
        return metValue * weight * durationHours
    }
    
    /// True only when BOTH permissions this app writes are granted:
    /// the workout itself, and the active-energy sample attached to it.
    /// HealthKit authorizes each HKSampleType independently, so a workout
    /// can be "authorized" while the energy sample write still silently
    /// fails if that second type was never granted -- this property exists
    /// specifically to catch that partial-authorization state before
    /// attempting a write, rather than after.
    var hasWorkoutWriteAuthorization: Bool {
        store.authorizationStatus(for: workoutType) == .sharingAuthorized
            && store.authorizationStatus(for: activeEnergyType) == .sharingAuthorized
    }

    func recordSyncError(_ message: String) {
        lastSyncErrorMessage = message
        UserDefaults.standard.set(message, forKey: lastSyncErrorKey)
    }

    func clearSyncError() {
        lastSyncErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: lastSyncErrorKey)
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Health data isn't available on this device."
        case .notAuthorized: return "Workout write access to Health isn't authorized. Check Settings → Privacy & Security → Health → WorkoutTracker."
        }
    }
}
