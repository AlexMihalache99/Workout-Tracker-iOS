//
//  PRCalculatorTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import XCTest
import SwiftData
@testable import WorkoutTracker

final class PRCalculatorTests: XCTestCase {
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

    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    func test_weightPR_isMaxAcrossSessions() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Deadlift", prMetric: .weight)
        let w1 = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 20))
        let w2 = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 10))
        let w3 = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 1))

        let e1 = TestFixtures.addExerciseEntry(context: context, workout: w1, exercise: exercise, sets: [(.working, 100, 5, nil, nil)])
        let e2 = TestFixtures.addExerciseEntry(context: context, workout: w2, exercise: exercise, sets: [(.working, 120, 3, nil, nil)])
        let e3 = TestFixtures.addExerciseEntry(context: context, workout: w3, exercise: exercise, sets: [(.working, 100, 8, nil, nil)])

        XCTAssertEqual(PRCalculator.weightPR(entries: [e1, e2, e3]), 120)
    }

    func test_weightPR_ignoresWarmupSets() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Bench Press", prMetric: .weight)
        let workout = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 1))
        let entry = TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: exercise,
            sets: [(.warmup, 200, 1, nil, nil), (.working, 80, 5, nil, nil)])

        XCTAssertEqual(PRCalculator.weightPR(entries: [entry]), 80)
    }

    func test_bodyweightRatio_computesCorrectly() {
        let ratio = PRCalculator.bodyweightRatio(prWeightKg: 150, bodyweightKg: 90)
        XCTAssertEqual(ratio!, 150.0 / 90.0, accuracy: 0.0001)
    }

    func test_bodyweightRatio_nilWhenBodyweightNotSet() {
        XCTAssertNil(PRCalculator.bodyweightRatio(prWeightKg: 150, bodyweightKg: 0))
    }

    func test_bodyweightRatio_nilWhenNoPR() {
        XCTAssertNil(PRCalculator.bodyweightRatio(prWeightKg: nil, bodyweightKg: 90))
    }

    func test_repsPR_onlyCountsBodyweightSets() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Chin-Up", prMetric: .reps)
        let w1 = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 10))
        let w2 = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 1))

        let e1 = TestFixtures.addExerciseEntry(context: context, workout: w1, exercise: exercise, sets: [(.working, 0, 8, nil, nil)])
        let e2 = TestFixtures.addExerciseEntry(context: context, workout: w2, exercise: exercise, sets: [(.working, 10, 12, nil, nil)])

        // The weighted set (10kg, 12 reps) must NOT count toward the bodyweight reps PR
        XCTAssertEqual(PRCalculator.repsPR(entries: [e1, e2]), 8)
    }

    func test_repsPR_nilWhenOnlyWeightedSetsLogged() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Weighted Pull-Up", prMetric: .weight)
        let workout = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 1))
        let entry = TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: exercise, sets: [(.working, 10, 6, nil, nil)])

        XCTAssertNil(PRCalculator.repsPR(entries: [entry]))
    }

    func test_assistedPR_isLeastAssistanceSession() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Assisted Pull-Up", prMetric: .assisted)
        let w1 = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 20))
        let w2 = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 1))

        let e1 = TestFixtures.addExerciseEntry(context: context, workout: w1, exercise: exercise, sets: [(.working, 20, 6, nil, nil)])
        let e2 = TestFixtures.addExerciseEntry(context: context, workout: w2, exercise: exercise, sets: [(.working, 10, 6, nil, nil)])

        // effective load: session1 = 80-20=60, session2 = 80-10=70 -> PR is 70
        XCTAssertEqual(PRCalculator.assistedPR(entries: [e1, e2], bodyweightKg: 80), 70)
    }

    func test_assistedPR_nilWhenBodyweightNotSet() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Assisted Dip", prMetric: .assisted)
        let workout = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 1))
        let entry = TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: exercise, sets: [(.working, 15, 6, nil, nil)])

        XCTAssertNil(PRCalculator.assistedPR(entries: [entry], bodyweightKg: 0))
    }

    func test_assistedPR_usesLeastAssistanceSetWithinASession() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Assisted Chin-Up", prMetric: .assisted)
        let workout = TestFixtures.makeWorkout(context: context, date: date(daysAgo: 1))
        let entry = TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: exercise,
            sets: [(.working, 20, 6, nil, nil), (.working, 10, 4, nil, nil), (.working, 15, 5, nil, nil)])

        XCTAssertEqual(PRCalculator.assistedPR(entries: [entry], bodyweightKg: 80), 70)
    }
    
    func test_assistedDataPoints_clampsNegativeEffectiveLoadToZero() {
        let exercise = TestFixtures.makeExercise(context: context, name: "Assisted Pull-Up", prMetric: .assisted)
        let workout = TestFixtures.makeWorkout(context: context, date: Date())
        let entry = TestFixtures.addExerciseEntry(context: context, workout: workout, exercise: exercise, sets: [(.working, 60, 6, nil, nil)])

        let points = PRCalculator.assistedDataPoints(entries: [entry], bodyweightKg: 50)
        XCTAssertEqual(points.first?.value, 0)
    }
}
