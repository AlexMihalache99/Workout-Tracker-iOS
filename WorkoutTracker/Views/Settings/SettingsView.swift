//
//  SettingsView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import HealthKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("restTimerDuration") private var restTimerDuration: Int = 90
    @AppStorage("bodyweightKg") private var bodyweightKg: Double = 0
    @AppStorage("barWeightKg") private var barWeightKg: Double = 20
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled: Bool = false
    @ObservedObject private var healthManager = HealthKitManager.shared
    
    
    @AppStorage("plateInventoryEnabled") private var plateInventoryEnabled: Bool = false
    @AppStorage("plateInventory25") private var plateInventory25: Int = 4
    @AppStorage("plateInventory20") private var plateInventory20: Int = 4
    @AppStorage("plateInventory15") private var plateInventory15: Int = 4
    @AppStorage("plateInventory10") private var plateInventory10: Int = 4
    @AppStorage("plateInventory5") private var plateInventory5: Int = 4
    @AppStorage("plateInventory2_5") private var plateInventory2_5: Int = 4
    @AppStorage("plateInventory1_25") private var plateInventory1_25: Int = 4
    

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
    
    //Weight
    @FocusState private var bodyweightFieldFocused: Bool
    @FocusState private var barWeightFieldFocused: Bool
    
    //HealthKit
    @State private var isSyncingBodyweight = false
    @State private var healthSyncMessage: String?
    
    //ClaudeSDK
    @State private var claudeAPIKeyText: String = ""
    @FocusState private var apiKeyFieldFocused: Bool
    
    private var bodyweightBinding: Binding<Double> {
        Binding<Double>(
            get: {
                guard bodyweightKg > 0 else { return 0 }
                let unit = weightUnit.wrappedValue
                return unit.fromKg(bodyweightKg)
            },
            set: { newValue in
                let unit = weightUnit.wrappedValue
                bodyweightKg = unit.toKg(newValue)
            }
        )
    }
    
    private var bodyweightFormat: FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(1))
    }
    
    private var weightUnitOptions: some View {
        ForEach(WeightUnit.allCases, id: \.self) { unit in
            Text(unit.label.uppercased())
                .tag(unit)
        }
    }
    
    private var appleHealthSection: some View {
        Section("Apple Health") {
            healthSyncErrorView

            Toggle("Sync with Apple Health", isOn: $healthSyncEnabled)
                .onChange(of: healthSyncEnabled) { _, newValue in
                    handleHealthSyncToggle(newValue)
                }

            if healthSyncEnabled {
                Button {
                    Task {
                        await syncBodyweightFromHealth()
                    }
                } label: {
                    HStack {
                        Text("Sync Bodyweight from Health")
                        Spacer()

                        if isSyncingBodyweight {
                            ProgressView()
                        }
                    }
                }
                .disabled(isSyncingBodyweight)
            }

            Text("When enabled, completed workouts are logged to Health as strength training, and you can pull your latest bodyweight from Health.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func handleHealthSyncToggle(_ newValue: Bool) {
        guard newValue else {
            return
        }

        Task {
            do {
                try await HealthKitManager.shared.requestAuthorization()

                if HealthKitManager.shared.hasWorkoutWriteAuthorization {
                    feedbackIsError = false
                    feedbackMessage = "Health sync enabled."
                } else {
                    healthSyncEnabled = false
                    feedbackIsError = true
                    feedbackMessage = "Health permission wasn't granted for workouts. You can enable it in Settings → Privacy & Security → Health → WorkoutTracker."
                }
            } catch {
                healthSyncEnabled = false
                feedbackIsError = true
                feedbackMessage = "Couldn't request Health access: \(error.localizedDescription)"
            }
        }
    }
    
    private var healthSyncErrorView: some View {
        Group {
            if let error = healthManager.lastSyncErrorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(PlateColor.deadlift)
                            .font(.caption)

                        Text("Last Health sync failed: \(error)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Button("Dismiss") {
                        healthManager.clearSyncError()
                    }
                    .font(.caption)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight Unit", selection: weightUnit) {
                        weightUnitOptions
                    }
                    .pickerStyle(.segmented)

                    Text("Weights are always stored in kg internally, so switching units is safe and won't affect past data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Body Metrics") {
                    HStack {
                        Text("Current Bodyweight")
                        Spacer()
                        TextField("Not set", value: bodyweightBinding, format: bodyweightFormat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($bodyweightFieldFocused)
                            .accessibilityIdentifier("settings.bodyweightField")
                        Text(weightUnit.wrappedValue.label)
                            .foregroundStyle(.secondary)
                        
                    }
                    Text("Used to show your main lifts relative to bodyweight. Leave blank to skip this.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                
                Section("Plate Calculator") {
                    HStack {
                        Text("Bar Weight")
                        Spacer()
                        TextField("20", value: Binding(
                            get: { weightUnit.wrappedValue.fromKg(barWeightKg) },
                            set: { barWeightKg = weightUnit.wrappedValue.toKg($0) }
                        ), format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($barWeightFieldFocused)
                        Text(weightUnit.wrappedValue.label)
                            .foregroundStyle(.secondary)
                    }
                    Text("Standard Olympic bar is 20 kg (44 lb). Adjust if you train on a different bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Plate Inventory") {
                    Toggle("Limit to plates I actually own", isOn: $plateInventoryEnabled)
                    if plateInventoryEnabled {
                        Stepper("25 kg: \(plateInventory25) pairs", value: $plateInventory25, in: 0...20)
                        Stepper("20 kg: \(plateInventory20) pairs", value: $plateInventory20, in: 0...20)
                        Stepper("15 kg: \(plateInventory15) pairs", value: $plateInventory15, in: 0...20)
                        Stepper("10 kg: \(plateInventory10) pairs", value: $plateInventory10, in: 0...20)
                        Stepper("5 kg: \(plateInventory5) pairs", value: $plateInventory5, in: 0...20)
                        Stepper("2.5 kg: \(plateInventory2_5) pairs", value: $plateInventory2_5, in: 0...20)
                        Stepper("1.25 kg: \(plateInventory1_25) pairs", value: $plateInventory1_25, in: 0...20)
                        Text("The calculator will show what's actually achievable with what you own, instead of assuming unlimited plates.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("AI Report Summaries") {
                    SecureField("Claude API Key", text: $claudeAPIKeyText)
                        .focused($apiKeyFieldFocused)
                    Text("Stored in the device Keychain, not in this app's regular settings or backups. When you tap \"Generate AI Summary\" on the Report tab, the report's stats for that period are sent to Anthropic's API to write the summary text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onAppear {
                    claudeAPIKeyText = KeychainHelper.load() ?? ""
                }
                .onChange(of: apiKeyFieldFocused) { _, isFocused in
                    if !isFocused {
                        if claudeAPIKeyText.isEmpty {
                            KeychainHelper.delete()
                        } else {
                            KeychainHelper.save(claudeAPIKeyText)
                        }
                    }
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
                
                appleHealthSection
                
                Section("Backup") {
                    Button {
                        exportBackup()
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("settings.exportButton")

                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("settings.importButton")

                    Text("Export before updating or reinstalling the app, then import afterward to restore your full workout history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        bodyweightFieldFocused = false
                        barWeightFieldFocused = false
                        apiKeyFieldFocused = false
                    }
                }
            }
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
    
    private func syncBodyweightFromHealth() async {
        isSyncingBodyweight = true
        defer { isSyncingBodyweight = false }

        if let kg = await HealthKitManager.shared.fetchLatestBodyweightKg() {
            bodyweightKg = kg
            feedbackIsError = false
            feedbackMessage = "Bodyweight updated from Health."
        } else {
            feedbackIsError = true
            feedbackMessage = "No bodyweight data found in Health."
        }
    }
}
