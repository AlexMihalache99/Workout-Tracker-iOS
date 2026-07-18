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

    @State private var activeWorkout: Workout?

    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name ?? workout.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            Text("\(workout.totalWorkingSets) sets · \(workout.totalReps) reps · \(Int(workout.totalVolume)) kg volume")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(workouts[index]) }
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
        }
    }
}
