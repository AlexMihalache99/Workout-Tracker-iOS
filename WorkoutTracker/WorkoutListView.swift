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
    
    private func mainLiftsIn(_ workout: Workout) -> [String] {
        let names = workout.exercises.compactMap { $0.exercise?.name }
        return names.filter { ["Deadlift", "Bench Press", "Squat"].contains($0) }
    }
    
    private func repeatWorkout(_ source: Workout) {
        let newWorkout = Workout(date: .now, name: source.name)
        for entry in source.exercises {
            guard let exercise = entry.exercise else { continue }
            let newEntry = ExerciseEntry(exercise: exercise)
            newEntry.lastSessionLabel = lastSessionLabel(for: entry)
            newWorkout.exercises.append(newEntry)
        }
        activeWorkout = newWorkout
    }

    private func lastSessionLabel(for entry: ExerciseEntry) -> String? {
        guard let topSet = entry.workingSets.max(by: { $0.weight < $1.weight }) else { return nil }
        var label = "\(String(format: "%.1f", weightUnit.fromKg(topSet.weight))) \(weightUnit.label) × \(topSet.reps)"
        if let rpe = topSet.rpe {
            label += ", RPE \(String(format: "%.1f", rpe))"
        } else if let rir = topSet.rir {
            label += ", RIR \(rir)"
        }
        return label
    }

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
                        if !workouts.isEmpty {
                            Section {
                                ConsistencyHeatmapView()
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                        
                        ForEach(workouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        ForEach(mainLiftsIn(workout), id: \.self) { name in
                                            Circle()
                                                .fill(PlateColor.forExercise(name))
                                                .frame(width: 8, height: 8)
                                        }
                                        Text(workout.name ?? workout.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                    let vol = weightUnit.fromKg(workout.totalVolume)
                                    Text("\(workout.totalWorkingSets) sets · \(workout.totalReps) reps · \(Int(vol)) \(weightUnit.label) volume")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(AppTheme.surface)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    withAnimation { workoutPendingDelete = workout }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    repeatWorkout(workout)
                                } label: {
                                    Label("Repeat", systemImage: "arrow.clockwise")
                                }
                                .tint(AppTheme.accent)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeWorkout = Workout()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $activeWorkout) { workout in
                NewWorkoutView(workout: workout)
            }
            .overlay {
                if let workout = workoutPendingDelete {
                    DeleteConfirmationOverlay(
                        title: "Delete Workout?",
                        message: "This can't be undone.",
                        onDelete: {
                            modelContext.delete(workout)
                            withAnimation { workoutPendingDelete = nil }
                        },
                        onCancel: {
                            withAnimation { workoutPendingDelete = nil }
                        }
                    )
                }
            }
        }
    }
}
