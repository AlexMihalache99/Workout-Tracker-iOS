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
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    private struct SetEditorTarget: Identifiable {
        let id = UUID()
        let entry: ExerciseEntry
        let set: SetEntry
    }

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Date", value: workout.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Total Working Sets", value: "\(workout.totalWorkingSets)")
                LabeledContent("Total Reps", value: "\(workout.totalReps)")
                LabeledContent("Total Volume", value: "\(Int(weightUnit.fromKg(workout.totalVolume))) \(weightUnit.label)")
            }

            Section("Notes") {
                TextField("Add notes...", text: Binding(
                    get: { workout.notes ?? "" },
                    set: { workout.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
            }

            ForEach(workout.exercises) { entry in
                Section {
                    ForEach(entry.sortedSets) { set in
                        Button {
                            setEditorTarget = SetEditorTarget(entry: entry, set: set)
                        } label: {
                            HStack {
                                Text(set.setType == .warmup ? "W" : "\(set.setNumber)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(set.setType == .warmup ? PlateColor.warmup : PlateColor.forExercise(entry.exercise?.name ?? ""))
                                    .clipShape(Circle())
                                Text("\(weightUnit.fromKg(set.weight), specifier: "%.1f") \(weightUnit.label) × \(set.reps)")
                                Spacer()
                                if let rpe = set.rpe {
                                    Text("RPE \(rpe, specifier: "%.1f")")
                                        .font(.caption).foregroundStyle(.secondary)
                                } else if let rir = set.rir {
                                    Text("RIR \(rir)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
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
                    Text("\(entry.workingSets.count) working sets · \(entry.totalReps) reps · \(Int(weightUnit.fromKg(entry.totalVolume))) \(weightUnit.label) volume")
                }
            }
        }
        .navigationTitle(workout.name ?? workout.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $setEditorTarget) { target in
            SetEditorView(setType: target.set.setType, nextSetNumber: target.set.setNumber, editingSet: target.set) { _ in }
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
    }
}
