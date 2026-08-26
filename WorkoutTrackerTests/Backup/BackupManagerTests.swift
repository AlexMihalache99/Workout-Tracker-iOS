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

    func test_exportImportRoundTrip_preservesWorkoutData() throws {
        let deadlift = TestFixtures.makeExercise(context: context, name: "Deadlift", prMetric: .weight)
        let workout = TestFixtures.makeWorkout(context: context, date: Date(), name: "Leg Day")
        TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: deadlift,
            sets: [(.warmup, 60, 5, nil, nil), (.working, 140, 3, 8.5, nil)])
        try context.save()

        let backup = try BackupManager.buildBackup(context: context)
        let data = try BackupManager.encode(backup)
        let decoded = try BackupManager.decode(data)

        XCTAssertEqual(decoded.workouts.count, 1)
        XCTAssertEqual(decoded.workouts.first?.name, "Leg Day")
        XCTAssertEqual(decoded.workouts.first?.exercises.first?.exerciseName, "Deadlift")
        XCTAssertEqual(decoded.workouts.first?.exercises.first?.sets.count, 2)

        let workingSet = decoded.workouts.first?.exercises.first?.sets.first { $0.setType == "working" }
        XCTAssertEqual(workingSet?.weight, 140)
        XCTAssertEqual(workingSet?.reps, 3)
        XCTAssertEqual(workingSet?.rpe, 8.5)
    }

    func test_decode_rejectsFutureVersionBackup() throws {
        let futureBackup = BackupData(version: 999, exportedAt: .now, exercises: [], workouts: [])
        let data = try BackupManager.encode(futureBackup)

        XCTAssertThrowsError(try BackupManager.decode(data)) { error in
            XCTAssertTrue(error is BackupError)
        }
    }

    func test_importReplace_wipesExistingDataBeforeRestoring() throws {
        let bench = TestFixtures.makeExercise(context: context, name: "Bench Press", prMetric: .weight)
        let oldWorkout = TestFixtures.makeWorkout(context: context, date: Date(), name: "Old Session")
        TestFixtures.addExerciseEntry(context: context, workout: oldWorkout, exercise: bench, sets: [(.working, 80, 5, nil, nil)])
        try context.save()

        let backupExercise = BackupExercise(name: "Squat", category: "Big 3", isMainLift: true)
        let backupSet = BackupSet(setType: "working", setNumber: 1, weight: 100, reps: 5, rpe: nil, rir: nil)
        let backupEntry = BackupExerciseEntry(exerciseName: "Squat", sets: [backupSet])
        let backupWorkout = BackupWorkout(date: Date(), name: "Restored Session", notes: nil, exercises: [backupEntry])
        let backup = BackupData(version: BackupManager.currentVersion, exportedAt: .now, exercises: [backupExercise], workouts: [backupWorkout])

        try BackupManager.importBackup(backup, context: context, mode: .replace)

        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(allWorkouts.count, 1)
        XCTAssertEqual(allWorkouts.first?.name, "Restored Session")

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(allExercises.map { $0.name }, ["Squat"])
    }

    func test_importMerge_addsToExistingWithoutDuplicatingExerciseCatalog() throws {
        let bench = TestFixtures.makeExercise(context: context, name: "Bench Press", prMetric: .weight)
        let existingWorkout = TestFixtures.makeWorkout(context: context, date: Date(), name: "Existing Session")
        TestFixtures.addExerciseEntry(context: context, workout: existingWorkout, exercise: bench, sets: [(.working, 80, 5, nil, nil)])
        try context.save()

        let backupExercise = BackupExercise(name: "Bench Press", category: "Big 3", isMainLift: true)
        let backupSet = BackupSet(setType: "working", setNumber: 1, weight: 85, reps: 5, rpe: nil, rir: nil)
        let backupEntry = BackupExerciseEntry(exerciseName: "Bench Press", sets: [backupSet])
        let backupWorkout = BackupWorkout(date: Date(), name: "Imported Session", notes: nil, exercises: [backupEntry])
        let backup = BackupData(version: BackupManager.currentVersion, exportedAt: .now, exercises: [backupExercise], workouts: [backupWorkout])

        try BackupManager.importBackup(backup, context: context, mode: .merge)

        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(allWorkouts.count, 2)

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(allExercises.filter { $0.name == "Bench Press" }.count, 1)
    }

    func test_importBackup_skipsEntryWhenExerciseMissingFromCatalogAndBackup() throws {
        let backupSet = BackupSet(setType: "working", setNumber: 1, weight: 50, reps: 5, rpe: nil, rir: nil)
        let backupEntry = BackupExerciseEntry(exerciseName: "Nonexistent Exercise", sets: [backupSet])
        let backupWorkout = BackupWorkout(date: Date(), name: "Edge Case Session", notes: nil, exercises: [backupEntry])
        let backup = BackupData(version: BackupManager.currentVersion, exportedAt: .now, exercises: [], workouts: [backupWorkout])

        XCTAssertNoThrow(try BackupManager.importBackup(backup, context: context, mode: .replace))

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.first?.exercises.count, 0)
    }
}