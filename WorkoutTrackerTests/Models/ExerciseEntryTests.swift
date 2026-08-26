//
//  ExerciseEntryTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import XCTest
@testable import WorkoutTracker

final class ExerciseEntryTests: XCTestCase {
    private func makeExercise() -> Exercise {
        Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
    }

    func test_sortedSets_putsAllWarmupsBeforeAllWorkingSets_regardlessOfEntryOrder() {
        let entry = ExerciseEntry(exercise: makeExercise())
        let working1 = SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5)
        let warmup1 = SetEntry(setType: .warmup, setNumber: 1, weight: 40, reps: 8)
        let working2 = SetEntry(setType: .working, setNumber: 2, weight: 100, reps: 5)
        let warmup2 = SetEntry(setType: .warmup, setNumber: 2, weight: 60, reps: 5)

        // Deliberately interleaved insertion order — this is the exact bug the sort guards against
        entry.sets = [working1, warmup1, working2, warmup2]

        let sorted = entry.sortedSets
        XCTAssertEqual(sorted.map { $0.setType }, [.warmup, .warmup, .working, .working])
        XCTAssertEqual(sorted[0].setNumber, 1)
        XCTAssertEqual(sorted[1].setNumber, 2)
    }

    func test_workingSets_excludesWarmups() {
        let entry = ExerciseEntry(exercise: makeExercise())
        entry.sets = [
            SetEntry(setType: .warmup, setNumber: 1, weight: 40, reps: 8),
            SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5)
        ]

        XCTAssertEqual(entry.workingSets.count, 1)
    }

    func test_averageRPE_computesMeanAcrossWorkingSetsWithRPE() {
        let entry = ExerciseEntry(exercise: makeExercise())
        entry.sets = [
            SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5, rpe: 7.0),
            SetEntry(setType: .working, setNumber: 2, weight: 100, reps: 5, rpe: 9.0)
        ]

        XCTAssertEqual(entry.averageRPE, 8.0)
    }

    func test_averageRPE_nilWhenNoSetsHaveRPE() {
        let entry = ExerciseEntry(exercise: makeExercise())
        entry.sets = [SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5, rir: 2)]

        XCTAssertNil(entry.averageRPE)
    }
}