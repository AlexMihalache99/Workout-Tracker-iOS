//
//  WorkoutTrackerApp.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 17/07/2026.
//

import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Workout.self,
            ExerciseEntry.self,
            SetEntry.self,
            Exercise.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
