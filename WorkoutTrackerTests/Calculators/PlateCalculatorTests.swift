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
}