//
//  SettingsView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue

    private var weightUnit: Binding<WeightUnit> {
        Binding(
            get: { WeightUnit(rawValue: weightUnitRaw) ?? .kg },
            set: { weightUnitRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight Unit", selection: weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.label.uppercased()).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Text("Weights are always stored in kg internally, so switching units is safe and won't affect past data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
