//
//  SettingsView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("restTimerDuration") private var restTimerDuration: Int = 90

    private var weightUnit: Binding<WeightUnit> {
        Binding(
            get: { WeightUnit(rawValue: weightUnitRaw) ?? .kg },
            set: { weightUnitRaw = $0.rawValue }
        )
    }
    
    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs == 0 {
            return "\(minutes) min"
        }
        return "\(minutes)m \(secs)s"
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

                Section("Rest Timer") {
                    Stepper(value: $restTimerDuration, in: 30...300, step: 15) {
                        HStack {
                            Text("Default Duration")
                            Spacer()
                            Text(formattedDuration(restTimerDuration))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Starts automatically after logging a working set. Heavy compound lifts often need 3–5 min.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
