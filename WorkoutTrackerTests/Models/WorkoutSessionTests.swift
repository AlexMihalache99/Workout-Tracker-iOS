//
//  WorkoutSessionTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class WorkoutSessionTests: XCTestCase {
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


    func test_freshWorkout_isNotTrackedUntilSaved() {
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)

        XCTAssertFalse(session.isTracked)
    }

    func test_discard_onUntrackedWorkout_isNoOp() {
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)

        session.discard()   // should not throw or crash; nothing was ever inserted

        let all = try? context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(all?.count ?? 0, 0)
    }

    func test_addingExercise_implicitlyTracksTheWorkout() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Deadlift")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)

        session.addExercise(exercise)

        // Matches the real SwiftData behavior this app has already hit before:
        // linking a persisted Exercise implicitly tracks the parent Workout.
        XCTAssertTrue(session.isTracked)
    }

    func test_discard_afterAddingExercise_removesItFromContext() throws {
        let exercise = TestFixtures.makeExercise(context: context, name: "Deadlift")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)

        session.addExercise(exercise)
        XCTAssertTrue(session.isTracked)

        session.discard()

        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(allWorkouts.count, 0)
    }

    func test_save_insertsWorkoutIntoContext() throws {
        let exercise = TestFixtures.makeExercise(context: context, name: "Deadlift")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise)

        let result = session.save()

        XCTAssertNotNil(result)
        let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(allWorkouts.count, 1)
    }

    func test_save_returnsNilWhenNoExercisesAdded() {
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)

        XCTAssertNil(session.save())
    }

    func test_save_returnsNilWhileInPairingMode() {
        let exercise1 = TestFixtures.makeExercise(context: context, name: "Bench Press")
        let exercise2 = TestFixtures.makeExercise(context: context, name: "Barbell Row")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise1)
        session.addExercise(exercise2)
        session.isPairingMode = true

        XCTAssertNil(session.save())
    }

    func test_save_returnsCorrectTotalsForHealthKitSync() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Deadlift")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise)

        let entry = workout.exercises[0]
        session.addSet(SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5), to: entry)
        session.addSet(SetEntry(setType: .working, setNumber: 2, weight: 100, reps: 5), to: entry)

        let result = session.save()

        XCTAssertEqual(result?.sets, 2)
        XCTAssertEqual(result?.volumeKg, 1000)
    }

    // MARK: - Exercise / set management

    func test_deleteExerciseEntry_removesFromWorkout() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Deadlift")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise)

        let entry = workout.exercises[0]
        session.deleteExerciseEntry(entry)

        XCTAssertTrue(workout.exercises.isEmpty)
    }

    func test_deleteSets_removesOnlyTargetedIndices() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Deadlift")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise)
        let entry = workout.exercises[0]

        let warmup = SetEntry(setType: .warmup, setNumber: 1, weight: 40, reps: 8)
        let working1 = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5)
        let working2 = SetEntry(setType: .working, setNumber: 2, weight: 100, reps: 5)
        session.addSet(warmup, to: entry)
        session.addSet(working1, to: entry)
        session.addSet(working2, to: entry)

        // sortedSets order: [warmup, working1, working2] -- delete index 1 (working1)
        session.deleteSets(from: entry, at: IndexSet(integer: 1))

        XCTAssertEqual(entry.sets.count, 2)
        XCTAssertTrue(entry.sets.contains { $0.persistentModelID == warmup.persistentModelID })
        XCTAssertTrue(entry.sets.contains { $0.persistentModelID == working2.persistentModelID })
        XCTAssertFalse(entry.sets.contains { $0.persistentModelID == working1.persistentModelID })
    }

    // MARK: - Superset pairing

    func test_confirmPairing_requiresExactlyTwoSelected() {
        let exercise1 = TestFixtures.makeExercise(context: context, name: "Bench Press")
        let exercise2 = TestFixtures.makeExercise(context: context, name: "Barbell Row")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise1)
        session.addExercise(exercise2)

        session.togglePairingSelection(workout.exercises[0])
        session.confirmPairing()   // only 1 selected -- should be a no-op

        XCTAssertNil(workout.exercises[0].supersetGroupID)
    }

    func test_confirmPairing_linksBothEntriesWithSameGroupID() {
        let exercise1 = TestFixtures.makeExercise(context: context, name: "Bench Press")
        let exercise2 = TestFixtures.makeExercise(context: context, name: "Barbell Row")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise1)
        session.addExercise(exercise2)

        session.togglePairingSelection(workout.exercises[0])
        session.togglePairingSelection(workout.exercises[1])
        session.confirmPairing()

        let groupID = workout.exercises[0].supersetGroupID
        XCTAssertNotNil(groupID)
        XCTAssertEqual(workout.exercises[1].supersetGroupID, groupID)
        XCTAssertFalse(session.isPairingMode)
        XCTAssertTrue(session.selectedForPairing.isEmpty)
    }

    func test_togglePairingSelection_capsAtTwoSelections() {
        let e1 = TestFixtures.makeExercise(context: context, name: "A")
        let e2 = TestFixtures.makeExercise(context: context, name: "B")
        let e3 = TestFixtures.makeExercise(context: context, name: "C")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(e1); session.addExercise(e2); session.addExercise(e3)

        session.togglePairingSelection(workout.exercises[0])
        session.togglePairingSelection(workout.exercises[1])
        session.togglePairingSelection(workout.exercises[2])   // should be ignored, already 2 selected

        XCTAssertEqual(session.selectedForPairing.count, 2)
    }

    func test_unlinkSuperset_clearsGroupIDOnBothEntries() {
        let exercise1 = TestFixtures.makeExercise(context: context, name: "Bench Press")
        let exercise2 = TestFixtures.makeExercise(context: context, name: "Barbell Row")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise1)
        session.addExercise(exercise2)
        session.togglePairingSelection(workout.exercises[0])
        session.togglePairingSelection(workout.exercises[1])
        session.confirmPairing()

        session.unlinkSuperset(workout.exercises)

        XCTAssertNil(workout.exercises[0].supersetGroupID)
        XCTAssertNil(workout.exercises[1].supersetGroupID)
    }

    func test_displayGroups_groupsPairedExercisesTogether() {
        let exercise1 = TestFixtures.makeExercise(context: context, name: "Bench Press")
        let exercise2 = TestFixtures.makeExercise(context: context, name: "Barbell Row")
        let exercise3 = TestFixtures.makeExercise(context: context, name: "Squat")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise1); session.addExercise(exercise2); session.addExercise(exercise3)
        session.togglePairingSelection(workout.exercises[0])
        session.togglePairingSelection(workout.exercises[1])
        session.confirmPairing()

        let groups = session.displayGroups
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first { $0.count == 2 }?.count, 2)
        XCTAssertEqual(groups.first { $0.count == 1 }?.first?.exercise?.name, "Squat")
    }

    // MARK: - Rest timer decision (the 0-rest-between-superset-partners rule)

    func test_shouldStartRestTimer_alwaysTrueForStandaloneExercise() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Deadlift")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exercise)
        let entry = workout.exercises[0]
        session.addSet(SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5), to: entry)

        XCTAssertTrue(session.shouldStartRestTimer(after: entry))
    }

    func test_shouldStartRestTimer_falseForSupersetPartner_whenPartnerHasNotCaughtUp() {
        let exerciseA = TestFixtures.makeExercise(context: context, name: "Bench Press")
        let exerciseB = TestFixtures.makeExercise(context: context, name: "Barbell Row")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exerciseA); session.addExercise(exerciseB)
        session.togglePairingSelection(workout.exercises[0])
        session.togglePairingSelection(workout.exercises[1])
        session.confirmPairing()

        let entryA = workout.exercises[0]
        session.addSet(SetEntry(setType: .working, setNumber: 1, weight: 60, reps: 8), to: entryA)

        // entryB has 0 working sets so far -- round isn't complete
        XCTAssertFalse(session.shouldStartRestTimer(after: entryA))
    }

    func test_shouldStartRestTimer_trueOnceRoundIsComplete() {
        let exerciseA = TestFixtures.makeExercise(context: context, name: "Bench Press")
        let exerciseB = TestFixtures.makeExercise(context: context, name: "Barbell Row")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exerciseA); session.addExercise(exerciseB)
        session.togglePairingSelection(workout.exercises[0])
        session.togglePairingSelection(workout.exercises[1])
        session.confirmPairing()

        let entryA = workout.exercises[0]
        let entryB = workout.exercises[1]
        session.addSet(SetEntry(setType: .working, setNumber: 1, weight: 60, reps: 8), to: entryA)
        session.addSet(SetEntry(setType: .working, setNumber: 1, weight: 40, reps: 10), to: entryB)

        // entryB has now caught up to entryA's set count -- round 1 complete
        XCTAssertTrue(session.shouldStartRestTimer(after: entryB))
    }

    func test_shouldStartRestTimer_falseAgainOnNextRoundUntilPartnerCatchesUp() {
        let exerciseA = TestFixtures.makeExercise(context: context, name: "Bench Press")
        let exerciseB = TestFixtures.makeExercise(context: context, name: "Barbell Row")
        let workout = Workout(date: Date())
        let session = WorkoutSession(workout: workout, context: context)
        session.addExercise(exerciseA); session.addExercise(exerciseB)
        session.togglePairingSelection(workout.exercises[0])
        session.togglePairingSelection(workout.exercises[1])
        session.confirmPairing()

        let entryA = workout.exercises[0]
        let entryB = workout.exercises[1]
        session.addSet(SetEntry(setType: .working, setNumber: 1, weight: 60, reps: 8), to: entryA)
        session.addSet(SetEntry(setType: .working, setNumber: 1, weight: 40, reps: 10), to: entryB)

        // Round 2 begins
        session.addSet(SetEntry(setType: .working, setNumber: 2, weight: 60, reps: 8), to: entryA)
        XCTAssertFalse(session.shouldStartRestTimer(after: entryA))
    }
}
