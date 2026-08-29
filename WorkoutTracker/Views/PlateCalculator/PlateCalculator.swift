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

enum PlateCalculatorEligibility {
    static let eligibleExerciseNames: Set<String> = [
        "Deadlift", "Bench Press", "Squat", "Overhead Press"
    ]

    static func isEligible(_ exerciseName: String?) -> Bool {
        guard let name = exerciseName else { return false }
        return eligibleExerciseNames.contains(name)
    }
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
        var hitInventoryCap = false

        for plate in availablePlates.sorted(by: >) {
            let cap = inventoryPerSide?[plate]
            while remaining >= plate - 0.001 {
                if let cap, (usedCount[plate] ?? 0) >= cap {
                    hitInventoryCap = true
                    break
                }
                plates.append(plate)
                usedCount[plate, default: 0] += 1
                remaining -= plate
            }
        }

        let achievedPerSide = plates.reduce(0, +)
        let achievedTotal = barWeight + (achievedPerSide * 2)
        let isExactMatch = abs(achievedTotal - targetWeight) < 0.01

        // Only report "limited by inventory" if the cap actually prevented
        // reaching the target -- not just skipped a plate size that turned out
        // to be unnecessary once smaller plates covered the exact amount.
        return PlateBreakdown(
            platesPerSide: plates,
            achievedTotal: achievedTotal,
            isExactMatch: isExactMatch,
            limitedByInventory: hitInventoryCap && !isExactMatch
        )
    }
}
