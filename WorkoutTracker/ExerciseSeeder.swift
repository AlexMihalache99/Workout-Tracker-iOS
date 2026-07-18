//
//  ExerciseSeeder.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import Foundation
import SwiftData

struct ExerciseSeeder {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }   // already seeded

        let defaults: [(String, String, Bool)] = [
            ("Deadlift", "Big 3", true),
            ("Bench Press", "Big 3", true),
            ("Squat", "Big 3", true),
            ("Overhead Press", "Accessory", false),
            ("Barbell Row", "Accessory", false),
            ("Pull-Up", "Accessory", false)
        ]

        for (name, category, isMain) in defaults {
            context.insert(Exercise(name: name, category: category, isMainLift: isMain))
        }

        try? context.save()
    }
}
