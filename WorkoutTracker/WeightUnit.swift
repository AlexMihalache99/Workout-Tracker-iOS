//
//  WeightUnit.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import Foundation

enum WeightUnit: String, CaseIterable {
    case kg
    case lb

    var label: String { self == .kg ? "kg" : "lb" }

    func fromKg(_ kg: Double) -> Double {
        self == .kg ? kg : kg * 2.20462
    }

    func toKg(_ value: Double) -> Double {
        self == .kg ? value : value / 2.20462
    }
}
