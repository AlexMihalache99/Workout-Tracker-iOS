//
//  PlateCalculatorTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import XCTest
@testable import WorkoutTracker

final class PlateCalculatorTests: XCTestCase {
    func test_exactMatch_standardWeight() {
        // 142.5kg target, 20kg bar -> 61.25 per side -> 25+25+10+1.25
        let result = PlateCalculator.calculate(targetWeight: 142.5, barWeight: 20)
        XCTAssertEqual(result.platesPerSide, [25, 25, 10, 1.25])
        XCTAssertTrue(result.isExactMatch)
        XCTAssertEqual(result.achievedTotal, 142.5, accuracy: 0.001)
    }

    func test_justTheBar_whenTargetEqualsBar() {
        let result = PlateCalculator.calculate(targetWeight: 20, barWeight: 20)
        XCTAssertTrue(result.platesPerSide.isEmpty)
        XCTAssertTrue(result.isExactMatch)
        XCTAssertEqual(result.achievedTotal, 20)
    }

    func test_targetLighterThanBar_returnsEmptyNotExact() {
        let result = PlateCalculator.calculate(targetWeight: 15, barWeight: 20)
        XCTAssertTrue(result.platesPerSide.isEmpty)
        XCTAssertFalse(result.isExactMatch)
        XCTAssertEqual(result.achievedTotal, 20)
    }

    func test_unachievableTarget_returnsClosestAchievable() {
        // 100.3kg target, 20kg bar -> 40.15 per side, not exactly reachable with 1.25 increments
        let result = PlateCalculator.calculate(targetWeight: 100.3, barWeight: 20)
        XCTAssertEqual(result.platesPerSide, [25, 15])
        XCTAssertEqual(result.achievedTotal, 100, accuracy: 0.001)
        XCTAssertFalse(result.isExactMatch)
    }

    func test_greedyAlgorithm_usesLargestPlatesFirst() {
        // 115kg target, 20kg bar -> 47.5 per side -> 25 + 20 + 2.5
        let result = PlateCalculator.calculate(targetWeight: 115, barWeight: 20)
        XCTAssertEqual(result.platesPerSide, [25, 20, 2.5])
        XCTAssertTrue(result.isExactMatch)
    }

    func test_customPlateSet() {
        let result = PlateCalculator.calculate(targetWeight: 60, barWeight: 20, availablePlates: [20, 10])
        XCTAssertEqual(result.platesPerSide, [20])
    }

    func test_zeroTarget_returnsEmpty() {
        let result = PlateCalculator.calculate(targetWeight: 0, barWeight: 20)
        XCTAssertTrue(result.platesPerSide.isEmpty)
    }
    
    func test_calculate_respectsInventoryLimit() {
        let result = PlateCalculator.calculate(
            targetWeight: 140, barWeight: 20,
            inventoryPerSide: [25: 1, 20: 4, 15: 4, 10: 4, 5: 4, 2.5: 4, 1.25: 4]
        )
        
        XCTAssertFalse(result.platesPerSide.filter { $0 == 25 }.count > 1)
        XCTAssertTrue(result.limitedByInventory || result.isExactMatch)
    }

    func test_calculate_unlimitedInventoryByDefault_matchesPreviousBehavior() {
        let result = PlateCalculator.calculate(targetWeight: 142.5, barWeight: 20)
        XCTAssertEqual(result.platesPerSide, [25, 25, 10, 1.25])
        XCTAssertFalse(result.limitedByInventory)
    }

    func test_calculate_flagsLimitedByInventoryWhenTargetUnreachable() {
        let result = PlateCalculator.calculate(
            targetWeight: 200, barWeight: 20,
            inventoryPerSide: [25: 1, 20: 1, 15: 0, 10: 0, 5: 0, 2.5: 0, 1.25: 0]
        )
        XCTAssertTrue(result.limitedByInventory)
        XCTAssertFalse(result.isExactMatch)
    }
    
    func test_calculate_doesNotFlagLimitedByInventoryWhenExactMatchStillAchieved() {
        // 25kg pair unavailable, but 20+15+... can still hit the exact target
        // via smaller plates -- this must NOT be flagged as inventory-limited.
        let result = PlateCalculator.calculate(
            targetWeight: 90, barWeight: 20,
            inventoryPerSide: [25: 0, 20: 4, 15: 4, 10: 4, 5: 4, 2.5: 4, 1.25: 4]
        )
        XCTAssertTrue(result.isExactMatch)
        XCTAssertFalse(result.limitedByInventory)
    }

    func test_calculate_flagsLimitedByInventoryOnlyWhenTargetTrulyUnreachable() {
        let result = PlateCalculator.calculate(
            targetWeight: 200, barWeight: 20,
            inventoryPerSide: [25: 1, 20: 1, 15: 0, 10: 0, 5: 0, 2.5: 0, 1.25: 0]
        )
        XCTAssertFalse(result.isExactMatch)
        XCTAssertTrue(result.limitedByInventory)
    }
    
    func test_eligibility_trueForMainLiftsAndOverheadPress() {
        XCTAssertTrue(PlateCalculatorEligibility.isEligible("Deadlift"))
        XCTAssertTrue(PlateCalculatorEligibility.isEligible("Bench Press"))
        XCTAssertTrue(PlateCalculatorEligibility.isEligible("Squat"))
        XCTAssertTrue(PlateCalculatorEligibility.isEligible("Overhead Press"))
    }

    func test_eligibility_falseForOtherExercises() {
        XCTAssertFalse(PlateCalculatorEligibility.isEligible("Dumbbell Bench Press"))
        XCTAssertFalse(PlateCalculatorEligibility.isEligible("Leg Press"))
        XCTAssertFalse(PlateCalculatorEligibility.isEligible("Assisted Pull-Up"))
    }

    func test_eligibility_falseForNilExerciseName() {
        XCTAssertFalse(PlateCalculatorEligibility.isEligible(nil))
    }
}
