//
//  WarmupSuggestionView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 24/08/2026.
//


import SwiftUI

struct WarmupSuggestionView: View {
    let entry: ExerciseEntry
    var onAdd: ([SetEntry]) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("barWeightKg") private var barWeightKg: Double = 20
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    @State private var targetText: String
    @FocusState private var fieldFocused: Bool
    
    @AppStorage("plateInventoryEnabled") private var plateInventoryEnabled: Bool = false
    @AppStorage("plateInventory25") private var plateInventory25: Int = 4
    @AppStorage("plateInventory20") private var plateInventory20: Int = 4
    @AppStorage("plateInventory15") private var plateInventory15: Int = 4
    @AppStorage("plateInventory10") private var plateInventory10: Int = 4
    @AppStorage("plateInventory5") private var plateInventory5: Int = 4
    @AppStorage("plateInventory2_5") private var plateInventory2_5: Int = 4
    @AppStorage("plateInventory1_25") private var plateInventory1_25: Int = 4

    private var inventory: [Double: Int]? {
        guard plateInventoryEnabled else { return nil }
        return [
            25: plateInventory25, 20: plateInventory20, 15: plateInventory15,
            10: plateInventory10, 5: plateInventory5, 2.5: plateInventory2_5, 1.25: plateInventory1_25
        ]
    }

    init(entry: ExerciseEntry, onAdd: @escaping ([SetEntry]) -> Void) {
        self.entry = entry
        self.onAdd = onAdd
        let existingTop = entry.workingSets.max(by: { $0.weight < $1.weight })?.weight
        let unit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
        _targetText = State(initialValue: existingTop.map { String(format: "%.1f", unit.fromKg($0)) } ?? "")
    }

    private var targetWeightKg: Double {
        weightUnit.toKg(Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    private var suggestions: [SuggestedWarmupSet] {
        WarmupSuggester.suggest(targetWeightKg: targetWeightKg, barWeightKg: barWeightKg)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Working Weight Today") {
                    HStack {
                        TextField("0", text: $targetText)
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                        Text(weightUnit.label).foregroundStyle(.secondary)
                    }
                }

                if targetWeightKg > 0 {
                    if suggestions.isEmpty {
                        Text("Target needs to be heavier than the bar (\(String(format: "%.1f", weightUnit.fromKg(barWeightKg))) \(weightUnit.label)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Section("Suggested Ramp") {
                            ForEach(suggestions) { set in
                                HStack {
                                    Text(set.label)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .frame(width: 44, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(weightUnit.fromKg(set.weightKg), specifier: "%.1f") \(weightUnit.label) × \(set.reps)")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(plateBreakdownText(for: set.weightKg))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Suggest Warm-ups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add All") { addAll() }
                        .disabled(suggestions.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
        }
    }

    private func plateBreakdownText(for weightKg: Double) -> String {
        let breakdown = PlateCalculator.calculate(targetWeight: weightKg, barWeight: barWeightKg, inventoryPerSide: inventory)
        guard !breakdown.platesPerSide.isEmpty else { return "Just the bar" }
        let plates = breakdown.platesPerSide.map { plate -> String in
            let converted = weightUnit.fromKg(plate)
            return String(format: "%.2f", converted).replacingOccurrences(of: ".00", with: "")
        }
        var text = "Per side: " + plates.joined(separator: " + ") + " \(weightUnit.label)"
        if breakdown.limitedByInventory {
            text += " (limited by your plate inventory)"
        }
        return text
    }

    private func addAll() {
        let existingWarmupCount = entry.sets.filter { $0.setType == .warmup }.count
        var newSets: [SetEntry] = []
        for (index, suggestion) in suggestions.enumerated() {
            let set = SetEntry(
                setType: .warmup,
                setNumber: existingWarmupCount + index + 1,
                weight: suggestion.weightKg,
                reps: suggestion.reps
            )
            set.exerciseEntry = entry
            newSets.append(set)
        }
        onAdd(newSets)
        dismiss()
    }
}
