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
    
    enum WorkoutSaveError: LocalizedError {
        case persistenceFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let error):
                return "Couldn't save this workout: \(error.localizedDescription)"
            }
        }
    }
    
    let workout: Workout
    private let context: ModelContext

    @Published var isPairingMode = false
    @Published var selectedForPairing: Set<PersistentIdentifier> = []

    init(workout: Workout, context: ModelContext) {
        self.workout = workout
        self.context = context
        if workout.sessionStartTime == nil {
            workout.sessionStartTime = Date()
        }
    }

    // MARK: - Display grouping (standalone vs. superset pairs)

    var displayGroups: [[ExerciseEntry]] {
        var result: [[ExerciseEntry]] = []
        var seen: Set<PersistentIdentifier> = []

        var groupedByID: [UUID: [ExerciseEntry]] = [:]
        for entry in workout.exercises {
            if let groupID = entry.supersetGroupID {
                groupedByID[groupID, default: []].append(entry)
            }
        }

        for entry in workout.exercises {
            if seen.contains(entry.persistentModelID) { continue }

            if let groupID = entry.supersetGroupID, let group = groupedByID[groupID], group.count == 2 {
                result.append(group)
                group.forEach { seen.insert($0.persistentModelID) }
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

    var isTracked: Bool {
        workout.modelContext != nil
    }

    func discard() {
        if isTracked {
            context.delete(workout)
        }
    }

    @discardableResult
    func save() throws -> (start: Date, end: Date, sets: Int, volumeKg: Double)? {
        guard isReadyToSave else { return nil }
        let end = Date()
        workout.sessionEndTime = end
        context.insert(workout)

        do {
            try context.save()
        } catch {
            context.delete(workout)
            throw WorkoutSaveError.persistenceFailed(underlying: error)
        }

        let start = workout.sessionStartTime ?? workout.date
        return (start, end, workout.totalWorkingSets, workout.totalVolume)
    }
}
