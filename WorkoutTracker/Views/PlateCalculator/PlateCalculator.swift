//
//  PlateCalculator.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 24/08/2026.
//

import Foundation

struct PlateBreakdown {
    let platesPerSide: [Double]   // largest to smallest, one entry per plate
    let achievedTotal: Double
    let isExactMatch: Bool
}

enum PlateCalculator {
    static let standardPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    static func calculate(targetWeight: Double, barWeight: Double, availablePlates: [Double] = standardPlates) -> PlateBreakdown {
        let weightPerSide = (targetWeight - barWeight) / 2

        guard weightPerSide > 0 else {
            return PlateBreakdown(platesPerSide: [], achievedTotal: barWeight, isExactMatch: targetWeight == barWeight)
        }

        var remaining = weightPerSide
        var plates: [Double] = []

        for plate in availablePlates.sorted(by: >) {
            while remaining >= plate - 0.001 {   // small epsilon for floating point safety
                plates.append(plate)
                remaining -= plate
            }
        }

        let achievedPerSide = plates.reduce(0, +)
        let achievedTotal = barWeight + (achievedPerSide * 2)

        return PlateBreakdown(
            platesPerSide: plates,
            achievedTotal: achievedTotal,
            isExactMatch: abs(achievedTotal - targetWeight) < 0.01
        )
    }
}
