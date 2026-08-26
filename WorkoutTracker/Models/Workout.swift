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
    var sessionStartTime: Date?
    var sessionEndTime: Date?

    @Relationship(deleteRule: .cascade)
    var exercises: [ExerciseEntry] = []

    init(date: Date = .now, name: String? = nil, notes: String? = nil) {
        self.date = date
        self.name = name
        self.notes = notes
    }

    var totalWorkingSets: Int {
        exercises.reduce(0) { $0 + $1.workingSets.count }
    }

    var totalReps: Int {
        exercises.reduce(0) { $0 + $1.totalReps }
    }

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }

    var durationMinutes: Int? {
        guard let start = sessionStartTime, let end = sessionEndTime else { return nil }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        return max(minutes, 0)
    }
}
