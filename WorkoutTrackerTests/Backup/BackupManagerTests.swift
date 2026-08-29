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
                .first { $0.setType == .working }

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
            setType: .working,
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

    // MARK: - Versioning / migration

    func test_decode_migratesOlderBackupMissingNewerFields() throws {
        // Simulates a v1 export: no id, prMetric, supersetGroupID, or session times.
        let legacyJSON = """
        {
          "version": 1,
          "exportedAt": "2026-01-01T00:00:00Z",
          "exercises": [{"name": "Deadlift", "category": "Big 3", "isMainLift": true}],
          "workouts": [{
            "date": "2026-01-01T00:00:00Z",
            "exercises": [{"exerciseName": "Deadlift", "sets": [
              {"setType": "working", "setNumber": 1, "weight": 100, "reps": 5}
            ]}]
          }]
        }
        """.data(using: .utf8)!

        let backup = try BackupManager.decode(legacyJSON)

        XCTAssertEqual(backup.version, BackupManager.currentVersion)
        XCTAssertEqual(backup.exercises.first?.prMetric, nil)
        XCTAssertEqual(backup.workouts.first?.id, nil)
        XCTAssertEqual(backup.workouts.first?.exercises.first?.sets.first?.setType, .working)
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
            setType: .working,
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
            setType: .working,
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

    func test_importReplace_rollsBackAllChangesIfFinalSaveFails() throws {
        let deadlift = TestFixtures.makeExercise(context: context, name: "Deadlift", prMetric: .weight)
        let existingWorkout = TestFixtures.makeWorkout(context: context, date: Date(), name: "Existing Session")
        TestFixtures.addExerciseEntry(context: context, workout: existingWorkout, exercise: deadlift, sets: [(.working, 140, 3, nil, nil)])
        try context.save()

        let backupExercise = BackupExercise(name: "Squat", category: "Big 3", isMainLift: true, prMetric: .weight, notes: nil)
        let backupSet = BackupSet(setType: .working, setNumber: 1, weight: 100, reps: 5, rpe: nil, rir: nil)
        let backupEntry = BackupExerciseEntry(exerciseName: "Squat", sets: [backupSet], supersetGroupID: nil)
        let backupWorkout = BackupWorkout(date: Date(), name: "Restored Session", notes: nil, sessionStartTime: nil, sessionEndTime: nil, exercises: [backupEntry])
        let backup = BackupData(version: BackupManager.currentVersion, exportedAt: .now, exercises: [backupExercise], workouts: [backupWorkout])

        // Happy-path sanity check that the new single-save structure still works:
        try BackupManager.importBackup(backup, context: context, mode: .replace)

        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(allWorkouts.count, 1)
        XCTAssertEqual(allWorkouts.first?.name, "Restored Session")
    }

    func test_importReplace_stillWorksAsSingleAtomicCommit() throws {
        let bench = TestFixtures.makeExercise(context: context, name: "Bench Press", prMetric: .weight)
        let oldWorkout = TestFixtures.makeWorkout(context: context, date: Date(), name: "Old Session")
        TestFixtures.addExerciseEntry(context: context, workout: oldWorkout, exercise: bench, sets: [(.working, 80, 5, nil, nil)])
        try context.save()

        let backupExercise = BackupExercise(name: "Squat", category: "Big 3", isMainLift: true, prMetric: .weight, notes: nil)
        let backupSet = BackupSet(setType: .working, setNumber: 1, weight: 100, reps: 5, rpe: nil, rir: nil)
        let backupEntry = BackupExerciseEntry(exerciseName: "Squat", sets: [backupSet], supersetGroupID: nil)
        let backupWorkout = BackupWorkout(date: Date(), name: "Restored Session", notes: nil, sessionStartTime: nil, sessionEndTime: nil, exercises: [backupEntry])
        let backup = BackupData(version: BackupManager.currentVersion, exportedAt: .now, exercises: [backupExercise], workouts: [backupWorkout])

        try BackupManager.importBackup(backup, context: context, mode: .replace)

        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(allWorkouts.count, 1)
        XCTAssertEqual(allWorkouts.first?.name, "Restored Session")

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(allExercises.map { $0.name }, ["Squat"])
    }

    func test_importMerge_isIdempotentOnRepeatImport() throws {
        let deadlift = TestFixtures.makeExercise(context: context, name: "Deadlift", prMetric: .weight)
        let workout = TestFixtures.makeWorkout(context: context, date: Date(), name: "Session A")
        TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: deadlift, sets: [(.working, 100, 5, nil, nil)])
        try context.save()

        let backup = try BackupManager.buildBackup(context: context)

        // Import the exact same backup twice in Merge mode.
        try BackupManager.importBackup(backup, context: context, mode: .merge)
        try BackupManager.importBackup(backup, context: context, mode: .merge)

        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(allWorkouts.filter { $0.name == "Session A" }.count, 1)
    }

    func test_importMerge_doesNotOverwriteExistingExerciseMetadata() throws {
        let chinUp = TestFixtures.makeExercise(context: context, name: "Chin-Up", prMetric: .reps)
        chinUp.notes = "Current notes I don't want overwritten"
        try context.save()

        // An older backup where Chin-Up had different settings
        let backupExercise = BackupExercise(name: "Chin-Up", category: "Accessory", isMainLift: false, prMetric: .weight, notes: "Old stale note")
        let backup = BackupData(version: BackupManager.currentVersion, exportedAt: .now, exercises: [backupExercise], workouts: [])

        try BackupManager.importBackup(backup, context: context, mode: .merge)

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        let restoredChinUp = allExercises.first { $0.name == "Chin-Up" }
        XCTAssertEqual(restoredChinUp?.prMetric, .reps)   // unchanged, not overwritten to .weight
        XCTAssertEqual(restoredChinUp?.notes, "Current notes I don't want overwritten")
    }

    func test_importMerge_stillAddsNewExercisesAndWorkouts() throws {
        let bench = TestFixtures.makeExercise(context: context, name: "Bench Press", prMetric: .weight)
        let existingWorkout = TestFixtures.makeWorkout(context: context, date: Date(), name: "Existing Session")
        TestFixtures.addExerciseEntry(context: context, workout: existingWorkout, exercise: bench, sets: [(.working, 80, 5, nil, nil)])
        try context.save()

        let backupExercise = BackupExercise(name: "Squat", category: "Big 3", isMainLift: true, prMetric: .weight, notes: nil)
        let backupSet = BackupSet(setType: .working, setNumber: 1, weight: 100, reps: 5, rpe: nil, rir: nil)
        let backupEntry = BackupExerciseEntry(exerciseName: "Squat", sets: [backupSet], supersetGroupID: nil)
        let backupWorkout = BackupWorkout(id: UUID(), date: Date(), name: "New Session", notes: nil, sessionStartTime: nil, sessionEndTime: nil, exercises: [backupEntry])
        let backup = BackupData(version: BackupManager.currentVersion, exportedAt: .now, exercises: [backupExercise], workouts: [backupWorkout])

        try BackupManager.importBackup(backup, context: context, mode: .merge)

        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(allWorkouts.count, 2)

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertTrue(allExercises.contains { $0.name == "Squat" })
        XCTAssertTrue(allExercises.contains { $0.name == "Bench Press" })
    }

    func test_importMerge_backupWithoutIDs_stillImportsSuccessfully() throws {
        // Simulates a pre-upgrade backup file with no workout IDs at all.
        let backupExercise = BackupExercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight, notes: nil)
        let backupSet = BackupSet(setType: .working, setNumber: 1, weight: 140, reps: 3, rpe: nil, rir: nil)
        let backupEntry = BackupExerciseEntry(exerciseName: "Deadlift", sets: [backupSet], supersetGroupID: nil)
        let backupWorkout = BackupWorkout(id: nil, date: Date(), name: "Legacy Session", notes: nil, sessionStartTime: nil, sessionEndTime: nil, exercises: [backupEntry])
        let backup = BackupData(version: BackupManager.currentVersion, exportedAt: .now, exercises: [backupExercise], workouts: [backupWorkout])

        try BackupManager.importBackup(backup, context: context, mode: .merge)

        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(allWorkouts.count, 1)
        XCTAssertEqual(allWorkouts.first?.name, "Legacy Session")
    }
    
    func test_roundTrip_preservesExerciseOrderWithinAWorkout() throws {
        let container = TestModelContainer.make()
        let context = ModelContext(container)

        let squat = TestFixtures.makeExercise(context: context, name: "Squat")
        let bench = TestFixtures.makeExercise(context: context, name: "Bench Press")
        let row = TestFixtures.makeExercise(context: context, name: "Row")
        let workout = TestFixtures.makeWorkout(context: context, date: .now)

        let entryB = TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: bench, sets: [])
        let entryS = TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: squat, sets: [])
        let entryR = TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: row, sets: [])
        entryB.order = 0
        entryS.order = 1
        entryR.order = 2
        try context.save()

        let backup = try BackupManager.buildBackup(context: context)
        let data = try BackupManager.encode(backup)
        let decoded = try BackupManager.decode(data)

        let freshContainer = TestModelContainer.make()
        let freshContext = ModelContext(freshContainer)
        try BackupManager.importBackup(decoded, context: freshContext, mode: .replace)

        let importedWorkout = try freshContext.fetch(FetchDescriptor<Workout>()).first!
        let names = importedWorkout.sortedExercises.compactMap { $0.exercise?.name }

        XCTAssertEqual(names, ["Bench Press", "Squat", "Row"], "Exercise order must survive an export/import round-trip")
    }

    func test_import_oldBackupWithoutOrderField_fallsBackToArrayPosition() throws {
        // Simulate a v2 backup captured before the `order` field existed.
        let json = """
        {
            "version": 2,
            "exportedAt": "2026-01-01T00:00:00Z",
            "exercises": [
                {"name": "Squat", "category": "Legs", "isMainLift": true},
                {"name": "Bench Press", "category": "Push", "isMainLift": true}
            ],
            "workouts": [{
                "date": "2026-01-01T00:00:00Z",
                "exercises": [
                    {"exerciseName": "Squat", "sets": []},
                    {"exerciseName": "Bench Press", "sets": []}
                ]
            }]
        }
        """.data(using: .utf8)!

        let decoded = try BackupManager.decode(json)
        let container = TestModelContainer.make()
        let context = ModelContext(container)
        try BackupManager.importBackup(decoded, context: context, mode: .replace)

        let workout = try context.fetch(FetchDescriptor<Workout>()).first!
        let names = workout.sortedExercises.compactMap { $0.exercise?.name }

        XCTAssertEqual(names, ["Squat", "Bench Press"], "Missing order field should fall back to the backup's own array order")
    }
    
    func test_decode_rejectsMalformedSetTypeString() throws {
        let json = """
        {
            "version": 2,
            "exportedAt": "2026-01-01T00:00:00Z",
            "exercises": [],
            "workouts": [{
                "date": "2026-01-01T00:00:00Z",
                "exercises": [{
                    "exerciseName": "Deadlift",
                    "sets": [
                        {"setType": "warm-up", "setNumber": 1, "weight": 60, "reps": 5}
                    ]
                }]
            }]
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try BackupManager.decode(json)) { error in
            XCTAssertTrue(error is DecodingError, "A malformed setType should fail decoding explicitly, not silently default to a category")
        }
    }
}
