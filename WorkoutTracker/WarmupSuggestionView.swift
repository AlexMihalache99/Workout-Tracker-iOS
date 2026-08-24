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
        let breakdown = PlateCalculator.calculate(targetWeight: weightKg, barWeight: barWeightKg)
        guard !breakdown.platesPerSide.isEmpty else { return "Just the bar" }
        let plates = breakdown.platesPerSide.map { plate -> String in
            let converted = weightUnit.fromKg(plate)
            let formatted = String(format: "%.2f", converted).replacingOccurrences(of: ".00", with: "")
            return formatted
        }
        return "Per side: " + plates.joined(separator: " + ") + " \(weightUnit.label)"
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