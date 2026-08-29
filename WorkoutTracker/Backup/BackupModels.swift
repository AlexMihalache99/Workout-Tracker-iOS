//
//  BackupModels.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 21/08/2026.
//

import Foundation
import SwiftData

struct BackupExercise: Codable {
    var name: String
    var category: String
    var isMainLift: Bool
    var prMetric: PRMetric?
    var notes: String?
}

struct BackupSet: Codable {
    var setType: SetType
    var setNumber: Int
    var weight: Double
    var reps: Int
    var rpe: Double?
    var rir: Int?
}

struct BackupExerciseEntry: Codable {
    var exerciseName: String
    var sets: [BackupSet]
    var supersetGroupID: UUID?
}

struct BackupWorkout: Codable {
    var id: UUID?
    var date: Date
    var name: String?
    var notes: String?
    var sessionStartTime: Date?
    var sessionEndTime: Date?
    var exercises: [BackupExerciseEntry]
}

struct BackupData: Codable {
    var version: Int
    var exportedAt: Date
    var exercises: [BackupExercise]
    var workouts: [BackupWorkout]
}

enum BackupError: LocalizedError {
    case fileAccessDenied
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .fileAccessDenied:
            return "Couldn't access the selected file."

        case .unsupportedVersion(let v):
            return "This backup (version \(v)) isn't supported by this version of the app."
        }
    }
}

enum BackupManager {

    static let currentVersion = 2

    enum ImportMode {
        case merge
        case replace
    }

    // MARK: - Export

    static func buildBackup(context: ModelContext) throws -> BackupData {
        let exercises = try context.fetch(
            FetchDescriptor<Exercise>()
        )

        let workouts = try context.fetch(
            FetchDescriptor<Workout>(
                sortBy: [SortDescriptor(\.date)]
            )
        )

        let backupExercises = exercises.map { exercise in
            BackupExercise(
                name: exercise.name,
                category: exercise.category,
                isMainLift: exercise.isMainLift,
                prMetric: exercise.prMetric,
                notes: exercise.notes
            )
        }

        let backupWorkouts = workouts.map { workout in

            let entries = workout.exercises.map { entry in

                let sets = entry.sets.map { set in
                    BackupSet(
                        setType: set.setType,
                        setNumber: set.setNumber,
                        weight: set.weight,
                        reps: set.reps,
                        rpe: set.rpe,
                        rir: set.rir
                    )
                }

                return BackupExerciseEntry(
                    exerciseName: entry.exercise?.name ?? "Unknown",
                    sets: sets,
                    supersetGroupID: entry.supersetGroupID
                )
            }

            return BackupWorkout(
                    id: workout.id,
                    date: workout.date,
                    name: workout.name,
                    notes: workout.notes,
                    sessionStartTime: workout.sessionStartTime,
                    sessionEndTime: workout.sessionEndTime,
                    exercises: entries
                )
        }

        return BackupData(
            version: currentVersion,
            exportedAt: .now,
            exercises: backupExercises,
            workouts: backupWorkouts
        )
    }
    
    enum BackupMigrator {
        /// Upgrades a decoded backup to the current schema. Purely additive
        /// Optional fields (most of this app's history so far) don't actually
        /// need explicit migration, since Codable already defaults a missing
        /// key to nil -- this hook exists for the day a change ISN'T simply
        /// additive (a renamed field, a changed unit, a re-typed value) and
        /// needs real transformation before the rest of the app touches it.
        static func migrate(_ data: BackupData) -> BackupData {
            var migrated = data
            // No transformations needed yet: v1 -> v2 only added Optional
            // fields (prMetric, supersetGroupID, sessionStartTime/EndTime,
            // notes, workout id), which decode safely as nil on older files.
            // Add version-gated transformations here as future changes
            // require them, e.g.:
            //
            // if migrated.version < 3 {
            //     migrated.workouts = migrated.workouts.map { ... }
            // }
            migrated.version = BackupManager.currentVersion
            return migrated
        }
    }

    static func encode(_ backup: BackupData) throws -> Data {
        let encoder = JSONEncoder()

        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(backup)
    }

    // MARK: - Import

    static func decode(_ data: Data) throws -> BackupData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)
        guard backup.version <= currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }
        return BackupMigrator.migrate(backup)
    }

    static func importBackup(
        _ backup: BackupData,
        context: ModelContext,
        mode: ImportMode
    ) throws {

        do {
            // MARK: Replace
            if mode == .replace {
                let existingWorkouts = try context.fetch(FetchDescriptor<Workout>())
                for workout in existingWorkouts {
                    context.delete(workout)
                }
                let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
                for exercise in existingExercises {
                    context.delete(exercise)
                }
            }

            // MARK: Exercise catalog

            var exerciseByName: [String: Exercise] = [:]
            let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
            for exercise in existingExercises {
                exerciseByName[exercise.name] = exercise
            }

            for backupExercise in backup.exercises {
                if exerciseByName[backupExercise.name] != nil {
                    continue
                }
                let newExercise = Exercise(
                    name: backupExercise.name,
                    category: backupExercise.category,
                    isMainLift: backupExercise.isMainLift,
                    prMetric: backupExercise.prMetric,
                    notes: backupExercise.notes
                )
                context.insert(newExercise)
                exerciseByName[backupExercise.name] = newExercise
            }

            // MARK: Workouts

            let existingWorkoutIDs: Set<UUID> = mode == .merge
                ? Set(try context.fetch(FetchDescriptor<Workout>()).map { $0.id })
                : []

            for backupWorkout in backup.workouts {
                if mode == .merge, let backupID = backupWorkout.id, existingWorkoutIDs.contains(backupID) {
                    continue
                }

                let workout = Workout(
                    date: backupWorkout.date,
                    name: backupWorkout.name,
                    notes: backupWorkout.notes,
                    id: backupWorkout.id ?? UUID()
                )
                workout.sessionStartTime = backupWorkout.sessionStartTime
                workout.sessionEndTime = backupWorkout.sessionEndTime
                context.insert(workout)

                for backupEntry in backupWorkout.exercises {
                    let exercise: Exercise
                    if let existingExercise = exerciseByName[backupEntry.exerciseName] {
                        exercise = existingExercise
                    } else {
                        let recoveredExercise = Exercise(
                            name: backupEntry.exerciseName,
                            category: "Imported",
                            isMainLift: false
                        )
                        context.insert(recoveredExercise)
                        exerciseByName[backupEntry.exerciseName] = recoveredExercise
                        exercise = recoveredExercise
                    }

                    let entry = ExerciseEntry(exercise: exercise)
                    entry.workout = workout
                    entry.supersetGroupID = backupEntry.supersetGroupID
                    context.insert(entry)

                    for backupSet in backupEntry.sets {
                        let type: SetType = backupSet.setType
                        let set = SetEntry(
                            setType: type,
                            setNumber: backupSet.setNumber,
                            weight: backupSet.weight,
                            reps: backupSet.reps,
                            rpe: backupSet.rpe,
                            rir: backupSet.rir
                        )
                        set.exerciseEntry = entry
                        context.insert(set)
                        entry.sets.append(set)
                    }

                    workout.exercises.append(entry)
                }
            }

            try context.save()

        } catch {
            context.rollback()
            throw error
        }
    }
}
