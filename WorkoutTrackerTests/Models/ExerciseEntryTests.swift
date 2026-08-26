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

    func test_totalTrainingVolume_weightMetric_sameAsRawVolume() {
        let exercise = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let entry = ExerciseEntry(exercise: exercise)
        entry.sets = [SetEntry(setType: .working, setNumber: 1, weight: 100, reps: 5)]

        XCTAssertEqual(entry.totalTrainingVolume(bodyweightKg: 80), 500)
    }

    func test_totalTrainingVolume_repsMetric_usesBodyweightForZeroWeightSets() {
        let exercise = Exercise(name: "Chin-Up", category: "Accessory", isMainLift: false, prMetric: .reps)
        let entry = ExerciseEntry(exercise: exercise)
        entry.sets = [SetEntry(setType: .working, setNumber: 1, weight: 0, reps: 10)]

        // Old totalVolume would report 0 here -- this is the bug being fixed
        XCTAssertEqual(entry.totalTrainingVolume(bodyweightKg: 80), 800)
    }

    func test_totalTrainingVolume_repsMetric_addsExternalWeightToBodyweight() {
        let exercise = Exercise(name: "Weighted Pull-Up", category: "Accessory", isMainLift: false, prMetric: .reps)
        let entry = ExerciseEntry(exercise: exercise)
        entry.sets = [SetEntry(setType: .working, setNumber: 1, weight: 10, reps: 6)]

        XCTAssertEqual(entry.totalTrainingVolume(bodyweightKg: 80), (80 + 10) * 6)
    }

    func test_totalTrainingVolume_assistedMetric_subtractsAssistanceFromBodyweight() {
        let exercise = Exercise(name: "Assisted Pull-Up", category: "Accessory", isMainLift: false, prMetric: .assisted)
        let entry = ExerciseEntry(exercise: exercise)
        entry.sets = [SetEntry(setType: .working, setNumber: 1, weight: 30, reps: 10)]

        // Old totalVolume would report 300 (30 x 10) and INCREASE with more assistance --
        // this confirms the corrected, inverted relationship: more assistance = less load
        XCTAssertEqual(entry.totalTrainingVolume(bodyweightKg: 80), (80 - 30) * 10)
    }

    func test_totalTrainingVolume_fallsBackToRawVolumeWhenBodyweightNotSet() {
        let exercise = Exercise(name: "Chin-Up", category: "Accessory", isMainLift: false, prMetric: .reps)
        let entry = ExerciseEntry(exercise: exercise)
        entry.sets = [SetEntry(setType: .working, setNumber: 1, weight: 0, reps: 10)]

        XCTAssertEqual(entry.totalTrainingVolume(bodyweightKg: 0), entry.totalVolume)
    }
}
