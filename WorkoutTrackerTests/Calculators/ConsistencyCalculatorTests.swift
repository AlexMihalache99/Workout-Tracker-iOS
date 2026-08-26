//
//  ConsistencyCalculatorTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import XCTest
@testable import WorkoutTracker

final class ConsistencyCalculatorTests: XCTestCase {

    private func daysAgo(_ n: Int, from reference: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: reference)!
    }

    private func makeWorkout(date: Date, sets: Int) -> Workout {
        let exercise = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let workout = Workout(date: date)
        let entry = ExerciseEntry(exercise: exercise)
        entry.workout = workout
        for i in 0..<sets {
            let set = SetEntry(setType: .working, setNumber: i + 1, weight: 100, reps: 5)
            set.exerciseEntry = entry
            entry.sets.append(set)
        }
        workout.exercises = [entry]
        return workout
    }

    func test_currentWeekStreak_countsConsecutiveActiveWeeksIncludingCurrent() {
        let reference = Date()
        let workouts = [
            makeWorkout(date: daysAgo(1, from: reference), sets: 5),
            makeWorkout(date: daysAgo(8, from: reference), sets: 5),
            makeWorkout(date: daysAgo(15, from: reference), sets: 5),
        ]

        let stats = ConsistencyCalculator.build(workouts: workouts, weeksBack: 20, referenceDate: reference)
        XCTAssertEqual(stats.currentWeekStreak, 3)
    }

    func test_currentWeekStreak_isZeroWhenCurrentWeekHasNoActivity() {
        let reference = Date()
        let workouts = [
            makeWorkout(date: daysAgo(15, from: reference), sets: 5),
            makeWorkout(date: daysAgo(22, from: reference), sets: 5),
        ]

        let stats = ConsistencyCalculator.build(workouts: workouts, weeksBack: 20, referenceDate: reference)
        XCTAssertEqual(stats.currentWeekStreak, 0)
    }

    func test_longestWeekStreak_findsLongestRunEvenIfNotCurrent() {
        let reference = Date()
        let workouts = [
            makeWorkout(date: daysAgo(60, from: reference), sets: 5),
            makeWorkout(date: daysAgo(67, from: reference), sets: 5),
            makeWorkout(date: daysAgo(74, from: reference), sets: 5),
            makeWorkout(date: daysAgo(1, from: reference), sets: 5),
        ]

        let stats = ConsistencyCalculator.build(workouts: workouts, weeksBack: 20, referenceDate: reference)
        XCTAssertGreaterThanOrEqual(stats.longestWeekStreak, 3)
    }

    func test_dayIntensityLevel_scalesWithSetCount() {
        XCTAssertEqual(DayActivity(date: Date(), setCount: 0, workoutCount: 0).intensityLevel, 0)
        XCTAssertEqual(DayActivity(date: Date(), setCount: 3, workoutCount: 1).intensityLevel, 1)
        XCTAssertEqual(DayActivity(date: Date(), setCount: 8, workoutCount: 1).intensityLevel, 2)
        XCTAssertEqual(DayActivity(date: Date(), setCount: 13, workoutCount: 1).intensityLevel, 3)
        XCTAssertEqual(DayActivity(date: Date(), setCount: 20, workoutCount: 1).intensityLevel, 4)
    }

    func test_noWorkouts_returnsZeroedStats() {
        let stats = ConsistencyCalculator.build(workouts: [], weeksBack: 20, referenceDate: Date())
        XCTAssertEqual(stats.currentWeekStreak, 0)
        XCTAssertEqual(stats.longestWeekStreak, 0)
        XCTAssertEqual(stats.avgSessionsPerWeek, 0)
    }

    func test_avgSessionsPerWeek_isNotArtificiallyDeflatedForShortHistory() {
        // Only ~2 weeks of real history -- average should reflect that window,
        // not be divided by the full fixed 20-week lookback.
        let reference = Date()
        let workouts = [
            makeWorkout(date: daysAgo(1, from: reference), sets: 5),
            makeWorkout(date: daysAgo(8, from: reference), sets: 5),
        ]

        let stats = ConsistencyCalculator.build(workouts: workouts, weeksBack: 20, referenceDate: reference)
        XCTAssertGreaterThan(stats.avgSessionsPerWeek, 0.5)
    }
}