//
//  WorkoutListView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    @State private var activeWorkout: Workout?
    @State private var workoutPendingDelete: Workout?

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Tap + to log your first workout.")
                    )
                } else {
                    List {
                        ForEach(workouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.name ?? workout.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.headline)
                                    let vol = weightUnit.fromKg(workout.totalVolume)
                                    Text("\(workout.totalWorkingSets) sets · \(workout.totalReps) reps · \(Int(vol)) \(weightUnit.label) volume")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    workoutPendingDelete = workout
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let workout = Workout()
                        modelContext.insert(workout)
                        activeWorkout = workout
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $activeWorkout) { workout in
                NewWorkoutView(workout: workout)
            }
            .confirmationDialog("Delete this workout?", isPresented: Binding(
                get: { workoutPendingDelete != nil },
                set: { if !$0 { workoutPendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let workout = workoutPendingDelete {
                        modelContext.delete(workout)
                    }
                    workoutPendingDelete = nil
                }
                Button("Cancel", role: .cancel) { workoutPendingDelete = nil }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}
