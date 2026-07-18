//
//  ExercisePickerView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    var onPick: (Exercise) -> Void

    var body: some View {
        NavigationStack {
            List(exercises) { exercise in
                Button {
                    onPick(exercise)
                    dismiss()
                } label: {
                    HStack {
                        Text(exercise.name)
                        Spacer()
                        if exercise.isMainLift {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .listRowBackground(AppTheme.surface)
        }
    }
}
