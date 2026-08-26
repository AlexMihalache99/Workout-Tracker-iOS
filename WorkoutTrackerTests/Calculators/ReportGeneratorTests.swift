//
//  ReportGeneratorTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import XCTest
@testable import WorkoutTracker

final class ReportGeneratorTests: XCTestCase {

    private func makeSet(_ type: SetType, _ weight: Double, _ reps: Int, rpe: Double? = nil, rir: Int? = nil) -> SetEntry {
        SetEntry(setType: type, setNumber: 1, weight: weight, reps: reps, rpe: rpe, rir: rir)
    }

    private func makeEntry(exercise: Exercise, sets: [SetEntry]) -> ExerciseEntry {
        let entry = ExerciseEntry(exercise: exercise)
        for set in sets { set.exerciseEntry = entry }
        entry.sets = sets
        return entry
    }

    private func makeWorkout(date: Date, exercises: [ExerciseEntry]) -> Workout {
        let workout = Workout(date: date)
        for entry in exercises { entry.workout = workout }
        workout.exercises = exercises
        return workout
    }

    private func daysAgo(_ n: Int, from reference: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: reference)!
    }

    // MARK: - Date boundaries

    func test_generate_includesWorkoutsExactlyOnStartAndEndBoundary() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let start = daysAgo(14)
        let end = daysAgo(0)

        let onStart = makeWorkout(date: start, exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5)])])
        let onEnd = makeWorkout(date: end, exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 110, 5)])])

        let report = ReportGenerator.generate(
            workouts: [onStart, onEnd], allExercises: [deadlift],
            start: start, end: end, phase: .strength, bodyweightKg: 0
        )

        XCTAssertEqual(report.totalWorkouts, 2)
    }

    func test_generate_excludesWorkoutsOutsideRange() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let start = daysAgo(14)
        let end = daysAgo(0)

        let before = makeWorkout(date: daysAgo(20), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5)])])
        let after = makeWorkout(date: daysAgo(-1), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5)])])
        let inside = makeWorkout(date: daysAgo(7), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5)])])

        let report = ReportGenerator.generate(
            workouts: [before, after, inside], allExercises: [deadlift],
            start: start, end: end, phase: .strength, bodyweightKg: 0
        )

        XCTAssertEqual(report.totalWorkouts, 1)
    }

    func test_generate_emptyPeriod_returnsNoWorkoutsInsight() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let report = ReportGenerator.generate(
            workouts: [], allExercises: [deadlift],
            start: daysAgo(14), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )
        XCTAssertEqual(report.totalWorkouts, 0)
        XCTAssertTrue(report.insights.contains("No workouts logged in this period."))
    }

    // MARK: - RPE/RIR invariants

    func test_effortScore_usesRPEDirectlyWhenPresent() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let workout = makeWorkout(date: daysAgo(1), exercises: [
            makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5, rpe: 8.0)])
        ])

        let report = ReportGenerator.generate(
            workouts: [workout], allExercises: [deadlift],
            start: daysAgo(7), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        XCTAssertEqual(report.weeklyStats.first?.avgEffort, 8.0)
    }

    func test_effortScore_derivesFromRIR_asTenMinusRIR() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let workout = makeWorkout(date: daysAgo(1), exercises: [
            makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5, rir: 2)])
        ])

        let report = ReportGenerator.generate(
            workouts: [workout], allExercises: [deadlift],
            start: daysAgo(7), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        XCTAssertEqual(report.weeklyStats.first?.avgEffort, 8.0)
    }

    func test_effortScore_nilWhenNeitherRPEnorRIRProvided() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let workout = makeWorkout(date: daysAgo(1), exercises: [
            makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5)])
        ])

        let report = ReportGenerator.generate(
            workouts: [workout], allExercises: [deadlift],
            start: daysAgo(7), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        XCTAssertNil(report.weeklyStats.first?.avgEffort)
    }

    // MARK: - Lift progress semantics

    func test_liftProgress_comparesFirstSessionToPeriodBest_notLastSession() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let w1 = makeWorkout(date: daysAgo(20), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 5)])])
        let w2 = makeWorkout(date: daysAgo(10), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 120, 1)])])
        let w3 = makeWorkout(date: daysAgo(1), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 8)])])

        let report = ReportGenerator.generate(
            workouts: [w1, w2, w3], allExercises: [deadlift],
            start: daysAgo(21), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        let lift = report.liftProgress.first { $0.exerciseName == "Deadlift" }
        XCTAssertEqual(lift?.earliestWeight, 100)
        XCTAssertEqual(lift?.bestWeight, 120)
        XCTAssertEqual(lift?.weightDelta, 20)
    }

    func test_bodyweightRatio_includedWhenBodyweightProvided() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let workout = makeWorkout(date: daysAgo(1), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 150, 1)])])

        let report = ReportGenerator.generate(
            workouts: [workout], allExercises: [deadlift],
            start: daysAgo(7), end: daysAgo(0), phase: .strength, bodyweightKg: 90
        )

        let lift = report.liftProgress.first { $0.exerciseName == "Deadlift" }
        XCTAssertEqual(lift?.bodyweightRatio ?? 0, 150.0 / 90.0, accuracy: 0.0001)
    }

    func test_repsExercise_flagsAddedWeightSeparatelyFromRepsDelta() {
        let chinUp = Exercise(name: "Chin-Up", category: "Accessory", isMainLift: false, prMetric: .reps)
        let w1 = makeWorkout(date: daysAgo(10), exercises: [makeEntry(exercise: chinUp, sets: [makeSet(.working, 0, 5)])])
        let w2 = makeWorkout(date: daysAgo(1), exercises: [makeEntry(exercise: chinUp, sets: [
            makeSet(.working, 0, 8),
            makeSet(.working, 10, 4)
        ])])

        let report = ReportGenerator.generate(
            workouts: [w1, w2], allExercises: [chinUp],
            start: daysAgo(14), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        let lift = report.liftProgress.first { $0.exerciseName == "Chin-Up" }
        XCTAssertEqual(lift?.earliestReps, 5)
        XCTAssertEqual(lift?.bestReps, 8)
        XCTAssertTrue(lift?.addedWeightSeen ?? false)
        XCTAssertEqual(lift?.maxAddedWeight, 10)
    }

    func test_assistedExercise_effectiveLoadDelta_reflectsDecreasingAssistance() {
        let assistedPullUp = Exercise(name: "Assisted Pull-Up", category: "Accessory", isMainLift: false, prMetric: .assisted)
        let w1 = makeWorkout(date: daysAgo(20), exercises: [makeEntry(exercise: assistedPullUp, sets: [makeSet(.working, 25, 6)])])
        let w2 = makeWorkout(date: daysAgo(1), exercises: [makeEntry(exercise: assistedPullUp, sets: [makeSet(.working, 15, 6)])])

        let report = ReportGenerator.generate(
            workouts: [w1, w2], allExercises: [assistedPullUp],
            start: daysAgo(21), end: daysAgo(0), phase: .strength, bodyweightKg: 80
        )

        let lift = report.liftProgress.first { $0.exerciseName == "Assisted Pull-Up" }
        XCTAssertEqual(lift?.earliestEffectiveLoad, 55)
        XCTAssertEqual(lift?.bestEffectiveLoad, 65)
        XCTAssertEqual(lift?.effectiveLoadDelta, 10)
    }

    func test_untrackedExercise_isExcludedFromLiftProgress() {
        let curl = Exercise(name: "Barbell Curl", category: "Accessory", isMainLift: false, prMetric: nil)
        let workout = makeWorkout(date: daysAgo(1), exercises: [makeEntry(exercise: curl, sets: [makeSet(.working, 30, 10)])])

        let report = ReportGenerator.generate(
            workouts: [workout], allExercises: [curl],
            start: daysAgo(7), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        XCTAssertTrue(report.liftProgress.isEmpty)
    }

    // MARK: - Deload signal
    
    func test_deloadSignal_doesNotFireWhenThreeWeeksHaveGap() {
        let deadlift = Exercise(
            name: "Deadlift",
            category: "Big 3",
            isMainLift: true,
            prMetric: .weight
        )

        let w1 = makeWorkout(
            date: daysAgo(28),
            exercises: [
                makeEntry(
                    exercise: deadlift,
                    sets: [makeSet(.working, 140, 3, rpe: 7.0)]
                )
            ]
        )

        let w3 = makeWorkout(
            date: daysAgo(14),
            exercises: [
                makeEntry(
                    exercise: deadlift,
                    sets: [makeSet(.working, 140, 3, rpe: 8.5)]
                )
            ]
        )

        let w4 = makeWorkout(
            date: daysAgo(7),
            exercises: [
                makeEntry(
                    exercise: deadlift,
                    sets: [makeSet(.working, 140, 3, rpe: 9.5)]
                )
            ]
        )

        let report = ReportGenerator.generate(
            workouts: [w1, w3, w4],
            allExercises: [deadlift],
            start: daysAgo(30),
            end: daysAgo(0),
            phase: .strength,
            bodyweightKg: 0
        )

        let lift = report.liftProgress.first { $0.exerciseName == "Deadlift" }

        XCTAssertFalse(lift?.deloadSignal ?? true)
    }


    func test_deloadSignal_firesWhenEffortRisesAndWeightStagnates() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let w1 = makeWorkout(date: daysAgo(28), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 7.0)])])
        let w2 = makeWorkout(date: daysAgo(21), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 7.5)])])
        let w3 = makeWorkout(date: daysAgo(14), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 8.5)])])
        let w4 = makeWorkout(date: daysAgo(7), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 9.5)])])

        let report = ReportGenerator.generate(
            workouts: [w1, w2, w3, w4], allExercises: [deadlift],
            start: daysAgo(30), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        let lift = report.liftProgress.first { $0.exerciseName == "Deadlift" }
        XCTAssertTrue(lift?.deloadSignal ?? false)
    }

    func test_deloadSignal_doesNotFireWhenWeightIsProgressing() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let w1 = makeWorkout(date: daysAgo(21), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 130, 3, rpe: 7.0)])])
        let w2 = makeWorkout(date: daysAgo(14), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 135, 3, rpe: 8.0)])])
        let w3 = makeWorkout(date: daysAgo(7), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 9.0)])])

        let report = ReportGenerator.generate(
            workouts: [w1, w2, w3], allExercises: [deadlift],
            start: daysAgo(21), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        let lift = report.liftProgress.first { $0.exerciseName == "Deadlift" }
        XCTAssertFalse(lift?.deloadSignal ?? true)
    }

    func test_deloadSignal_doesNotFireWithFewerThanThreeWeeksOfData() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let w1 = makeWorkout(date: daysAgo(7), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 8.0)])])
        let w2 = makeWorkout(date: daysAgo(1), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 9.0)])])

        let report = ReportGenerator.generate(
            workouts: [w1, w2], allExercises: [deadlift],
            start: daysAgo(7), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        let lift = report.liftProgress.first { $0.exerciseName == "Deadlift" }
        XCTAssertFalse(lift?.deloadSignal ?? true)
    }
    
    func test_deloadSignal_doesNotFireWhenWeeksAreNotConsecutive() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        // Weeks at day -28, -21, -7 (missing week at -14) -- a real gap
        let w1 = makeWorkout(date: daysAgo(28), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 7.0)])])
        let w2 = makeWorkout(date: daysAgo(21), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 8.0)])])
        let w3 = makeWorkout(date: daysAgo(7), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 140, 3, rpe: 9.0)])])

        let report = ReportGenerator.generate(
            workouts: [w1, w2, w3], allExercises: [deadlift],
            start: daysAgo(30), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        let lift = report.liftProgress.first { $0.exerciseName == "Deadlift" }
        XCTAssertFalse(lift?.deloadSignal ?? true)
    }

    func test_deloadSignal_doesNotFireWhenMidWindowWeightIncreases() {
        let deadlift = Exercise(name: "Deadlift", category: "Big 3", isMainLift: true, prMetric: .weight)
        let w1 = makeWorkout(date: daysAgo(21), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 3, rpe: 7.0)])])
        let w2 = makeWorkout(date: daysAgo(14), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 105, 3, rpe: 8.0)])])
        let w3 = makeWorkout(date: daysAgo(7), exercises: [makeEntry(exercise: deadlift, sets: [makeSet(.working, 100, 3, rpe: 9.0)])])

        let report = ReportGenerator.generate(
            workouts: [w1, w2, w3], allExercises: [deadlift],
            start: daysAgo(21), end: daysAgo(0), phase: .strength, bodyweightKg: 0
        )

        // Old implementation (first vs. last only: 100 <= 100) would have
        // incorrectly fired here despite the real bump in week 2.
        let lift = report.liftProgress.first { $0.exerciseName == "Deadlift" }
        XCTAssertFalse(lift?.deloadSignal ?? true)
    }
}
