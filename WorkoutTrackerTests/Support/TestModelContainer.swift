//
//  TestModelContainer.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 25/08/2026.
//


import Foundation
import SwiftData
@testable import WorkoutTracker

enum TestModelContainer {
    static func make() -> ModelContainer {
        let schema = Schema([Workout.self, ExerciseEntry.self, SetEntry.self, Exercise.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}