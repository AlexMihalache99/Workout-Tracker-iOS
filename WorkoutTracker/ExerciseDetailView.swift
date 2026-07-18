//
//  ExerciseDetailView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    let exercise: Exercise

    // Pull every ExerciseEntry for this exercise, across all workouts
    @Query private var allEntries: [ExerciseEntry]
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    init(exercise: Exercise) {
        self.exercise = exercise
        let name = exercise.name
        _allEntries = Query(
            filter: #Predicate<ExerciseEntry> { $0.exercise?.name == name },
            sort: []
        )
    }

    private var sortedEntries: [ExerciseEntry] {
        allEntries.sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
    }

    private var personalRecord: Double? {
        allEntries
            .flatMap { $0.workingSets }
            .map { $0.weight }
            .max()
    }

    var body: some View {
        List {
            if exercise.isMainLift, let pr = personalRecord {
                Section("Personal Record") {
                    Text("\(weightUnit.fromKg(pr), specifier: "%.1f") \(weightUnit.label)")
                        .font(.title2.bold())
                }
            }

            ForEach(sortedEntries) { entry in
                Section(entry.workout?.date.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date") {
                    ForEach(entry.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                        HStack {
                            Text(set.setType == .warmup ? "Warm-up" : "Set \(set.setNumber)")
                            Spacer()
                            Text("\(weightUnit.fromKg(set.weight), specifier: "%.1f") \(weightUnit.label) × \(set.reps)")
                        }
                    }
                }
            }

            if sortedEntries.isEmpty {
                ContentUnavailableView("No History Yet", systemImage: "clock", description: Text("Log this exercise in a workout to see history here."))
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .listRowBackground(AppTheme.surface)
    }
}
