//
//  WorkoutSession.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import Foundation
import SwiftData
import Combine

@MainActor
final class WorkoutSession: ObservableObject {
    let workout: Workout
    private let context: ModelContext

    @Published var isPairingMode = false
    @Published var selectedForPairing: Set<PersistentIdentifier> = []

    init(workout: Workout, context: ModelContext) {
        self.workout = workout
        self.context = context
    }

    // MARK: - Display grouping (standalone vs. superset pairs)

    var displayGroups: [[ExerciseEntry]] {
        var result: [[ExerciseEntry]] = []
        var seen: Set<PersistentIdentifier> = []

        for entry in workout.exercises {
            if seen.contains(entry.persistentModelID) { continue }
            if let groupID = entry.supersetGroupID {
                let partners = workout.exercises.filter { $0.supersetGroupID == groupID }
                result.append(partners)
                partners.forEach { seen.insert($0.persistentModelID) }
            } else {
                result.append([entry])
                seen.insert(entry.persistentModelID)
            }
        }
        return result
    }

    var canEnterPairingMode: Bool {
        workout.exercises.count >= 2
    }

    var isReadyToSave: Bool {
        !workout.exercises.isEmpty && !isPairingMode
    }

    // MARK: - Exercise management

    func addExercise(_ exercise: Exercise) {
        let entry = ExerciseEntry(exercise: exercise)
        entry.workout = workout
        workout.exercises.append(entry)
    }

    func deleteExerciseEntry(_ entry: ExerciseEntry) {
        if entry.modelContext != nil {
            context.delete(entry)
        }
        workout.exercises.removeAll { $0.persistentModelID == entry.persistentModelID }
    }

    // MARK: - Set management

    func addSet(_ set: SetEntry, to entry: ExerciseEntry) {
        set.exerciseEntry = entry
        entry.sets.append(set)
    }

    func addWarmupSets(_ sets: [SetEntry], to entry: ExerciseEntry) {
        for set in sets {
            addSet(set, to: entry)
        }
    }

    func deleteSets(from entry: ExerciseEntry, at offsets: IndexSet) {
        let sorted = entry.sortedSets
        for index in offsets {
            let setToDelete = sorted[index]
            if setToDelete.modelContext != nil {
                context.delete(setToDelete)
            }
            entry.sets.removeAll { $0.persistentModelID == setToDelete.persistentModelID }
        }
    }

    // MARK: - Superset pairing

    func togglePairingSelection(_ entry: ExerciseEntry) {
        if selectedForPairing.contains(entry.persistentModelID) {
            selectedForPairing.remove(entry.persistentModelID)
        } else if selectedForPairing.count < 2 {
            selectedForPairing.insert(entry.persistentModelID)
        }
    }

    func confirmPairing() {
        guard selectedForPairing.count == 2 else { return }
        let groupID = UUID()
        for entry in workout.exercises where selectedForPairing.contains(entry.persistentModelID) {
            entry.supersetGroupID = groupID
        }
        selectedForPairing.removeAll()
        isPairingMode = false
    }

    func cancelPairing() {
        isPairingMode = false
        selectedForPairing.removeAll()
    }

    func unlinkSuperset(_ group: [ExerciseEntry]) {
        for entry in group {
            entry.supersetGroupID = nil
        }
    }

    // MARK: - Rest timer decision

    /// Whether logging a working set on this entry should start the rest timer.
    /// Standalone exercises always rest. Superset partners only rest once the
    /// round is complete (partner has caught up to this entry's set count) --
    /// the pairing decision (rest = 0 between paired exercises) lives here,
    /// not in the timer itself.
    func shouldStartRestTimer(after entry: ExerciseEntry) -> Bool {
        guard let groupID = entry.supersetGroupID else { return true }
        let partners = workout.exercises.filter {
            $0.supersetGroupID == groupID && $0.persistentModelID != entry.persistentModelID
        }
        guard let partner = partners.first else { return true }

        let entryWorkingCount = entry.workingSets.count
        let partnerWorkingCount = partner.workingSets.count
        return partnerWorkingCount >= entryWorkingCount
    }

    // MARK: - Discard / Save

    /// True once this workout has actually been tracked by the context --
    /// e.g. by SwiftData's implicit relationship tracking when a persisted
    /// Exercise gets linked in. A workout that's never been touched this way
    /// needs no explicit delete on discard.
    var isTracked: Bool {
        workout.modelContext != nil
    }

    /// Discards the workout. Safe to call whether or not the workout has
    /// become implicitly tracked -- see the modelContext != nil guard note
    /// in isTracked.
    func discard() {
        if isTracked {
            context.delete(workout)
        }
    }

    /// Persists the workout for the first time. Returns the totals needed
    /// for a HealthKit sync so the caller (the View) can decide whether to
    /// fire that side effect -- WorkoutSession itself never talks to HealthKit.
    @discardableResult
    func save() -> (start: Date, sets: Int, volumeKg: Double)? {
        guard isReadyToSave else { return nil }
        context.insert(workout)
        try? context.save()
        return (workout.date, workout.totalWorkingSets, workout.totalVolume)
    }
}
