//
//  ContentView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 17/07/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]

    var body: some View {
        NavigationStack {
            List(exercises) { exercise in
                HStack {
                    Text(exercise.name)
                    Spacer()
                    if exercise.isMainLift {
                        Text("PR tracked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Exercises")
            .onAppear {
                ExerciseSeeder.seedIfNeeded(context: modelContext)
            }
        }
    }
}
