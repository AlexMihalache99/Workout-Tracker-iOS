//
//  ReportView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 20/08/2026.
//

import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \Workout.date) private var allWorkouts: [Workout]
    @Query private var allExercises: [Exercise]
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("bodyweightKg") private var bodyweightKg: Double = 0
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    @State private var startDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: .now) ?? .now
    @State private var endDate: Date = .now
    @State private var phase: TrainingPhase = .strength
    @State private var report: WorkoutReport?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PERIOD")
                            .font(.system(size: 12, weight: .bold)).tracking(1.2)
                            .foregroundStyle(AppTheme.textSecondary)

                        DatePicker("Start", selection: $startDate, in: ...endDate, displayedComponents: .date)
                        DatePicker("End", selection: $endDate, in: startDate...Date.now, displayedComponents: .date)

                        Text("FOCUS")
                            .font(.system(size: 12, weight: .bold)).tracking(1.2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.top, 4)

                        Picker("Focus", selection: $phase) {
                            ForEach(TrainingPhase.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button {
                            report = ReportGenerator.generate(
                                workouts: allWorkouts,
                                allExercises: allExercises,
                                start: startDate,
                                end: endDate,
                                phase: phase,
                                bodyweightKg: bodyweightKg
                            )
                        } label: {
                            Text("Generate Report")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                    .cardStyle()

                    if let report {
                        ReportResultsView(report: report, weightUnit: weightUnit)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Report")
        }
    }
}

private struct ReportResultsView: View {
    let report: WorkoutReport
    let weightUnit: WeightUnit

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SUMMARY").font(.system(size: 12, weight: .bold)).tracking(1.2).foregroundStyle(AppTheme.textSecondary)
                HStack {
                    statBlock("Workouts", "\(report.totalWorkouts)")
                    statBlock("Sets", "\(report.totalSets)")
                    statBlock("Reps", "\(report.totalReps)")
                }
                statBlock("Total Volume", "\(Int(weightUnit.fromKg(report.totalVolume))) \(weightUnit.label)")
            }
            .cardStyle()
            .frame(maxWidth: .infinity, alignment: .leading)

            if !report.liftProgress.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("LIFT PROGRESS").font(.system(size: 12, weight: .bold)).tracking(1.2).foregroundStyle(AppTheme.textSecondary)
                    ForEach(report.liftProgress) { lift in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle().fill(PlateColor.forExercise(lift.exerciseName)).frame(width: 8, height: 8)
                                Text(lift.exerciseName).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                deltaBadge(for: lift)
                            }
                            progressLine(for: lift)
                            if let oneRM = lift.estimatedOneRepMax {
                                if let srcWeight = lift.estimatedOneRepMaxSourceWeight, let srcReps = lift.estimatedOneRepMaxSourceReps {
                                    Text("Est. 1RM: \(String(format: "%.1f", weightUnit.fromKg(oneRM))) \(weightUnit.label) (from \(String(format: "%.1f", weightUnit.fromKg(srcWeight))) \(weightUnit.label) × \(srcReps))")
                                        .font(.caption2).foregroundStyle(AppTheme.textSecondary)
                                } else {
                                    Text("Est. 1RM: \(String(format: "%.1f", weightUnit.fromKg(oneRM))) \(weightUnit.label)")
                                        .font(.caption2).foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            if let ratio = lift.bodyweightRatio {
                                Text("\(String(format: "%.2f", ratio))x bodyweight")
                                    .font(.caption2).foregroundStyle(AppTheme.textSecondary)
                            }
                            if lift.addedWeightSeen, let maxAdded = lift.maxAddedWeight {
                                Text("Added weight used, up to \(String(format: "%.1f", weightUnit.fromKg(maxAdded))) \(weightUnit.label)")
                                    .font(.caption2).foregroundStyle(AppTheme.textSecondary)
                            }
                            if lift.deloadSignal {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(PlateColor.deadlift)
                                    Text("Effort rising 3 weeks straight without a weight increase — consider a deload")
                                        .font(.caption2)
                                        .foregroundStyle(PlateColor.deadlift)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                        Rectangle().fill(AppTheme.textSecondary.opacity(0.15)).frame(height: 1)
                    }
                }
                .cardStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !report.weeklyStats.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("WEEKLY BREAKDOWN").font(.system(size: 12, weight: .bold)).tracking(1.2).foregroundStyle(AppTheme.textSecondary)
                    ForEach(report.weeklyStats) { week in
                        HStack {
                            Text(week.weekStart.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 13)).foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("\(Int(weightUnit.fromKg(week.totalVolume))) \(weightUnit.label)")
                                .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                            if let effort = week.avgEffort {
                                Text("RPE \(String(format: "%.1f", effort))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(effortColor(effort))
                            }
                        }
                    }
                }
                .cardStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !report.insights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("INSIGHTS").font(.system(size: 12, weight: .bold)).tracking(1.2).foregroundStyle(AppTheme.textSecondary)
                    ForEach(report.insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: insight.hasPrefix("⚠️") ? "exclamationmark.triangle.fill" : "sparkle")
                                .foregroundStyle(insight.hasPrefix("⚠️") ? PlateColor.deadlift : AppTheme.accent)
                                .font(.caption)
                            Text(insight.replacingOccurrences(of: "⚠️ ", with: ""))
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
                .cardStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func statBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
            Text(label).font(.caption2).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func effortColor(_ effort: Double) -> Color {
        if effort >= 8.5 { return PlateColor.deadlift }
        if effort >= 7 { return PlateColor.squat }
        return .green
    }

    @ViewBuilder
    private func deltaBadge(for lift: LiftProgress) -> some View {
        switch lift.metric {
        case .weight:
            if let delta = lift.weightDelta {
                Text("\(delta >= 0 ? "+" : "")\(String(format: "%.1f", weightUnit.fromKg(delta))) \(weightUnit.label)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(delta >= 0 ? .green : PlateColor.deadlift)
            }
        case .reps:
            if let delta = lift.repsDelta {
                Text("\(delta >= 0 ? "+" : "")\(delta) reps")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(delta >= 0 ? .green : PlateColor.deadlift)
            }
        case .assisted:
            if let delta = lift.effectiveLoadDelta {
                Text("\(delta >= 0 ? "+" : "")\(String(format: "%.1f", weightUnit.fromKg(delta))) \(weightUnit.label)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(delta >= 0 ? .green : PlateColor.deadlift)
            }
        }
    }

    @ViewBuilder
    private func progressLine(for lift: LiftProgress) -> some View {
        switch lift.metric {
        case .weight:
            if let start = lift.earliestWeight, let end = lift.bestWeight {
                Text("\(String(format: "%.1f", weightUnit.fromKg(start))) → \(String(format: "%.1f", weightUnit.fromKg(end))) \(weightUnit.label)")
                    .font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
        case .reps:
            if let start = lift.earliestReps, let end = lift.bestReps {
                Text("\(start) → \(end) reps (bodyweight)")
                    .font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
        case .assisted:
            if let start = lift.earliestEffectiveLoad, let end = lift.bestEffectiveLoad {
                Text("\(String(format: "%.1f", weightUnit.fromKg(start))) → \(String(format: "%.1f", weightUnit.fromKg(end))) \(weightUnit.label) effective load")
                    .font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
