//
//  SetEditor.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI

struct SetEditorView: View {
    let setType: SetType
    let nextSetNumber: Int
    var editingSet: SetEntry? = nil        // nil = adding new, non-nil = editing
    var onSave: (SetEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var trackingMode: TrackingMode = .none
    @State private var rpeValue: Double = 8.0
    @State private var rirValue: Int = 2

    enum TrackingMode: String, CaseIterable {
        case none = "None"
        case rpe = "RPE"
        case rir = "RIR"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Set Details") {
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Effort Tracking") {
                    Picker("Mode", selection: $trackingMode) {
                        ForEach(TrackingMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if trackingMode == .rpe {
                        Stepper(value: $rpeValue, in: 5...10, step: 0.5) {
                            Text("RPE: \(rpeValue, specifier: "%.1f")")
                        }
                    } else if trackingMode == .rir {
                        Stepper(value: $rirValue, in: 0...5) {
                            Text("RIR: \(rirValue)")
                        }
                    }
                }
            }
            .navigationTitle(setType == .warmup ? "Warm-up Set" : "Working Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingSet == nil ? "Add" : "Save") { save() }
                        .disabled(weightText.isEmpty || repsText.isEmpty)
                }
            }
            .onAppear { prefillIfEditing() }
        }
    }

    private func prefillIfEditing() {
        guard let set = editingSet else { return }
        weightText = String(set.weight)
        repsText = String(set.reps)
        if let rpe = set.rpe {
            trackingMode = .rpe
            rpeValue = rpe
        } else if let rir = set.rir {
            trackingMode = .rir
            rirValue = rir
        }
    }

    private func save() {
        guard let weight = Double(weightText), let reps = Int(repsText) else { return }

        if let existing = editingSet {
            // Mutate in place — SwiftData autosaves the change
            existing.weight = weight
            existing.reps = reps
            existing.rpe = trackingMode == .rpe ? rpeValue : nil
            existing.rir = trackingMode == .rir ? rirValue : nil
            onSave(existing)
        } else {
            let entry = SetEntry(
                setType: setType,
                setNumber: nextSetNumber,
                weight: weight,
                reps: reps,
                rpe: trackingMode == .rpe ? rpeValue : nil,
                rir: trackingMode == .rir ? rirValue : nil
            )
            onSave(entry)
        }
        dismiss()
    }
}
