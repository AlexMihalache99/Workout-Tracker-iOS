//
//  WarmupSuggesterTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import XCTest
@testable import WorkoutTracker

final class WarmupSuggesterTests: XCTestCase {
    func test_standardRamp_forTypicalWorkingWeight() {
        let sets = WarmupSuggester.suggest(targetWeightKg: 140, barWeightKg: 20)
        XCTAssertEqual(sets.count, 4)

        XCTAssertEqual(sets[0].weightKg, 20, accuracy: 0.001)
        XCTAssertEqual(sets[0].reps, 8)
        XCTAssertEqual(sets[0].label, "Bar")

        XCTAssertEqual(sets[1].weightKg, 55, accuracy: 0.001)
        XCTAssertEqual(sets[1].reps, 5)

        XCTAssertEqual(sets[2].weightKg, 85, accuracy: 0.001)
        XCTAssertEqual(sets[2].reps, 3)

        XCTAssertEqual(sets[3].weightKg, 112.5, accuracy: 0.001)
        XCTAssertEqual(sets[3].reps, 2)
    }

    func test_targetBelowBarWeight_returnsEmpty() {
        let sets = WarmupSuggester.suggest(targetWeightKg: 15, barWeightKg: 20)
        XCTAssertTrue(sets.isEmpty)
    }

    func test_targetEqualsBarWeight_returnsEmpty() {
        let sets = WarmupSuggester.suggest(targetWeightKg: 20, barWeightKg: 20)
        XCTAssertTrue(sets.isEmpty)
    }

    func test_allSuggestedWeights_areAtLeastBarWeight() {
        let sets = WarmupSuggester.suggest(targetWeightKg: 30, barWeightKg: 20)
        for set in sets {
            XCTAssertGreaterThanOrEqual(set.weightKg, 20)
        }
    }

    func test_allSuggestedWeights_areRoundedTo2point5Increment() {
        let sets = WarmupSuggester.suggest(targetWeightKg: 137, barWeightKg: 20)
        for set in sets {
            let remainder = set.weightKg.truncatingRemainder(dividingBy: 2.5)
            XCTAssertEqual(remainder, 0, accuracy: 0.0001)
        }
    }
}