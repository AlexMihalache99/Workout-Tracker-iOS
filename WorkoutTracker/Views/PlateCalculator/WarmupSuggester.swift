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

        var results: [SuggestedWarmupSet] = []
        var lastWeight: Double? = nil

        for step in steps {
            let raw = step.percent == 0 ? barWeightKg : targetWeightKg * step.percent
            var rounded = roundToNearestPlateIncrement(max(raw, barWeightKg))

            if let last = lastWeight, rounded <= last {
                rounded = last + 2.5
            }

            guard rounded < targetWeightKg else { continue }

            results.append(SuggestedWarmupSet(weightKg: rounded, reps: step.reps, label: step.label))
            lastWeight = rounded
        }

        return results
    }

    private static func roundToNearestPlateIncrement(_ weight: Double) -> Double {
        (weight / 2.5).rounded() * 2.5
    }
}
