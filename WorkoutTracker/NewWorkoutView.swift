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
                    Section(entry.exercise?.name ?? "Unknown Exercise") {
                        ForEach(entry.sortedSets) { set in
                            SetRow(set: set)
                        }

                        HStack {
                            Button {
                                setEditorTarget = SetEditorTarget(entry: entry, type: .warmup)
                            } label: {
                                Label("Warm-up", systemImage: "flame")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                setEditorTarget = SetEditorTarget(entry: entry, type: .working)
                            } label: {
                                Label("Working Set", systemImage: "plus.circle")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .onDelete(perform: deleteExercises)

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
                SetEditorView(setType: target.type, nextSetNumber: nextNumber) { newSet in
                    newSet.exerciseEntry = target.entry
                    target.entry.sets.append(newSet)
                }
            }
            .overlay {
                if showingDiscardConfirmation {
                    DeleteConfirmationOverlay(
                        title: "Discard Workout?",
                        message: "You'll lose everything logged in this workout.",
                        onDelete: {
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
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        workout.exercises.remove(atOffsets: offsets)
    }
}

private struct SetRow: View {
    let set: SetEntry

    var body: some View {
        HStack {
            Text(set.setType == .warmup ? "W" : "\(set.setNumber)")
                .font(.caption.bold())
                .foregroundStyle(set.setType == .warmup ? .orange : .primary)
                .frame(width: 24)

            Text("\(set.weight, specifier: "%.1f") kg × \(set.reps)")

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
}
