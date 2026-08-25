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
    @State private var warmupSuggestionEntry: ExerciseEntry?
    @State private var isPairingMode = false
    @State private var isSavingWorkout = false
    @State private var selectedForPairing: Set<PersistentIdentifier> = []

    @StateObject private var restTimer = RestTimerManager()
    @AppStorage("restTimerDuration") private var restTimerDuration: Int = 90
    @FocusState private var nameFieldFocused: Bool
    
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled: Bool = false

    private struct SetEditorTarget: Identifiable {
        let id = UUID()
        let entry: ExerciseEntry
        let type: SetType
    }

    private var displayGroups: [[ExerciseEntry]] {
        var result: [[ExerciseEntry]] = []
        var seen: Set<PersistentIdentifier> = []

        for entry in workout.exercises {
            if seen.contains(entry.persistentModelID) { continue }
            if let groupID = entry.supersetGroupID {
                let partners = workout.exercises.filter { $0.supersetGroupID == groupID }
                result.append(partners)
                partners.forEach { seen.insert($0.persistentModelID) }
            } else {
                result.append([entry])
                seen.insert(entry.persistentModelID)
            }
        }
        return result
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

                ForEach(Array(displayGroups.enumerated()), id: \.offset) { _, group in
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
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isPairingMode {
                        Button(selectedForPairing.count == 2 ? "Confirm" : "Select 2") {
                            confirmPairing()
                        }
                        .disabled(selectedForPairing.count != 2)
                    } else if workout.exercises.count >= 2 {
                        Button {
                            isPairingMode = true
                        } label: {
                            Image(systemName: "link")
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if isPairingMode {
                        Button("Cancel") {
                            isPairingMode = false
                            selectedForPairing.removeAll()
                        }
                    } else {
                        Button("Discard") {
                            if workout.exercises.isEmpty {
                                restTimer.cancel()
                                dismiss()
                            } else {
                                showingDiscardConfirmation = true
                            }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveWorkout() }
                    }
                    .disabled(workout.exercises.isEmpty || isPairingMode || isSavingWorkout)
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
                            if shouldStartRestTimer(after: target.entry) {
                                restTimer.start(duration: pendingRestDuration ?? restTimerDuration)
                            }
                        }
                    },
                    prMetric: target.entry.exercise?.prMetric
                )
            }
            .sheet(item: $warmupSuggestionEntry) { entry in
                WarmupSuggestionView(entry: entry) { newSets in
                    for set in newSets {
                        entry.sets.append(set)
                    }
                }
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

    private func saveWorkout() async {
        guard !isSavingWorkout else { return }

        isSavingWorkout = true
        defer { isSavingWorkout = false }

        modelContext.insert(workout)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        restTimer.cancel()

        if healthSyncEnabled {
            let sets = workout.totalWorkingSets
            let volume = workout.totalVolume
            let start = workout.date
            let end = workout.date.addingTimeInterval(TimeInterval(sets * 180))

            do {
                try await HealthKitManager.shared.saveWorkout(start: start, end: end, workingSets: sets, totalVolumeKg: volume)
            } catch {
                print("Health sync failed: \(error.localizedDescription)")
            }
        }

        dismiss()
    }

    private func shouldStartRestTimer(after entry: ExerciseEntry) -> Bool {
        guard let groupID = entry.supersetGroupID else { return true }
        let partners = workout.exercises.filter { $0.supersetGroupID == groupID && $0.persistentModelID != entry.persistentModelID }
        guard let partner = partners.first else { return true }

        let entryWorkingCount = entry.workingSets.count
        let partnerWorkingCount = partner.workingSets.count
        return partnerWorkingCount >= entryWorkingCount
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

    @ViewBuilder
    private func exerciseSection(_ entry: ExerciseEntry) -> some View {
        Section {
            ForEach(entry.sortedSets) { set in
                SetRow(set: set)
            }
            .onDelete { offsets in
                deleteSets(from: entry, at: offsets)
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
                    unlinkSuperset(group)
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
                if isPairingMode && showPairCheckbox {
                    Button {
                        togglePairingSelection(entry)
                    } label: {
                        Image(systemName: selectedForPairing.contains(entry.persistentModelID) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                Text(entry.exercise?.name ?? "Unknown Exercise")
                Spacer()
                if !isPairingMode {
                    Button {
                        deleteExerciseEntry(entry)
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
            Button {
                warmupSuggestionEntry = entry
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .fixedSize()

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
        }
    }

    private func togglePairingSelection(_ entry: ExerciseEntry) {
        if selectedForPairing.contains(entry.persistentModelID) {
            selectedForPairing.remove(entry.persistentModelID)
        } else if selectedForPairing.count < 2 {
            selectedForPairing.insert(entry.persistentModelID)
        }
    }

    private func confirmPairing() {
        guard selectedForPairing.count == 2 else { return }
        let groupID = UUID()
        for entry in workout.exercises where selectedForPairing.contains(entry.persistentModelID) {
            entry.supersetGroupID = groupID
        }
        selectedForPairing.removeAll()
        isPairingMode = false
    }

    private func unlinkSuperset(_ group: [ExerciseEntry]) {
        for entry in group {
            entry.supersetGroupID = nil
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
