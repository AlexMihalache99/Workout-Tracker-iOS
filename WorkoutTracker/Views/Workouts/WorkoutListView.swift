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
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    @State private var activeWorkout: Workout?
    @State private var workoutPendingDelete: Workout?
    @State private var searchText = ""
    @State private var filterExercise: Exercise?

    private var filteredWorkouts: [Workout] {
        var result = workouts

        if let filterExercise {
            result = result.filter { workout in
                workout.exercises.contains { $0.exercise?.name == filterExercise.name }
            }
        }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result = result.filter { workout in
                let nameMatch = workout.name?.localizedCaseInsensitiveContains(trimmed) ?? false
                let dateMatch = workout.date.formatted(date: .abbreviated, time: .omitted)
                    .localizedCaseInsensitiveContains(trimmed)
                return nameMatch || dateMatch
            }
        }

        return result
    }

    // Only exercises actually used in at least one workout — no point filtering by unused ones
    private var filterableExercises: [Exercise] {
        let usedNames = Set(workouts.flatMap { $0.exercises.compactMap { $0.exercise?.name } })
        return allExercises.filter { usedNames.contains($0.name) }
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
                } else if filteredWorkouts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        Section {
                            ConsistencyHeatmapView()
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }

                        if let filterExercise {
                            Section {
                                HStack {
                                    Circle().fill(PlateColor.forExercise(filterExercise.name)).frame(width: 8, height: 8)
                                    Text("Filtered: \(filterExercise.name)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Spacer()
                                    Button {
                                        self.filterExercise = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        ForEach(filteredWorkouts) { workout in
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
                            .accessibilityIdentifier("workoutList.row.\(workout.persistentModelID)")
                            .listRowBackground(AppTheme.surface)
                            .swipeActions(edge: .leading) {
                                Button {
                                    repeatWorkout(workout)
                                } label: {
                                    Label("Repeat", systemImage: "arrow.clockwise")
                                }
                                .tint(AppTheme.accent)
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    withAnimation { workoutPendingDelete = workout }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search by name or date")
            .accessibilityIdentifier("workoutList.searchField")
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            filterExercise = nil
                        } label: {
                            Label("All Exercises", systemImage: filterExercise == nil ? "checkmark" : "")
                        }
                        Divider()
                        ForEach(filterableExercises) { exercise in
                            Button {
                                filterExercise = exercise
                            } label: {
                                Label(exercise.name, systemImage: filterExercise?.name == exercise.name ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: filterExercise == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .disabled(filterableExercises.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeWorkout = Workout()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("workoutList.newWorkoutButton")
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
}
