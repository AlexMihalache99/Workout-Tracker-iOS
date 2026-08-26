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

    private func makeEntry(sets: [SetEntry]) -> ExerciseEntry {
        let exercise = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let entry = ExerciseEntry(exercise: exercise)
        entry.sets = sets
        return entry
    }

    func test_totalWorkingSets_excludesWarmups() {
        let entry1 = makeEntry(sets: [makeSet(.warmup, 40, 5), makeSet(.working, 100, 5), makeSet(.working, 100, 5)])
        let entry2 = makeEntry(sets: [makeSet(.working, 60, 8)])
        let workout = Workout(date: Date())
        workout.exercises = [entry1, entry2]

        XCTAssertEqual(workout.totalWorkingSets, 3)
    }

    func test_totalReps_sumsOnlyWorkingSetReps() {
        let entry = makeEntry(sets: [makeSet(.warmup, 40, 10), makeSet(.working, 100, 5), makeSet(.working, 100, 3)])
        let workout = Workout(date: Date())
        workout.exercises = [entry]

        XCTAssertEqual(workout.totalReps, 8)
    }

    func test_totalVolume_isWeightTimesRepsSummedAcrossWorkingSets() {
        let entry = makeEntry(sets: [makeSet(.working, 100, 5), makeSet(.working, 120, 3)])
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
}