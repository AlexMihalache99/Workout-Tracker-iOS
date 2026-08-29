//
//  WorkoutDetailView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var modelContext

    @State private var setEditorTarget: SetEditorTarget?
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("bodyweightKg") private var bodyweightKg: Double = 0
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    @State private var nameText: String = ""
    @State private var notesText: String = ""
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var notesFieldFocused: Bool

    private struct SetEditorTarget: Identifiable {
        let id = UUID()
        let entry: ExerciseEntry
        let set: SetEntry
    }

    var body: some View {
        List {
            Section("Name") {
                TextField("Workout name", text: $nameText)
                    .focused($nameFieldFocused)
                    .accessibilityIdentifier("workoutDetail.nameField")
            }

            Section("Summary") {
                LabeledContent("Date", value: workout.date.formatted(date: .abbreviated, time: .shortened))
                if let minutes = workout.durationMinutes {
                    LabeledContent("Duration", value: "\(minutes) min")
                }
                LabeledContent("Total Working Sets", value: "\(workout.totalWorkingSets)")
                LabeledContent("Total Reps", value: "\(workout.totalReps)")
                LabeledContent("Total Volume", value: "\(Int(workout.totalTrainingVolume(bodyweightKg: bodyweightKg))) kg")
            }

            Section("Notes") {
                TextField("Add notes...", text: $notesText, axis: .vertical)
                    .focused($notesFieldFocused)
            }

            ForEach(workout.sortedExercises) { entry in
                Section {
                    ForEach(entry.sortedSets) { set in
                        Button {
                            setEditorTarget = SetEditorTarget(entry: entry, set: set)
                        } label: {
                            SetDetailRow(setEntry: set, exerciseName: entry.exercise?.name, weightUnit: weightUnit)
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("workoutDetail.setRow.\(set.persistentModelID)")
                    }
                    .onDelete { offsets in
                        deleteSets(from: entry, at: offsets)
                    }
                } header: {
                    HStack {
                        Text(entry.exercise?.name ?? "Unknown")
                        Spacer()
                        if let avgRPE = entry.averageRPE {
                            Text("avg RPE \(avgRPE, specifier: "%.1f")")
                                .font(.caption)
                        }
                    }
                } footer: {
                    Text("\(entry.workingSets.count) working sets · \(entry.totalReps) reps · \(Int(entry.totalTrainingVolume(bodyweightKg: bodyweightKg))) kg volume")
                }
            }
        }
        .onAppear {
            nameText = workout.name ?? ""
            notesText = workout.notes ?? ""
        }
        .onChange(of: nameFieldFocused) { _, isFocused in
            if !isFocused {
                workout.name = nameText.isEmpty ? nil : nameText
                try? modelContext.save()
            }
        }
        .onChange(of: notesFieldFocused) { _, isFocused in
            if !isFocused {
                workout.notes = notesText.isEmpty ? nil : notesText
                try? modelContext.save()
            }
        }
        .onDisappear {
            workout.name = nameText.isEmpty ? nil : nameText
            workout.notes = notesText.isEmpty ? nil : notesText
            try? modelContext.save()
        }
        .navigationTitle(workout.name ?? workout.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $setEditorTarget) { target in
            SetEditorView(
                setType: target.set.setType,
                nextSetNumber: target.set.setNumber,
                editingSet: target.set,
                prMetric: target.entry.exercise?.prMetric,
                exerciseName: target.entry.exercise?.name,
                onSave: { _ in
                    try? modelContext.save()
                }
            )
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
    }

    private func deleteSets(from entry: ExerciseEntry, at offsets: IndexSet) {
        let sorted = entry.sortedSets
        for index in offsets {
            let setToDelete = sorted[index]
            modelContext.delete(setToDelete)
            entry.sets.removeAll { $0.persistentModelID == setToDelete.persistentModelID }
        }
        try? modelContext.save()
    }
}

private struct SetDetailRow: View {
    let setEntry: SetEntry
    let exerciseName: String?
    let weightUnit: WeightUnit

    private var badgeLabel: String {
        setEntry.setType == .warmup ? "W" : "\(setEntry.setNumber)"
    }

    private var badgeColor: Color {
        setEntry.setType == .warmup ? PlateColor.warmup : PlateColor.forExercise(exerciseName ?? "")
    }

    private var weightRepsText: String {
        let weight = weightUnit.fromKg(setEntry.weight)
        return String(format: "%.1f", weight) + " \(weightUnit.label) × \(setEntry.reps)"
    }

    var body: some View {
        HStack {
            Text(badgeLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(badgeColor)
                .clipShape(Circle())

            Text(weightRepsText)

            Spacer()

            if let rpe = setEntry.rpe {
                Text("RPE \(rpe, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let rir = setEntry.rir {
                Text("RIR \(rir)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
