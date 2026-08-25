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
}

struct BackupSet: Codable {
    var setType: String   // "warmup" or "working"
    var setNumber: Int
    var weight: Double
    var reps: Int
    var rpe: Double?
    var rir: Int?
}

struct BackupExerciseEntry: Codable {
    var exerciseName: String
    var sets: [BackupSet]
}

struct BackupWorkout: Codable {
    var date: Date
    var name: String?
    var notes: String?
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
    static let currentVersion = 1

    enum ImportMode {
        case merge
        case replace
    }

    // MARK: - Export

    static func buildBackup(context: ModelContext) throws -> BackupData {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let workouts = try context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)]))

        let backupExercises = exercises.map {
            BackupExercise(name: $0.name, category: $0.category, isMainLift: $0.isMainLift)
        }

        let backupWorkouts = workouts.map { workout -> BackupWorkout in
            let entries = workout.exercises.map { entry -> BackupExerciseEntry in
                let sets = entry.sets.map { set in
                    BackupSet(
                        setType: set.setType == .warmup ? "warmup" : "working",
                        setNumber: set.setNumber,
                        weight: set.weight,
                        reps: set.reps,
                        rpe: set.rpe,
                        rir: set.rir
                    )
                }
                return BackupExerciseEntry(exerciseName: entry.exercise?.name ?? "Unknown", sets: sets)
            }
            return BackupWorkout(date: workout.date, name: workout.name, notes: workout.notes, exercises: entries)
        }

        return BackupData(version: currentVersion, exportedAt: .now, exercises: backupExercises, workouts: backupWorkouts)
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
        return backup
    }

    static func importBackup(_ backup: BackupData, context: ModelContext, mode: ImportMode) throws {
        if mode == .replace {
            let existingWorkouts = try context.fetch(FetchDescriptor<Workout>())
            for workout in existingWorkouts { context.delete(workout) }
            let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
            for exercise in existingExercises { context.delete(exercise) }
            try context.save()
        }

        var exerciseByName: [String: Exercise] = [:]
        let existing = try context.fetch(FetchDescriptor<Exercise>())
        for exercise in existing { exerciseByName[exercise.name] = exercise }

        for backupExercise in backup.exercises where exerciseByName[backupExercise.name] == nil {
            let newExercise = Exercise(name: backupExercise.name, category: backupExercise.category, isMainLift: backupExercise.isMainLift)
            context.insert(newExercise)
            exerciseByName[backupExercise.name] = newExercise
        }

        for backupWorkout in backup.workouts {
            let workout = Workout(date: backupWorkout.date, name: backupWorkout.name, notes: backupWorkout.notes)
            context.insert(workout)

            for backupEntry in backupWorkout.exercises {
                guard let exercise = exerciseByName[backupEntry.exerciseName] else { continue }
                let entry = ExerciseEntry(exercise: exercise)
                entry.workout = workout
                context.insert(entry)

                for backupSet in backupEntry.sets {
                    let type: SetType = backupSet.setType == "warmup" ? .warmup : .working
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
    }
}
