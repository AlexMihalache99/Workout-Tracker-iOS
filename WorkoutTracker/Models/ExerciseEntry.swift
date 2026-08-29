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
    var supersetGroupID: UUID?
    var order: Int = 0 

    @Relationship(deleteRule: .cascade)
    var sets: [SetEntry] = []
    
    @Transient var lastSessionLabel: String?

    init(exercise: Exercise?) {
        self.exercise = exercise
    }

    var workingSets: [SetEntry] {
        sets.filter { $0.setType == .working }
    }

    var totalReps: Int {
        workingSets.reduce(0) { $0 + $1.reps }
    }

    var totalVolume: Double {
        workingSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    func totalTrainingVolume(bodyweightKg: Double) -> Double {
        guard let metric = exercise?.prMetric else { return totalVolume }

        switch metric {
        case .weight:
            return totalVolume
        case .reps:
            guard bodyweightKg > 0 else { return totalVolume }
            return workingSets.reduce(0) { partial, set in
                partial + ((bodyweightKg + set.weight) * Double(set.reps))
            }
        case .assisted:
            guard bodyweightKg > 0 else { return totalVolume }
            return workingSets.reduce(0) { partial, set in
                partial + (max(bodyweightKg - set.weight, 0) * Double(set.reps))
            }
        }
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
