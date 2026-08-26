//
//  BackupManagerTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//

import XCTest
import SwiftData

@testable import WorkoutTracker

final class BackupManagerTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()

        container = TestModelContainer.make()
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil

        super.tearDown()
    }

    // MARK: - Round trip

    func test_exportImportRoundTrip_preservesWorkoutData() throws {

        let deadlift = TestFixtures.makeExercise(
            context: context,
            name: "Deadlift",
            prMetric: .weight
        )

        let workout = TestFixtures.makeWorkout(
            context: context,
            date: Date(),
            name: "Leg Day"
        )

        TestFixtures.addExerciseEntry(
            context: context,
            workout: workout,
            exercise: deadlift,
            sets: [
                (.warmup, 60, 5, nil, nil),
                (.working, 140, 3, 8.5, nil)
            ]
        )

        try context.save()

        let backup = try BackupManager.buildBackup(
            context: context
        )

        let data = try BackupManager.encode(backup)

        let decoded = try BackupManager.decode(data)

        XCTAssertEqual(decoded.workouts.count, 1)
        XCTAssertEqual(
            decoded.workouts.first?.name,
            "Leg Day"
        )

        XCTAssertEqual(
            decoded.workouts.first?.exercises.first?.exerciseName,
            "Deadlift"
        )

        XCTAssertEqual(
            decoded.workouts.first?.exercises.first?.sets.count,
            2
        )

        let workingSet =
            decoded.workouts.first?
                .exercises.first?
                .sets
                .first { $0.setType == "working" }

        XCTAssertEqual(workingSet?.weight, 140)
        XCTAssertEqual(workingSet?.reps, 3)
        XCTAssertEqual(workingSet?.rpe, 8.5)
    }

    // MARK: - P0: PR metric

    func test_exportImportRoundTrip_preservesPRMetric() throws {

        let exercise = TestFixtures.makeExercise(
            context: context,
            name: "Pull Up",
            prMetric: .assisted
        )

        exercise.notes = "Track assistance reduction."

        try context.save()

        let backup = try BackupManager.buildBackup(
            context: context
        )

        XCTAssertEqual(
            backup.exercises.first?.prMetric,
            .assisted
        )

        XCTAssertEqual(
            backup.exercises.first?.notes,
            "Track assistance reduction."
        )

        let data = try BackupManager.encode(backup)

        let decoded = try BackupManager.decode(data)

        let importedContainer = TestModelContainer.make()
        let importedContext = ModelContext(importedContainer)

        try BackupManager.importBackup(
            decoded,
            context: importedContext,
            mode: .replace
        )

        let importedExercises =
            try importedContext.fetch(
                FetchDescriptor<Exercise>()
            )

        let importedExercise =
            try XCTUnwrap(
                importedExercises.first {
                    $0.name == "Pull Up"
                }
            )

        XCTAssertEqual(
            importedExercise.prMetric,
            .assisted
        )

        XCTAssertEqual(
            importedExercise.notes,
            "Track assistance reduction."
        )
    }

    // MARK: - P0: Supersets

    func test_exportImportRoundTrip_preservesSupersetGroupID() throws {

        let bench = TestFixtures.makeExercise(
            context: context,
            name: "Bench Press",
            prMetric: .weight
        )

        let row = TestFixtures.makeExercise(
            context: context,
            name: "Barbell Row",
            prMetric: .weight
        )

        let workout = TestFixtures.makeWorkout(
            context: context,
            date: Date(),
            name: "Upper Body"
        )

        let supersetID = UUID()

        let benchEntry = ExerciseEntry(
            exercise: bench
        )

        benchEntry.workout = workout
        benchEntry.supersetGroupID = supersetID

        let rowEntry = ExerciseEntry(
            exercise: row
        )

        rowEntry.workout = workout
        rowEntry.supersetGroupID = supersetID

        context.insert(benchEntry)
        context.insert(rowEntry)

        workout.exercises.append(benchEntry)
        workout.exercises.append(rowEntry)

        try context.save()

        let backup = try BackupManager.buildBackup(
            context: context
        )

        XCTAssertEqual(
            backup.workouts.first?.exercises.count,
            2
        )

        XCTAssertEqual(
            backup.workouts.first?.exercises[0].supersetGroupID,
            supersetID
        )

        XCTAssertEqual(
            backup.workouts.first?.exercises[1].supersetGroupID,
            supersetID
        )

        let data = try BackupManager.encode(backup)

        let decoded = try BackupManager.decode(data)

        let importedContainer = TestModelContainer.make()
        let importedContext = ModelContext(importedContainer)

        try BackupManager.importBackup(
            decoded,
            context: importedContext,
            mode: .replace
        )

        let importedWorkouts =
            try importedContext.fetch(
                FetchDescriptor<Workout>()
            )

        let importedWorkout =
            try XCTUnwrap(importedWorkouts.first)

        XCTAssertEqual(
            importedWorkout.exercises.count,
            2
        )

        let importedSupersetIDs =
            importedWorkout.exercises.compactMap {
                $0.supersetGroupID
            }

        XCTAssertEqual(
            importedSupersetIDs.count,
            2
        )

        XCTAssertEqual(
            importedSupersetIDs[0],
            importedSupersetIDs[1]
        )

        XCTAssertEqual(
            importedSupersetIDs[0],
            supersetID
        )
    }

    // MARK: - P0: Unknown exercise

    func test_importBackup_recoversEntryWhenExerciseMissingFromCatalog() throws {

        let backupSet = BackupSet(
            setType: "working",
            setNumber: 1,
            weight: 50,
            reps: 5,
            rpe: nil,
            rir: nil
        )

        let backupEntry = BackupExerciseEntry(
            exerciseName: "Exercise Missing From Catalog",
            sets: [backupSet],
            supersetGroupID: nil
        )

        let backupWorkout = BackupWorkout(
            date: Date(),
            name: "Recovered Session",
            notes: nil,
            sessionStartTime: nil,
            sessionEndTime: nil,
            exercises: [backupEntry]
        )

        let backup = BackupData(
            version: BackupManager.currentVersion,
            exportedAt: .now,
            exercises: [],
            workouts: [backupWorkout]
        )

        try BackupManager.importBackup(
            backup,
            context: context,
            mode: .replace
        )

        let workouts =
            try context.fetch(
                FetchDescriptor<Workout>()
            )

        XCTAssertEqual(workouts.count, 1)

        let workout =
            try XCTUnwrap(workouts.first)

        // The entry must NOT disappear.
        XCTAssertEqual(
            workout.exercises.count,
            1
        )

        let entry =
            try XCTUnwrap(
                workout.exercises.first
            )

        XCTAssertEqual(
            entry.exercise?.name,
            "Exercise Missing From Catalog"
        )

        XCTAssertEqual(
            entry.sets.count,
            1
        )

        XCTAssertEqual(
            entry.sets.first?.weight,
            50
        )

        XCTAssertEqual(
            entry.sets.first?.reps,
            5
        )
    }

    // MARK: - Future versions

    func test_decode_rejectsFutureVersionBackup() throws {

        let futureBackup = BackupData(
            version: 999,
            exportedAt: .now,
            exercises: [],
            workouts: []
        )

        let data = try BackupManager.encode(
            futureBackup
        )

        XCTAssertThrowsError(
            try BackupManager.decode(data)
        ) { error in

            XCTAssertTrue(
                error is BackupError
            )
        }
    }

    // MARK: - Replace

    func test_importReplace_wipesExistingDataBeforeRestoring() throws {

        let bench = TestFixtures.makeExercise(
            context: context,
            name: "Bench Press",
            prMetric: .weight
        )

        let oldWorkout = TestFixtures.makeWorkout(
            context: context,
            date: Date(),
            name: "Old Session"
        )

        TestFixtures.addExerciseEntry(
            context: context,
            workout: oldWorkout,
            exercise: bench,
            sets: [
                (.working, 80, 5, nil, nil)
            ]
        )

        try context.save()

        let backupExercise = BackupExercise(
            name: "Squat",
            category: "Big 3",
            isMainLift: true,
            prMetric: .weight,
            notes: nil
        )

        let backupSet = BackupSet(
            setType: "working",
            setNumber: 1,
            weight: 100,
            reps: 5,
            rpe: nil,
            rir: nil
        )

        let backupEntry = BackupExerciseEntry(
            exerciseName: "Squat",
            sets: [backupSet],
            supersetGroupID: nil
        )

        let backupWorkout = BackupWorkout(
            date: Date(),
            name: "Restored Session",
            notes: nil,
            sessionStartTime: nil,
            sessionEndTime: nil,
            exercises: [backupEntry]
        )

        let backup = BackupData(
            version: BackupManager.currentVersion,
            exportedAt: .now,
            exercises: [backupExercise],
            workouts: [backupWorkout]
        )

        try BackupManager.importBackup(
            backup,
            context: context,
            mode: .replace
        )

        let allWorkouts =
            try context.fetch(
                FetchDescriptor<Workout>()
            )

        XCTAssertEqual(
            allWorkouts.count,
            1
        )

        XCTAssertEqual(
            allWorkouts.first?.name,
            "Restored Session"
        )

        let allExercises =
            try context.fetch(
                FetchDescriptor<Exercise>()
            )

        XCTAssertEqual(
            allExercises.map { $0.name },
            ["Squat"]
        )
    }

    // MARK: - Merge

    func test_importMerge_addsToExistingWithoutDuplicatingExerciseCatalog() throws {

        let bench = TestFixtures.makeExercise(
            context: context,
            name: "Bench Press",
            prMetric: .weight
        )

        let existingWorkout = TestFixtures.makeWorkout(
            context: context,
            date: Date(),
            name: "Existing Session"
        )

        TestFixtures.addExerciseEntry(
            context: context,
            workout: existingWorkout,
            exercise: bench,
            sets: [
                (.working, 80, 5, nil, nil)
            ]
        )

        try context.save()

        let backupExercise = BackupExercise(
            name: "Bench Press",
            category: "Big 3",
            isMainLift: true,
            prMetric: .weight,
            notes: nil
        )

        let backupSet = BackupSet(
            setType: "working",
            setNumber: 1,
            weight: 85,
            reps: 5,
            rpe: nil,
            rir: nil
        )

        let backupEntry = BackupExerciseEntry(
            exerciseName: "Bench Press",
            sets: [backupSet],
            supersetGroupID: nil
        )

        let backupWorkout = BackupWorkout(
            date: Date(),
            name: "Imported Session",
            notes: nil,
            sessionStartTime: nil,
            sessionEndTime: nil,
            exercises: [backupEntry]
        )

        let backup = BackupData(
            version: BackupManager.currentVersion,
            exportedAt: .now,
            exercises: [backupExercise],
            workouts: [backupWorkout]
        )

        try BackupManager.importBackup(
            backup,
            context: context,
            mode: .merge
        )

        let allWorkouts =
            try context.fetch(
                FetchDescriptor<Workout>()
            )

        XCTAssertEqual(
            allWorkouts.count,
            2
        )

        let allExercises =
            try context.fetch(
                FetchDescriptor<Exercise>()
            )

        XCTAssertEqual(
            allExercises.filter {
                $0.name == "Bench Press"
            }.count,
            1
        )
    }
}
