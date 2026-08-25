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
    @Environment(\.modelContext) private var modelContext
    var onPick: (Exercise) -> Void

    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var exactMatchExists: Bool {
        exercises.contains { $0.name.localizedCaseInsensitiveCompare(searchText) == .orderedSame }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                if !trimmedSearchText.isEmpty && !exactMatchExists {
                    Section {
                        Button {
                            addCustomExercise(name: trimmedSearchText)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                                Text("Add \"\(trimmedSearchText)\"")
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                        .listRowBackground(AppTheme.surface)
                    }
                }

                ForEach(filteredExercises) { exercise in
                    Button {
                        onPick(exercise)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(PlateColor.forExercise(exercise.name))
                                .frame(width: 10, height: 10)
                            Text(exercise.name)
                            Spacer()
                            if exercise.isMainLift {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                    .listRowBackground(AppTheme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search or add an exercise")
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if filteredExercises.isEmpty && trimmedSearchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private func addCustomExercise(name: String) {
        let newExercise = Exercise(name: name, category: "Custom", isMainLift: false)
        modelContext.insert(newExercise)
        try? modelContext.save()
        onPick(newExercise)
        dismiss()
    }
}
