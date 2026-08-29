//
//  NewWorkoutView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI
import UIKit
import SwiftData
import Combine

struct NewWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let workout: Workout
    @State private var session: WorkoutSession?

    init(workout: Workout) {
        self.workout = workout
    }

    var body: some View {
        Group {
            if let session {
                NewWorkoutFormView(workout: workout, session: session)
            } else {
                ProgressView()
                    .onAppear {
                        session = WorkoutSession(workout: workout, context: modelContext)
                    }
            }
        }
    }
}

private struct NewWorkoutFormView: View {
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    @ObservedObject var session: WorkoutSession

    @State private var showingExercisePicker = false
    @State private var setEditorTarget: SetEditorTarget?
    @State private var showingDiscardConfirmation = false
    @State private var pendingRestDuration: Int? = nil
    @State private var warmupSuggestionEntry: ExerciseEntry?
    @State private var saveErrorMessage: String?

    @StateObject private var restTimer = RestTimerManager()
    @AppStorage("restTimerDuration") private var restTimerDuration: Int = 90
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled: Bool = false
    @AppStorage("bodyweightKg") private var bodyweightKg: Double = 0

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
                    .accessibilityIdentifier("newWorkout.nameField")
                    DatePicker("Date", selection: Binding(
                        get: { workout.date },
                        set: { workout.date = $0 }
                    ), in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                }

                ForEach(Array(session.displayGroups.enumerated()), id: \.offset) { _, group in
                    if group.count == 2 {
                        supersetSection(group)
                    } else if let entry = group.first {
                        exerciseSection(entry)
                    }
                }

                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
                .accessibilityIdentifier("newWorkout.addExerciseButton")
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if session.isPairingMode {
                        Button(session.selectedForPairing.count == 2 ? "Confirm" : "Select 2") {
                            session.confirmPairing()
                        }
                        .disabled(session.selectedForPairing.count != 2)
                    } else if session.canEnterPairingMode {
                        Button {
                            session.isPairingMode = true
                        } label: {
                            Image(systemName: "link")
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if session.isPairingMode {
                        Button("Cancel") {
                            session.cancelPairing()
                        }
                    } else {
                        Button("Discard") {
                            if workout.exercises.isEmpty {
                                session.discard()
                                restTimer.cancel()
                                dismiss()
                            } else {
                                showingDiscardConfirmation = true
                            }
                        }
                        .accessibilityIdentifier("newWorkout.discardButton")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            guard let result = try session.save() else { return }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            restTimer.cancel()

                            if healthSyncEnabled {
                                Task {
                                    do {
                                        try await HealthKitManager.shared.saveWorkout(
                                            start: result.start, end: result.end,
                                            workingSets: result.sets, totalVolumeKg: result.volumeKg,
                                            bodyweightKg: bodyweightKg > 0 ? bodyweightKg : nil
                                        )
                                        HealthKitManager.shared.clearSyncError()
                                    } catch {
                                        HealthKitManager.shared.recordSyncError(error.localizedDescription)
                                    }
                                }
                            }
                            dismiss()
                        } catch {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            saveErrorMessage = error.localizedDescription
                        }
                    }
                    .disabled(!session.isReadyToSave)
                    .accessibilityIdentifier("newWorkout.saveButton")
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    session.addExercise(exercise)
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
                    prMetric: target.entry.exercise?.prMetric,
                    exerciseName: target.entry.exercise?.name
                ) { newSet in
                    session.addSet(newSet, to: target.entry)
                    if target.type == .working, session.shouldStartRestTimer(after: target.entry) {
                        restTimer.start(duration: pendingRestDuration ?? restTimerDuration)
                    }
                    pendingRestDuration = nil
                }
            }
            .sheet(item: $warmupSuggestionEntry) { entry in
                WarmupSuggestionView(entry: entry) { newSets in
                    session.addWarmupSets(newSets, to: entry)
                }
            }
            .overlay {
                if showingDiscardConfirmation {
                    DeleteConfirmationOverlay(
                        title: "Discard Workout?",
                        message: "You'll lose everything logged in this workout.",
                        confirmLabel: "Discard",
                        onDelete: {
                            session.discard()
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
            .alert("Save Failed", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK") { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
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

    @ViewBuilder
    private func exerciseSection(_ entry: ExerciseEntry) -> some View {
        Section {
            ForEach(entry.sortedSets) { set in
                SetRow(set: set)
            }
            .onDelete { offsets in
                session.deleteSets(from: entry, at: offsets)
            }
            setActionButtons(for: entry)
        } header: {
            exerciseHeader(entry, showPairCheckbox: true)
        }
    }

    @ViewBuilder
    private func supersetSection(_ group: [ExerciseEntry]) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text("SUPERSET")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.0)
                }
                .foregroundStyle(AppTheme.accent)

                Button("Unlink") {
                    session.unlinkSuperset(group)
                }
                .font(.caption2)
            }
            .padding(.vertical, 2)

            ForEach(group) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    exerciseHeader(entry, showPairCheckbox: false)
                    ForEach(entry.sortedSets) { set in
                        SetRow(set: set)
                    }
                    setActionButtons(for: entry)
                }
                .padding(.vertical, 4)
                if entry.persistentModelID != group.last?.persistentModelID {
                    Rectangle().fill(AppTheme.textSecondary.opacity(0.15)).frame(height: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseHeader(_ entry: ExerciseEntry, showPairCheckbox: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if session.isPairingMode && showPairCheckbox {
                    Button {
                        session.togglePairingSelection(entry)
                    } label: {
                        Image(systemName: session.selectedForPairing.contains(entry.persistentModelID) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                Text(entry.exercise?.name ?? "Unknown Exercise")
                Spacer()
                if !session.isPairingMode {
                    Button {
                        session.deleteExerciseEntry(entry)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(PlateColor.deadlift)
                            .font(.caption)
                    }
                }
            }
            if let lastLabel = entry.lastSessionLabel {
                Text("Last time: \(lastLabel)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(nil)
            }
            if let notes = entry.exercise?.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(PlateColor.squat)
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .textCase(nil)
                }
                .padding(.top, 2)
            }
        }
        .textCase(nil)
    }

    @ViewBuilder
    private func setActionButtons(for entry: ExerciseEntry) -> some View {
        HStack(spacing: 8) {
            
            if PlateCalculatorEligibility.isEligible(entry.exercise?.name) {
                Button {
                    warmupSuggestionEntry = entry
                } label: {
                    Image(systemName: "wand.and.stars")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .fixedSize()
                .accessibilityIdentifier("newWorkout.warmupSuggestButton.\(entry.persistentModelID)")
            }
            Button {
                setEditorTarget = SetEditorTarget(entry: entry, type: .warmup)
            } label: {
                Text("Warm-up")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .accessibilityIdentifier("newWorkout.warmupButton.\(entry.persistentModelID)")

            Menu {
                Button("90s rest") { pendingRestDuration = 90 }
                Button("2 min rest") { pendingRestDuration = 120 }
                Button("3 min rest") { pendingRestDuration = 180 }
                Button("5 min rest") { pendingRestDuration = 300 }
                Divider()
                Button("Use default (\(restTimerDuration)s)") { pendingRestDuration = nil }
            } label: {
                Text("Working Set")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            } primaryAction: {
                setEditorTarget = SetEditorTarget(entry: entry, type: .working)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityIdentifier("newWorkout.workingSetButton.\(entry.persistentModelID)")
        }
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
