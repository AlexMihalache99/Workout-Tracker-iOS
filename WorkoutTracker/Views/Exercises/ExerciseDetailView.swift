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
    @AppStorage("bodyweightKg") private var bodyweightKg: Double = 0
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    
    @State private var notesText: String = ""
    @FocusState private var notesFieldFocused: Bool
    @Environment(\.modelContext) private var modelContext

    init(exercise: Exercise) {
        self.exercise = exercise
        let name = exercise.name
        _allEntries = Query(
            filter: #Predicate<ExerciseEntry> { $0.exercise?.name == name },
            sort: []
        )
    }
    
    private enum PRTrackingOption: String, CaseIterable, Identifiable {
        case none = "Not Tracked"
        case weight = "Weight"
        case reps = "Reps"
        case assisted = "Assisted"
        var id: String { rawValue }
    }

    private var sortedEntries: [ExerciseEntry] {
        allEntries.sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
    }

    private var personalRecordWeight: Double? {
        allEntries
            .flatMap { $0.workingSets }
            .map { $0.weight }
            .max()
    }

    private var personalRecordReps: Int? {
        allEntries
            .flatMap { $0.workingSets }
            .filter { $0.weight == 0 }
            .map { $0.reps }
            .max()
    }
    
    private var personalRecordAssistance: Double? {
        allEntries.flatMap { $0.workingSets }.map { $0.weight }.min()
    }

    private var personalRecordEffectiveLoad: Double? {
        guard bodyweightKg > 0, let minAssistance = personalRecordAssistance else { return nil }
        return max(bodyweightKg - minAssistance, 0)
    }

    var body: some View {
        List {
            
            Section("PR Tracking") {
                Picker("Track Progress By", selection: Binding<PRTrackingOption>(
                    get: {
                        switch exercise.prMetric {
                        case .weight: return .weight
                        case .reps: return .reps
                        case .assisted: return .assisted
                        case nil: return .none
                        }
                    },
                    set: { newValue in
                        switch newValue {
                        case .none: exercise.prMetric = nil
                        case .weight: exercise.prMetric = .weight
                        case .reps: exercise.prMetric = .reps
                        case .assisted: exercise.prMetric = .assisted
                        }
                        try? modelContext.save()
                    }
                )) {
                    ForEach(PRTrackingOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("exerciseDetail.prTrackingMenu")
            }
            
            Section("Form Cues & Notes") {
                TextField("e.g. Brace core, chest up, bar over midfoot...", text: $notesText, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($notesFieldFocused)
            }
            
            if exercise.prMetric == .weight, let pr = personalRecordWeight {
                Section("Personal Record") {
                    Text("\(weightUnit.fromKg(pr), specifier: "%.1f") \(weightUnit.label)")
                        .font(.title2.bold())
                }
            } else if exercise.prMetric == .reps, let pr = personalRecordReps {
                Section("Personal Record") {
                    Text("\(pr) reps")
                        .font(.title2.bold())
                    Text("At bodyweight (0 added)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if exercise.prMetric == .assisted {
                Section("Personal Record") {
                    if bodyweightKg <= 0 {
                        Text("Set your bodyweight in Settings to see this.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let effective = personalRecordEffectiveLoad, let assistance = personalRecordAssistance {
                        Text("\(weightUnit.fromKg(effective), specifier: "%.1f") \(weightUnit.label)")
                            .font(.title2.bold())
                        Text("Effective load (\(weightUnit.fromKg(assistance), specifier: "%.1f") \(weightUnit.label) assistance)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(sortedEntries) { entry in
                Section(entry.workout?.date.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date") {
                    ForEach(entry.sortedSets) { set in
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
        .onAppear {
            notesText = exercise.notes ?? ""
        }
        onChange(of: notesFieldFocused) { _, isFocused in
            if !isFocused {
                exercise.notes = notesText.isEmpty ? nil : notesText
                try? modelContext.save()
            }
        }
        .onDisappear {
            exercise.notes = notesText.isEmpty ? nil : notesText
            try? modelContext.save()
        }
    }
}
