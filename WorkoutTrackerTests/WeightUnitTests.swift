//
//  WeightUnitTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 26/08/2026.
//


import XCTest
@testable import WorkoutTracker

final class WeightUnitTests: XCTestCase {
    func test_kg_fromKg_isIdentity() {
        XCTAssertEqual(WeightUnit.kg.fromKg(100), 100, accuracy: 0.0001)
    }

    func test_kg_toKg_isIdentity() {
        XCTAssertEqual(WeightUnit.kg.toKg(100), 100, accuracy: 0.0001)
    }

    func test_lb_fromKg_conversion() {
        XCTAssertEqual(WeightUnit.lb.fromKg(100), 220.462, accuracy: 0.01)
    }

    func test_lb_toKg_conversion() {
        XCTAssertEqual(WeightUnit.lb.toKg(220.462), 100, accuracy: 0.01)
    }

    func test_roundTrip_kgToLbAndBack() {
        let original = 142.5
        let converted = WeightUnit.lb.fromKg(original)
        let back = WeightUnit.lb.toKg(converted)
        XCTAssertEqual(original, back, accuracy: 0.001)
    }

    func test_label_values() {
        XCTAssertEqual(WeightUnit.kg.label, "kg")
        XCTAssertEqual(WeightUnit.lb.label, "lb")
    }
}