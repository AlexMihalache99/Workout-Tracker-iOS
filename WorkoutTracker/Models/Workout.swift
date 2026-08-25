//
//  Workout.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import Foundation
import SwiftData

@Model
final class Workout {
    var date: Date
    var name: String?
    var notes: String?

    @Relationship(deleteRule: .cascade)
    var exercises: [ExerciseEntry] = []

    init(date: Date = .now, name: String? = nil, notes: String? = nil) {
        self.date = date
        self.name = name
        self.notes = notes
    }

    // Workout-level summary, computed from exercises
    var totalWorkingSets: Int {
        exercises.reduce(0) { $0 + $1.workingSets.count }
    }

    var totalReps: Int {
        exercises.reduce(0) { $0 + $1.totalReps }
    }

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }
}
