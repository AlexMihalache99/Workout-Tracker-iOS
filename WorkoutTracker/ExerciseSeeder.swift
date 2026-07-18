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
        let existingExercises = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existingExercises.map(\.name))

        let defaults: [(String, String, Bool)] = [
            ("Deadlift", "Big 3", true),
            ("Bench Press", "Big 3", true),
            ("Squat", "Big 3", true),
            ("Assisted Chin-Up", "Accessory", false),
            ("Assisted Dip", "Accessory", false),
            ("Assisted Pull-Up", "Accessory", false),
            ("Band Lateral Walk", "Accessory", false),
            ("Band Pull-Apart", "Accessory", false),
            ("Barbell Curl", "Accessory", false),
            ("Barbell Floor Press", "Accessory", false),
            ("Barbell Skull Crusher", "Accessory", false),
            ("Bent Over Reverse Dumbbell Flye", "Accessory", false),
            ("Barbell Row", "Accessory", false),
            ("Bicycle Crunch", "Accessory", false),
            ("Block Pull", "Accessory", false),
            ("Bulgarian Split Squat", "Accessory", false),
            ("Chest-Supported Dumbbell Row", "Accessory", false),
            ("Chest-Supported T-Bar Row", "Accessory", false),
            ("Chin-Up", "Accessory", false),
            ("Close Grip Bench Press", "Accessory", false),
            ("Concentration Bicep Curl", "Accessory", false),
            ("Deficit Push-Up", "Accessory", false),
            ("Dumbbell Incline Press", "Accessory", false),
            ("Dumbbell Lateral Raise", "Accessory", false),
            ("Dumbbell Shrug", "Accessory", false),
            ("Eccentric Accentuated Pull-Up", "Accessory", false),
            ("EZ Bar Curl", "Accessory", false),
            ("Face Pull", "Accessory", false),
            ("Flat Back Barbell Bench Press", "Accessory", false),
            ("Floor Skull Crusher", "Accessory", false),
            ("Glute Ham Raise", "Accessory", false),
            ("Good Morning", "Accessory", false),
            ("Hammer Curl", "Accessory", false),
            ("Hanging Leg Raise", "Accessory", false),
            ("Helms Row", "Accessory", false),
            ("Hip Abduction", "Accessory", false),
            ("Hip Thrust", "Accessory", false),
            ("Incline Dumbbell Curl", "Accessory", false),
            ("Incline Shrug", "Accessory", false),
            ("Lat Pullover", "Accessory", false),
            ("Lean-Away Lateral Raise", "Accessory", false),
            ("Leg Curl", "Accessory", false),
            ("Leg Extension", "Accessory", false),
            ("Neutral Grip Pull-Up", "Accessory", false),
            ("Nordic Ham Curl", "Accessory", false),
            ("Overhead Press", "Accessory", false),
            ("Pause Barbell Bench Press", "Accessory", false),
            ("Pause Deadlift", "Accessory", false),
            ("Pause High-Bar Squat", "Accessory", false),
            ("Pec Flye", "Accessory", false),
            ("Pendlay Row", "Accessory", false),
            ("Seated Calf Raise", "Accessory", false),
            ("Single-Arm Lat Pulldown", "Accessory", false),
            ("Single-Arm Row", "Accessory", false),
            ("Snatch Grip Romanian Deadlift", "Accessory", false),
            ("Standing Calf Raise", "Accessory", false),
            ("Sumo Box Squat", "Accessory", false),
            ("Triceps Pressdown", "Accessory", false),
            ("Upright Row", "Accessory", false),
            ("V Sit-Up", "Accessory", false),
            ("Weighted Dip", "Accessory", false),
            ("Weighted Pull-Up", "Accessory", false)
        ]

        for (name, category, isMain) in defaults where !existingNames.contains(name) {
            context.insert(Exercise(name: name, category: category, isMainLift: isMain))
        }

        if context.hasChanges {
            try? context.save()
        }
    }
}
