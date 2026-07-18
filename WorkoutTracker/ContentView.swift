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
        TabView {
            WorkoutListView()
                .tabItem { Label("Workouts", systemImage: "list.bullet.clipboard") }

            PRDashboardView()
                .tabItem { Label("PRs", systemImage: "chart.line.uptrend.xyaxis") }

            ExerciseListView(exercises: exercises)
                .tabItem { Label("Exercises", systemImage: "dumbbell") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            ExerciseSeeder.seedIfNeeded(context: modelContext)
        }
    }
}

private struct ExerciseListView: View {
    let exercises: [Exercise]

    var body: some View {
        NavigationStack {
            List(exercises) { exercise in
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(PlateColor.forExercise(exercise.name))
                            .frame(width: 10, height: 10)
                        Text(exercise.name)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        if exercise.isMainLift {
                            Text("PR tracked")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Exercises")
        }
    }
}
