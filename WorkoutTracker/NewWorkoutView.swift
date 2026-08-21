//
//  NewWorkoutView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI
import UIKit
import SwiftData

struct NewWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var workout: Workout

    @State private var showingExercisePicker = false
    @State private var setEditorTarget: SetEditorTarget?
    @State private var showingDiscardConfirmation = false
    @State private var pendingRestDuration: Int? = nil
    @StateObject private var restTimer = RestTimerManager()
    @AppStorage("restTimerDuration") private var restTimerDuration: Int = 90
    @FocusState private var nameFieldFocused: Bool

    private struct SetEditorTarget: Identifiable {
        let id = UUID()
        let entry: ExerciseEntry
        let type: SetType
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name (optional)", text: Binding(
                        get: { workout.name ?? "" },
                        set: { workout.name = $0.isEmpty ? nil : $0 }
                    ))
                    .focused($nameFieldFocused)
                    DatePicker("Date", selection: $workout.date, displayedComponents: [.date, .hourAndMinute])
                }

                ForEach(workout.exercises) { entry in
                    Section {
                        ForEach(entry.sortedSets) { set in
                            SetRow(set: set)
                        }
                        .onDelete { offsets in
                            deleteSets(from: entry, at: offsets)
                        }

                        HStack {
                            Button {
                                setEditorTarget = SetEditorTarget(entry: entry, type: .warmup)
                            } label: {
                                Label("Warm-up", systemImage: "flame")
                            }
                            .buttonStyle(.bordered)

                            Menu {
                                Button("90s rest") { pendingRestDuration = 90 }
                                Button("2 min rest") { pendingRestDuration = 120 }
                                Button("3 min rest") { pendingRestDuration = 180 }
                                Button("5 min rest") { pendingRestDuration = 300 }
                                Divider()
                                Button("Use default (\(restTimerDuration)s)") { pendingRestDuration = nil }
                            } label: {
                                Label("Working Set", systemImage: "plus.circle")
                            } primaryAction: {
                                setEditorTarget = SetEditorTarget(entry: entry, type: .working)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.exercise?.name ?? "Unknown Exercise")
                                Spacer()
                                Button {
                                    deleteExerciseEntry(entry)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(PlateColor.deadlift)
                                        .font(.caption)
                                }
                            }
                            if let lastLabel = entry.lastSessionLabel {
                                Text("Last time: \(lastLabel)")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .textCase(nil)
                            }
                        }
                    }
                }

                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        if workout.exercises.isEmpty {
                            restTimer.cancel()
                            dismiss()
                        } else {
                            showingDiscardConfirmation = true
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        modelContext.insert(workout)
                        try? modelContext.save()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        restTimer.cancel()
                        dismiss()
                    }
                    .disabled(workout.exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    let entry = ExerciseEntry(exercise: exercise)
                    entry.workout = workout
                    workout.exercises.append(entry)
                }
            }
            .sheet(item: $setEditorTarget, onDismiss: {
                nameFieldFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }) { target in
                let nextNumber = target.entry.sets.filter { $0.setType == target.type }.count + 1
                SetEditorView(
                    setType: target.type,
                    nextSetNumber: nextNumber,
                    onSave: { newSet in
                        newSet.exerciseEntry = target.entry
                        target.entry.sets.append(newSet)
                        if target.type == .working {
                            restTimer.start(duration: pendingRestDuration ?? restTimerDuration)
                        }
                    },
                    prMetric: target.entry.exercise?.prMetric
                )
            }
            .overlay {
                if showingDiscardConfirmation {
                    DeleteConfirmationOverlay(
                        title: "Discard Workout?",
                        message: "You'll lose everything logged in this workout.",
                        onDelete: {
                            if workout.modelContext != nil {
                                modelContext.delete(workout)
                            }
                            restTimer.cancel()
                            showingDiscardConfirmation = false
                            dismiss()
                        },
                        onCancel: {
                            showingDiscardConfirmation = false
                        }
                    )
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    nameFieldFocused = false
                }
            }
            .safeAreaInset(edge: .bottom) {
                if restTimer.isActive {
                    RestTimerBar(manager: restTimer)
                }
            }
            .animation(.easeInOut, value: restTimer.isActive)
            .onDisappear {
                restTimer.cancel()
            }
        }
    }

    private func deleteSets(from entry: ExerciseEntry, at offsets: IndexSet) {
        let sorted = entry.sortedSets
        for index in offsets {
            let setToDelete = sorted[index]
            if setToDelete.modelContext != nil {
                modelContext.delete(setToDelete)
            }
            entry.sets.removeAll { $0.persistentModelID == setToDelete.persistentModelID }
        }
    }

    private func deleteExerciseEntry(_ entry: ExerciseEntry) {
        if entry.modelContext != nil {
            modelContext.delete(entry)
        }
        workout.exercises.removeAll { $0.persistentModelID == entry.persistentModelID }
    }
}

private struct SetRow: View {
    let set: SetEntry

    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        HStack {
            Text(set.setType == .warmup ? "W" : "\(set.setNumber)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(set.setType == .warmup ? PlateColor.warmup : AppTheme.accent)
                .clipShape(Circle())

            Text("\(weightUnit.fromKg(set.weight), specifier: "%.1f") \(weightUnit.label) x \(set.reps)")

            Spacer()

            if let rpe = set.rpe {
                Text("RPE \(rpe, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let rir = set.rir {
                Text("RIR \(rir)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
