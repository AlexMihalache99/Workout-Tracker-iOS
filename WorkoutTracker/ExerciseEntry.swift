//
//  ExerciseEntry.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import Foundation
import SwiftData

@Model
final class ExerciseEntry {
    var exercise: Exercise?
    var workout: Workout?

    @Relationship(deleteRule: .cascade)
    var sets: [SetEntry] = []

    init(exercise: Exercise?) {
        self.exercise = exercise
    }

    // Convenience computed properties for summaries later
    var workingSets: [SetEntry] {
        sets.filter { $0.setType == .working }
    }

    var totalReps: Int {
        workingSets.reduce(0) { $0 + $1.reps }
    }

    var totalVolume: Double {
        workingSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    var averageRPE: Double? {
            let rpes = workingSets.compactMap { $0.rpe }
            guard !rpes.isEmpty else { return nil }
            return rpes.reduce(0, +) / Double(rpes.count)
    }
    
    var sortedSets: [SetEntry] {
        sets.sorted { lhs, rhs in
            if lhs.setType != rhs.setType {
                return lhs.setType == .warmup
            }
            return lhs.setNumber < rhs.setNumber
        }
    }
}
