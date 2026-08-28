//
//  PlateCalculatorView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 24/08/2026.
//

import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("barWeightKg") private var barWeightKg: Double = 20
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    
    @AppStorage("plateInventoryEnabled") private var plateInventoryEnabled: Bool = false
    @AppStorage("plateInventory25") private var plateInventory25: Int = 4
    @AppStorage("plateInventory20") private var plateInventory20: Int = 4
    @AppStorage("plateInventory15") private var plateInventory15: Int = 4
    @AppStorage("plateInventory10") private var plateInventory10: Int = 4
    @AppStorage("plateInventory5") private var plateInventory5: Int = 4
    @AppStorage("plateInventory2_5") private var plateInventory2_5: Int = 4
    @AppStorage("plateInventory1_25") private var plateInventory1_25: Int = 4

    @State private var targetText: String
    @FocusState private var fieldFocused: Bool

    init(initialWeight: Double = 0) {
        _targetText = State(initialValue: initialWeight > 0 ? String(format: "%.1f", initialWeight) : "")
    }

    private var targetWeight: Double {
        Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var inventory: [Double: Int]? {
        guard plateInventoryEnabled else { return nil }
        return [
            25: plateInventory25, 20: plateInventory20, 15: plateInventory15,
            10: plateInventory10, 5: plateInventory5, 2.5: plateInventory2_5, 1.25: plateInventory1_25
        ]
    }

    private var breakdown: PlateBreakdown {
        PlateCalculator.calculate(
            targetWeight: weightUnit.toKg(targetWeight),
            barWeight: weightUnit.toKg(barWeightKg),
            inventoryPerSide: inventory
        )
    }

    private func plateColor(_ plateKg: Double) -> Color {
        switch plateKg {
        case 25: return PlateColor.deadlift
        case 20: return PlateColor.bench
        case 15: return PlateColor.squat
        case 10: return .green
        default: return AppTheme.textSecondary
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("TARGET WEIGHT")
                        .font(.system(size: 12, weight: .bold)).tracking(1.2)
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack {
                        TextField("0", text: $targetText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                            .focused($fieldFocused)
                            .frame(width: 160)
                        Text(weightUnit.label)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.top, 8)

                if targetWeight > 0 {
                    if targetWeight < weightUnit.fromKg(barWeightKg) {
                        Text("Target is lighter than the bar (\(String(format: "%.1f", barWeightKg)) \(weightUnit.label)).")
                            .font(.caption)
                            .foregroundStyle(PlateColor.deadlift)
                            .multilineTextAlignment(.center)
                    } else if breakdown.platesPerSide.isEmpty {
                        Text("Just the bar — \(String(format: "%.1f", weightUnit.fromKg(barWeightKg))) \(weightUnit.label)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        VStack(spacing: 14) {
                            // Visual bar representation
                            HStack(spacing: 3) {
                                Spacer()
                                ForEach(Array(breakdown.platesPerSide.reversed().enumerated()), id: \.offset) { _, plate in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(plateColor(plate))
                                        .frame(width: 14, height: plateHeight(plate))
                                }
                                Rectangle()
                                    .fill(AppTheme.textSecondary.opacity(0.4))
                                    .frame(width: 50, height: 8)
                                ForEach(Array(breakdown.platesPerSide.enumerated()), id: \.offset) { _, plate in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(plateColor(plate))
                                        .frame(width: 14, height: plateHeight(plate))
                                }
                                Spacer()
                            }
                            .frame(height: 90)

                            Text("Per side (bar not included):")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            Text(breakdown.platesPerSide.map { formatPlate($0) }.joined(separator: "  +  "))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)

                            if !breakdown.isExactMatch {
                                Text("Closest achievable: \(String(format: "%.2f", weightUnit.fromKg(breakdown.achievedTotal))) \(weightUnit.label)")
                                    .font(.caption)
                                    .foregroundStyle(PlateColor.squat)
                            }
                            
                            if breakdown.limitedByInventory {
                                Text("Limited by your plate inventory — you'd need more plates to reach this weight exactly.")
                                    .font(.caption)
                                    .foregroundStyle(PlateColor.squat)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(AppTheme.background)
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
        }
    }

    private func plateHeight(_ plateKg: Double) -> CGFloat {
        switch plateKg {
        case 25: return 90
        case 20: return 78
        case 15: return 66
        case 10: return 54
        case 5: return 44
        case 2.5: return 36
        default: return 30
        }
    }

    private func formatPlate(_ kg: Double) -> String {
        let converted = weightUnit.fromKg(kg)
        return String(format: "%.2f", converted).replacingOccurrences(of: ".00", with: "") + " " + weightUnit.label
    }
}
