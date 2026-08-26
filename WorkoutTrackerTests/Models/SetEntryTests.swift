//
//  SetEntryTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import XCTest
@testable import WorkoutTracker

final class SetEntryTests: XCTestCase {

    func test_init_storesAllProvidedValues() {
        let set = SetEntry(setType: .working, setNumber: 2, weight: 100, reps: 5, rpe: 8.5, rir: nil)

        XCTAssertEqual(set.setType, .working)
        XCTAssertEqual(set.setNumber, 2)
        XCTAssertEqual(set.weight, 100)
        XCTAssertEqual(set.reps, 5)
        XCTAssertEqual(set.rpe, 8.5)
        XCTAssertNil(set.rir)
    }

    func test_init_defaultsRPEAndRIRToNilWhenOmitted() {
        let set = SetEntry(setType: .warmup, setNumber: 1, weight: 40, reps: 8)

        XCTAssertNil(set.rpe)
        XCTAssertNil(set.rir)
    }

    func test_warmupSet_canHaveZeroWeight_forBodyweightExercises() {
        // Bodyweight movements (Chin-Up, Dips, etc.) are logged at 0kg -- this
        // must remain a valid, storable state, not something the model rejects.
        let set = SetEntry(setType: .working, setNumber: 1, weight: 0, reps: 8)

        XCTAssertEqual(set.weight, 0)
    }

    func test_rirCanBeStoredIndependentlyOfRPE() {
        let set = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5, rpe: nil, rir: 2)

        XCTAssertNil(set.rpe)
        XCTAssertEqual(set.rir, 2)
    }

    func test_setType_warmupAndWorking_areDistinctAndCodable() {
        // SetType backs storage as a raw String via Codable, so round-tripping
        // through its rawValue must be lossless -- this is the same mechanism
        // BackupManager relies on when serializing "warmup"/"working" strings.
        XCTAssertEqual(SetType.warmup.rawValue, "warmup")
        XCTAssertEqual(SetType.working.rawValue, "working")
        XCTAssertEqual(SetType(rawValue: "warmup"), .warmup)
        XCTAssertEqual(SetType(rawValue: "working"), .working)
    }

    func test_exerciseEntryBackReference_startsNilUntilAssigned() {
        let set = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5)
        XCTAssertNil(set.exerciseEntry)

        let exercise = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let entry = ExerciseEntry(exercise: exercise)
        set.exerciseEntry = entry

        XCTAssertNotNil(set.exerciseEntry)
        XCTAssertEqual(set.exerciseEntry?.exercise?.name, "Deadlift")
    }
    
    func test_init_clampsWeightToNonNegative() {
        let set = SetEntry(setType: .working, setNumber: 1, weight: -50, reps: 5)
        XCTAssertEqual(set.weight, 0)
    }

    func test_init_clampsRepsToNonNegative() {
        let set = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: -3)
        XCTAssertEqual(set.reps, 0)
    }

    func test_init_clampsRPEToValidRange() {
        let tooHigh = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5, rpe: 14)
        let tooLow = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5, rpe: 0.1)
        XCTAssertEqual(tooHigh.rpe, 10)
        XCTAssertEqual(tooLow.rpe, 0.5)
    }

    func test_init_clampsRIRToValidRange() {
        let tooHigh = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5, rir: 20)
        let tooLow = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5, rir: -10)
        XCTAssertEqual(tooHigh.rir, 5)
        XCTAssertEqual(tooLow.rir, 0)
    }

    func test_init_whenBothRPEAndRIRProvided_RPEWinsAndRIRIsCleared() {
        let set = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5, rpe: 8, rir: 2)
        XCTAssertEqual(set.rpe, 8)
        XCTAssertNil(set.rir)
    }

    func test_normalize_reclampsAfterDirectMutation() {
        let set = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5)
        set.weight = -20
        set.rpe = 99

        set.normalize()

        XCTAssertEqual(set.weight, 0)
        XCTAssertEqual(set.rpe, 10)
    }
}
