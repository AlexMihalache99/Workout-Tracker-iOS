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
    var editingSet: SetEntry? = nil
    var prMetric: PRMetric? = nil
    var exerciseName: String? = nil
    var onSave: (SetEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    @State private var weightText: String = "0"
    @State private var repsText: String = ""
    @State private var trackingMode: TrackingMode = .none
    @State private var rpeValue: Double = 8.0
    @State private var rirValue: Int = 2
    @State private var showingPlateCalculator = false
    @FocusState private var focusedField: Field?

    private enum Field { case weight, reps }
    enum TrackingMode: String, CaseIterable {
        case none = "None"
        case rpe = "RPE"
        case rir = "RIR"
    }

    private var weightValue: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }
    private var repsValue: Int? { Int(repsText) }

    private var isValid: Bool {
        guard let w = weightValue, let r = repsValue else { return false }
        return w >= 0 && r >= 1
    }

    private var validationMessage: String? {
        if weightText.isEmpty || repsText.isEmpty { return nil }
        if weightValue == nil || (weightValue ?? -1) < 0 { return "Weight can't be negative" }
        if repsValue == nil || (repsValue ?? 0) < 1 { return "Reps must be at least 1" }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Set Details") {
                    HStack {
                            Text(prMetric == .assisted ? "Assistance (\(weightUnit.label))" : "Weight (\(weightUnit.label))")
                            Spacer()
                            TextField("0", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .weight)
                                .accessibilityIdentifier("setEditor.weightField")
                        if PlateCalculatorEligibility.isEligible(exerciseName) {
                            Button {
                                showingPlateCalculator = true
                            } label: {
                                Image(systemName: "square.stack.3d.up")
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .reps)
                            .accessibilityIdentifier("setEditor.repsField")
                    }
                    if let message = validationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if setType == .working {
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
            }
            .navigationTitle(setType == .warmup ? "Warm-up Set" : "Working Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("setEditor.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingSet == nil ? "Add" : "Save") { save() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("setEditor.saveButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear {
                prefillIfEditing()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = nil
                }
            }
            .sheet(isPresented: $showingPlateCalculator) {
                PlateCalculatorView(initialWeight: weightValue ?? 0)
            }
        }
    }

    private func prefillIfEditing() {
        guard let set = editingSet else { return }
        weightText = String(format: "%.1f", weightUnit.fromKg(set.weight))
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
        guard let weight = weightValue, let reps = repsValue, isValid else { return }
        let weightInKg = weightUnit.toKg(weight)
        let effectiveTrackingMode = setType == .working ? trackingMode : .none

        if let existing = editingSet {
            existing.weight = weightInKg
            existing.reps = reps
            existing.rpe = effectiveTrackingMode == .rpe ? rpeValue : nil
            existing.rir = effectiveTrackingMode == .rir ? rirValue : nil
            onSave(existing)
        } else {
            let entry = SetEntry(
                setType: setType,
                setNumber: nextSetNumber,
                weight: weightInKg,
                reps: reps,
                rpe: effectiveTrackingMode == .rpe ? rpeValue : nil,
                rir: effectiveTrackingMode == .rir ? rirValue : nil
            )
            onSave(entry)
        }
        focusedField = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

}
