//
//  HealthKitManager.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 25/08/2026.
//


import Foundation
import HealthKit

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private let bodyMassType = HKQuantityType(.bodyMass)
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)
    private let workoutType: HKWorkoutType = .workoutType()

    private var readTypes: Set<HKObjectType> {
        [bodyMassType]
    }

    private var writeTypes: Set<HKSampleType> {
        [workoutType, activeEnergyType]
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }

        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
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

    func saveWorkout(start: Date, end: Date, workingSets: Int, totalVolumeKg: Double) async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }

        try await requestWorkoutAuthorizationIfNeeded()

        guard hasWorkoutWriteAuthorization else {
            throw HealthKitError.notAuthorized
        }

        let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories(sets: workingSets))
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)

        let energySample = HKQuantitySample(
            type: activeEnergyType,
            quantity: energyBurned,
            start: start,
            end: end
        )
        try await builder.addSamples([energySample])
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }
    
    func checkWorkoutAuthorizationStatus() -> HKAuthorizationStatus {
        store.authorizationStatus(for: workoutType)
    }

    var hasWorkoutWriteAuthorization: Bool {
        store.authorizationStatus(for: workoutType) == .sharingAuthorized
        && store.authorizationStatus(for: activeEnergyType) == .sharingAuthorized
    }

    private func requestWorkoutAuthorizationIfNeeded() async throws {
        let needsAuthorization = store.authorizationStatus(for: workoutType) == .notDetermined
        || store.authorizationStatus(for: activeEnergyType) == .notDetermined

        if needsAuthorization {
            try await requestAuthorization()
        }
    }

    private func estimatedCalories(sets: Int) -> Double {
        Double(sets) * 6.0
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
}
