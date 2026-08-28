//
//  PlateCalculator.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 24/08/2026.
//

import Foundation

struct PlateBreakdown {
    let platesPerSide: [Double]
    let achievedTotal: Double
    let isExactMatch: Bool
    let limitedByInventory: Bool
}

enum PlateCalculator {
    static let standardPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    static func calculate(
        targetWeight: Double,
        barWeight: Double,
        availablePlates: [Double] = standardPlates,
        inventoryPerSide: [Double: Int]? = nil
    ) -> PlateBreakdown {
        let weightPerSide = (targetWeight - barWeight) / 2

        guard weightPerSide > 0 else {
            return PlateBreakdown(platesPerSide: [], achievedTotal: barWeight, isExactMatch: targetWeight == barWeight, limitedByInventory: false)
        }

        var remaining = weightPerSide
        var plates: [Double] = []
        var usedCount: [Double: Int] = [:]
        var limitedByInventory = false

        for plate in availablePlates.sorted(by: >) {
            let cap = inventoryPerSide?[plate]
            while remaining >= plate - 0.001 {
                if let cap, (usedCount[plate] ?? 0) >= cap {
                    limitedByInventory = true
                    break
                }
                plates.append(plate)
                usedCount[plate, default: 0] += 1
                remaining -= plate
            }
        }

        let achievedPerSide = plates.reduce(0, +)
        let achievedTotal = barWeight + (achievedPerSide * 2)

        return PlateBreakdown(
            platesPerSide: plates,
            achievedTotal: achievedTotal,
            isExactMatch: abs(achievedTotal - targetWeight) < 0.01,
            limitedByInventory: limitedByInventory
        )
    }
}
