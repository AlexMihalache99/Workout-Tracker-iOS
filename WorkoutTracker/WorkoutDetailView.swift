//
//  WorkoutDetailView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Total Sets", value: "\(workout.totalWorkingSets)")
                LabeledContent("Total Reps", value: "\(workout.totalReps)")
                LabeledContent("Total Volume", value: "\(Int(workout.totalVolume)) kg")
            }

            ForEach(workout.exercises) { entry in
                Section(entry.exercise?.name ?? "Unknown") {
                    ForEach(entry.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                        HStack {
                            Text(set.setType == .warmup ? "Warm-up" : "Set \(set.setNumber)")
                            Spacer()
                            Text("\(set.weight, specifier: "%.1f") kg × \(set.reps)")
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.name ?? workout.date.formatted(date: .abbreviated, time: .omitted))
    }
}
