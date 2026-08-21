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
        guard existingCount == 0 else { return }

        for (name, category, isMain, metric) in defaults {
            context.insert(Exercise(name: name, category: category, isMainLift: isMain, prMetric: metric))
        }
        try? context.save()
    }

    /// One-time migration for installs that already had exercises seeded before
    /// prMetric existed. Sets prMetric from isMainLift, and assigns .reps to
    /// known bodyweight movements by name. Runs once, guarded by a flag, so it
    /// never overwrites a tracking choice you make later via Exercise Detail.
    static func migratePRMetricIfNeeded(context: ModelContext) {
        let flagKey = "didMigratePRMetric"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let repsTrackedByDefault: Set<String> = ["Chin-Up", "Neutral Grip Pull-Up"]
        let weightTrackedAccessories: Set<String> = ["Weighted Pull-Up", "Weighted Dip"]

        for exercise in allExercises where exercise.prMetric == nil {
            if exercise.isMainLift {
                exercise.prMetric = .weight
            } else if repsTrackedByDefault.contains(exercise.name) {
                exercise.prMetric = .reps
            } else if weightTrackedAccessories.contains(exercise.name) {
                exercise.prMetric = .weight
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    private static let defaults: [(String, String, Bool, PRMetric?)] = [
        ("Deadlift", "Big 3", true, .weight),
        ("Bench Press", "Big 3", true, .weight),
        ("Squat", "Big 3", true, .weight),
        ("Assisted Chin-Up", "Accessory", false, nil),
        ("Assisted Dip", "Accessory", false, nil),
        ("Assisted Pull-Up", "Accessory", false, nil),
        ("Band Lateral Walk", "Accessory", false, nil),
        ("Band Pull-Apart", "Accessory", false, nil),
        ("Barbell Curl", "Accessory", false, nil),
        ("Barbell Floor Press", "Accessory", false, nil),
        ("Barbell Skull Crusher", "Accessory", false, nil),
        ("Bent Over Reverse Dumbbell Flye", "Accessory", false, nil),
        ("Barbell Row", "Accessory", false, nil),
        ("Bicycle Crunch", "Accessory", false, nil),
        ("Block Pull", "Accessory", false, nil),
        ("Bulgarian Split Squat", "Accessory", false, nil),
        ("Chest-Supported Dumbbell Row", "Accessory", false, nil),
        ("Chest-Supported T-Bar Row", "Accessory", false, nil),
        ("Chin-Up", "Accessory", false, .reps),
        ("Close Grip Bench Press", "Accessory", false, nil),
        ("Concentration Bicep Curl", "Accessory", false, nil),
        ("Deficit Push-Up", "Accessory", false, nil),
        ("Dumbbell Curl", "Accessory", false, nil),
        ("Dumbbell Incline Press", "Accessory", false, nil),
        ("Dumbbell Lateral Raise", "Accessory", false, nil),
        ("Dumbbell Shrug", "Accessory", false, nil),
        ("Dumbbell Skull Crusher", "Accessory", false, nil),
        ("Eccentric Accentuated Pull-Up", "Accessory", false, nil),
        ("EZ Bar Curl", "Accessory", false, nil),
        ("EZ Bar Skull Crusher", "Accessory", false, nil),
        ("Face Pull", "Accessory", false, nil),
        ("Flat Back Barbell Bench Press", "Accessory", false, nil),
        ("Floor Skull Crusher", "Accessory", false, nil),
        ("Glute Ham Raise", "Accessory", false, nil),
        ("Good Morning", "Accessory", false, nil),
        ("Hammer Curl", "Accessory", false, nil),
        ("Hanging Leg Raise", "Accessory", false, nil),
        ("Helms Row", "Accessory", false, nil),
        ("Hip Abduction", "Accessory", false, nil),
        ("Hip Thrust", "Accessory", false, nil),
        ("Incline Dumbbell Curl", "Accessory", false, nil),
        ("Incline Shrug", "Accessory", false, nil),
        ("Lat Pullover", "Accessory", false, nil),
        ("Lean-Away Lateral Raise", "Accessory", false, nil),
        ("Leg Curl", "Accessory", false, nil),
        ("Leg Extension", "Accessory", false, nil),
        ("Neutral Grip Pull-Up", "Accessory", false, .reps),
        ("Nordic Ham Curl", "Accessory", false, nil),
        ("Overhead Press", "Accessory", false, nil),
        ("Pause Barbell Bench Press", "Accessory", false, nil),
        ("Pause Deadlift", "Accessory", false, nil),
        ("Pause High-Bar Squat", "Accessory", false, nil),
        ("Pec Flye", "Accessory", false, nil),
        ("Pendlay Row", "Accessory", false, nil),
        ("Seated Calf Raise", "Accessory", false, nil),
        ("Single-Arm Lat Pulldown", "Accessory", false, nil),
        ("Single-Arm Row", "Accessory", false, nil),
        ("Snatch Grip Romanian Deadlift", "Accessory", false, nil),
        ("Standing Calf Raise", "Accessory", false, nil),
        ("Sumo Box Squat", "Accessory", false, nil),
        ("Triceps Pressdown", "Accessory", false, nil),
        ("Upright Row", "Accessory", false, nil),
        ("V Sit-Up", "Accessory", false, nil),
        ("Weighted Dip", "Accessory", false, .weight),
        ("Weighted Pull-Up", "Accessory", false, .weight),
        ("Ab Wheel Rollout", "Accessory", false, nil),
        ("Arnold Press", "Accessory", false, nil),
        ("Cable Crunch", "Accessory", false, nil),
        ("Cable Flye", "Accessory", false, nil),
        ("Cable Lateral Raise", "Accessory", false, nil),
        ("Dumbbell Bench Press", "Accessory", false, nil),
        ("Dumbbell Shoulder Press", "Accessory", false, nil),
        ("Front Squat", "Accessory", false, nil),
        ("Goblet Squat", "Accessory", false, nil),
        ("Hack Squat", "Accessory", false, nil),
        ("Incline Bench Press", "Accessory", false, nil),
        ("Lat Pulldown", "Accessory", false, nil),
        ("Leg Press", "Accessory", false, nil),
        ("Machine Chest Press", "Accessory", false, nil),
        ("Plank", "Accessory", false, nil),
        ("Preacher Curl", "Accessory", false, nil),
        ("Romanian Deadlift", "Accessory", false, nil),
        ("Seated Cable Row", "Accessory", false, nil),
        ("Walking Lunge", "Accessory", false, nil)
    ]
}
