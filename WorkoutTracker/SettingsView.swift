//
//  SettingsView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("restTimerDuration") private var restTimerDuration: Int = 90

    private var weightUnit: Binding<WeightUnit> {
        Binding(
            get: { WeightUnit(rawValue: weightUnitRaw) ?? .kg },
            set: { weightUnitRaw = $0.rawValue }
        )
    }

    // Export state
    @State private var exportDocument = BackupDocument(data: Data())
    @State private var showingExporter = false

    // Import state
    @State private var showingImportPicker = false
    @State private var pendingImportURL: URL?
    @State private var showingImportModeChoice = false

    // Feedback
    @State private var feedbackMessage: String?
    @State private var feedbackIsError = false

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

                Section("Backup") {
                    Button {
                        exportBackup()
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }

                    Text("Export before updating or reinstalling the app, then import afterward to restore your full workout history.")
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
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: defaultFilename()
            ) { result in
                switch result {
                case .success:
                    feedbackIsError = false
                    feedbackMessage = "Backup exported successfully."
                case .failure(let error):
                    feedbackIsError = true
                    feedbackMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    pendingImportURL = url
                    showingImportModeChoice = true
                case .failure(let error):
                    feedbackIsError = true
                    feedbackMessage = error.localizedDescription
                }
            }
            .confirmationDialog(
                "Import Backup",
                isPresented: $showingImportModeChoice,
                titleVisibility: .visible
            ) {
                Button("Replace All Data", role: .destructive) {
                    if let url = pendingImportURL {
                        performImport(url: url, mode: .replace)
                    }
                }
                Button("Merge with Existing Data") {
                    if let url = pendingImportURL {
                        performImport(url: url, mode: .merge)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingImportURL = nil
                }
            } message: {
                Text("Replace deletes everything currently in the app and restores exactly what's in the backup — use this after reinstalling. Merge adds the backup's workouts to what's already here.")
            }
            .alert(
                feedbackIsError ? "Error" : "Success",
                isPresented: Binding(
                    get: { feedbackMessage != nil },
                    set: { if !$0 { feedbackMessage = nil } }
                )
            ) {
                Button("OK") { feedbackMessage = nil }
            } message: {
                Text(feedbackMessage ?? "")
            }
        }
    }

    private func exportBackup() {
        do {
            let backup = try BackupManager.buildBackup(context: modelContext)
            let data = try BackupManager.encode(backup)
            exportDocument = BackupDocument(data: data)
            showingExporter = true
        } catch {
            feedbackIsError = true
            feedbackMessage = error.localizedDescription
        }
    }

    private func performImport(url: URL, mode: BackupManager.ImportMode) {
        guard url.startAccessingSecurityScopedResource() else {
            feedbackIsError = true
            feedbackMessage = BackupError.fileAccessDenied.localizedDescription
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let backup = try BackupManager.decode(data)
            try BackupManager.importBackup(backup, context: modelContext, mode: mode)
            feedbackIsError = false
            feedbackMessage = "Imported \(backup.workouts.count) workout\(backup.workouts.count == 1 ? "" : "s") from \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened))."
        } catch {
            feedbackIsError = true
            feedbackMessage = error.localizedDescription
        }
        pendingImportURL = nil
    }

    private func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "WorkoutTracker-Backup-\(formatter.string(from: .now))"
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return secs == 0 ? "\(minutes) min" : "\(minutes)m \(secs)s"
    }
}
