//
//  WorkoutTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//

import XCTest
@testable import WorkoutTracker

final class WorkoutTests: XCTestCase {
    private func makeSet(_ type: SetType, _ weight: Double, _ reps: Int) -> SetEntry {
        SetEntry(setType: type, setNumber: 1, weight: weight, reps: reps)
    }

    private func makeEntry(exercise: Exercise, sets: [SetEntry]) -> ExerciseEntry {
        let entry = ExerciseEntry(exercise: exercise)
        entry.sets = sets
        return entry
    }

    // MARK: - Existing totals (raw external-load volume)

    func test_totalWorkingSets_excludesWarmups() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let entry1 = makeEntry(exercise: deadlift, sets: [makeSet(.warmup, 40, 5), makeSet(.working, 100, 5), makeSet(.working, 100, 5)])
        let entry2 = makeEntry(exercise: deadlift, sets: [makeSet(.working, 60, 8)])
        let workout = Workout(date: Date())
        workout.exercises = [entry1, entry2]

        XCTAssertEqual(workout.totalWorkingSets, 3)
    }

    func test_totalReps_sumsOnlyWorkingSetReps() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let entry = makeEntry(exercise: deadlift, sets: [makeSet(.warmup, 40, 10), makeSet(.working, 100, 5), makeSet(.working, 100, 3)])
        let workout = Workout(date: Date())
        workout.exercises = [entry]

        XCTAssertEqual(workout.totalReps, 8)
    }

    func test_totalVolume_isWeightTimesRepsSummedAcrossWorkingSets() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let entry = makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5), makeSet(.working, 120, 3)])
        let workout = Workout(date: Date())
        workout.exercises = [entry]

        XCTAssertEqual(workout.totalVolume, 100 * 5 + 120 * 3, accuracy: 0.001)
    }

    func test_emptyWorkout_hasZeroedTotals() {
        let workout = Workout(date: Date())
        XCTAssertEqual(workout.totalWorkingSets, 0)
        XCTAssertEqual(workout.totalReps, 0)
        XCTAssertEqual(workout.totalVolume, 0)
    }

    // MARK: - totalTrainingVolume (bodyweight/assisted-aware volume)

    func test_totalTrainingVolume_weightExercise_matchesRawVolume() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let entry = makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5)])
        let workout = Workout(date: Date())
        workout.exercises = [entry]

        XCTAssertEqual(workout.totalTrainingVolume(bodyweightKg: 80), 500)
    }

    func test_totalTrainingVolume_bodyweightExercise_isNotZero() {
        // This is the exact bug being fixed: raw totalVolume reports 0 for
        // 0kg bodyweight sets, which is not the actual training load.
        let chinUp = Exercise(name: "Chin-Up", category: "Accessory", isMainLift: false, prMetric: .reps)
        let entry = makeEntry(exercise: chinUp, sets: [makeSet(.working, 0, 10)])
        let workout = Workout(date: Date())
        workout.exercises = [entry]

        XCTAssertEqual(workout.totalVolume, 0)   // old/raw metric, still 0 -- kept as-is, not the fix
        XCTAssertEqual(workout.totalTrainingVolume(bodyweightKg: 80), 800)   // the corrected metric
    }

    func test_totalTrainingVolume_weightedBodyweightExercise_addsExternalWeightToBodyweight() {
        let weightedPullUp = Exercise(name: "Weighted Pull-Up", category: "Accessory", isMainLift: false, prMetric: .reps)
        let entry = makeEntry(exercise: weightedPullUp, sets: [makeSet(.working, 10, 6)])
        let workout = Workout(date: Date())
        workout.exercises = [entry]

        XCTAssertEqual(workout.totalTrainingVolume(bodyweightKg: 80), (80 + 10) * 6)
    }

    func test_totalTrainingVolume_assistedExercise_moreAssistanceMeansLessVolume() {
        let assistedPullUp = Exercise(name: "Assisted Pull-Up", category: "Accessory", isMainLift: false, prMetric: .assisted)

        let lowAssistanceEntry = makeEntry(exercise: assistedPullUp, sets: [makeSet(.working, 10, 8)])
        let highAssistanceEntry = makeEntry(exercise: assistedPullUp, sets: [makeSet(.working, 40, 8)])

        let lowAssistanceWorkout = Workout(date: Date())
        lowAssistanceWorkout.exercises = [lowAssistanceEntry]

        let highAssistanceWorkout = Workout(date: Date())
        highAssistanceWorkout.exercises = [highAssistanceEntry]

        let lowAssistanceVolume = lowAssistanceWorkout.totalTrainingVolume(bodyweightKg: 80)
        let highAssistanceVolume = highAssistanceWorkout.totalTrainingVolume(bodyweightKg: 80)

        // Confirms the inverted relationship is now correct: less assistance
        // (harder set) must report MORE training volume, not less.
        XCTAssertGreaterThan(lowAssistanceVolume, highAssistanceVolume)
        XCTAssertEqual(lowAssistanceVolume, (80 - 10) * 8)
        XCTAssertEqual(highAssistanceVolume, (80 - 40) * 8)
    }

    func test_totalTrainingVolume_mixedWorkout_sumsAcrossDifferentMetricTypes() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let chinUp = Exercise(name: "Chin-Up", category: "Accessory", isMainLift: false, prMetric: .reps)

        let deadliftEntry = makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5)])
        let chinUpEntry = makeEntry(exercise: chinUp, sets: [makeSet(.working, 0, 10)])

        let workout = Workout(date: Date())
        workout.exercises = [deadliftEntry, chinUpEntry]

        let expected = (100.0 * 5) + (80.0 * 10)
        XCTAssertEqual(workout.totalTrainingVolume(bodyweightKg: 80), expected)
    }

    func test_totalTrainingVolume_fallsBackToRawVolumeWhenBodyweightNotSet() {
        let chinUp = Exercise(name: "Chin-Up", category: "Accessory", isMainLift: false, prMetric: .reps)
        let entry = makeEntry(exercise: chinUp, sets: [makeSet(.working, 0, 10)])
        let workout = Workout(date: Date())
        workout.exercises = [entry]

        XCTAssertEqual(workout.totalTrainingVolume(bodyweightKg: 0), workout.totalVolume)
        XCTAssertEqual(workout.totalTrainingVolume(bodyweightKg: 0), 0)
    }

    func test_totalTrainingVolume_emptyWorkout_isZero() {
        let workout = Workout(date: Date())
        XCTAssertEqual(workout.totalTrainingVolume(bodyweightKg: 80), 0)
    }
}
