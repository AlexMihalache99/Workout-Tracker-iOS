//
//  TestFixtures.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 25/08/2026.
//


import Foundation
import SwiftData
@testable import WorkoutTracker

enum TestFixtures {
    @discardableResult
    static func makeExercise(
        context: ModelContext,
        name: String = "Deadlift",
        category: String = "Big 3",
        prMetric: PRMetric? = .weight
    ) -> Exercise {
        let exercise = Exercise(name: name, category: category, isMainLift: prMetric == .weight, prMetric: prMetric)
        context.insert(exercise)
        return exercise
    }

    @discardableResult
    static func makeWorkout(
        context: ModelContext,
        date: Date,
        name: String? = nil
    ) -> Workout {
        let workout = Workout(date: date, name: name)
        context.insert(workout)
        return workout
    }

    @discardableResult
    static func addExerciseEntry(
        context: ModelContext,
        workout: Workout,
        exercise: Exercise,
        sets: [(type: SetType, weight: Double, reps: Int, rpe: Double?, rir: Int?)]
    ) -> ExerciseEntry {
        let entry = ExerciseEntry(exercise: exercise)
        entry.workout = workout
        context.insert(entry)
        for (index, s) in sets.enumerated() {
            let set = SetEntry(setType: s.type, setNumber: index + 1, weight: s.weight, reps: s.reps, rpe: s.rpe, rir: s.rir)
            set.exerciseEntry = entry
            context.insert(set)
            entry.sets.append(set)
        }
        workout.exercises.append(entry)
        return entry
    }
}
