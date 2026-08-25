//
//  WarmUpSuggester.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 24/08/2026.
//

import Foundation

struct SuggestedWarmupSet: Identifiable {
    let id = UUID()
    let weightKg: Double
    let reps: Int
    let label: String
}

enum WarmupSuggester {
    private static let steps: [(percent: Double, reps: Int, label: String)] = [
        (0.0, 8, "Bar"),
        (0.4, 5, "40%"),
        (0.6, 3, "60%"),
        (0.8, 2, "80%")
    ]

    static func suggest(targetWeightKg: Double, barWeightKg: Double) -> [SuggestedWarmupSet] {
        guard targetWeightKg > barWeightKg else { return [] }

        return steps.map { step in
            let raw = step.percent == 0 ? barWeightKg : targetWeightKg * step.percent
            let rounded = roundToNearestPlateIncrement(max(raw, barWeightKg))
            return SuggestedWarmupSet(weightKg: rounded, reps: step.reps, label: step.label)
        }
    }

    // Smallest standard plate is 1.25kg, so 2.5kg is the smallest real change per side
    private static func roundToNearestPlateIncrement(_ weight: Double) -> Double {
        (weight / 2.5).rounded() * 2.5
    }
}
