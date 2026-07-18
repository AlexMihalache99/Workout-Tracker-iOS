//
//  PRDashboard.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI
import SwiftData
import Charts

struct PRDashboardView: View {
    @Query(filter: #Predicate<Exercise> { $0.isMainLift == true })
    private var mainLifts: [Exercise]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if mainLifts.isEmpty {
                        ContentUnavailableView("No Main Lifts Found", systemImage: "chart.line.uptrend.xyaxis")
                            .padding(.top, 60)
                    } else {
                        ForEach(mainLifts) { lift in
                            LiftProgressCard(exercise: lift)
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Personal Records")
        }
    }
}

private struct LiftProgressCard: View {
    let exercise: Exercise
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    @Query private var allEntries: [ExerciseEntry]

    init(exercise: Exercise) {
        self.exercise = exercise
        let name = exercise.name
        _allEntries = Query(filter: #Predicate<ExerciseEntry> { $0.exercise?.name == name })
    }

    private struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
    }

    private var plateColor: Color { PlateColor.forExercise(exercise.name) }

    private var dataPoints: [DataPoint] {
        allEntries
            .compactMap { entry -> DataPoint? in
                guard let date = entry.workout?.date,
                      let sessionMax = entry.workingSets.map({ $0.weight }).max() else { return nil }
                return DataPoint(date: date, maxWeight: sessionMax)
            }
            .sorted { $0.date < $1.date }
    }

    private var personalRecord: Double? { dataPoints.map { $0.maxWeight }.max() }
    private var lastSessionWeight: Double? { dataPoints.last?.maxWeight }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(plateColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.textSecondary)

                        if let pr = personalRecord {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(weightUnit.fromKg(pr), specifier: "%.1f")")
                                    .font(.heroNumber())
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text(weightUnit.label)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        } else {
                            Text("No data yet")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    Spacer()
                    if let pr = personalRecord, let last = lastSessionWeight, dataPoints.count > 1 {
                        Image(systemName: last == pr ? "flame.fill" : "arrow.up.right")
                            .foregroundStyle(last == pr ? plateColor : .green)
                            .font(.title3)
                    }
                }

                if dataPoints.count >= 2 {
                    Chart(dataPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", weightUnit.fromKg(point.maxWeight))
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(plateColor)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", weightUnit.fromKg(point.maxWeight))
                        )
                        .foregroundStyle(plateColor)
                    }
                    .frame(height: 120)
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine().foregroundStyle(AppTheme.textSecondary.opacity(0.2))
                            AxisValueLabel().foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { AxisValueLabel().foregroundStyle(AppTheme.textSecondary) }
                    }
                } else if dataPoints.count == 1 {
                    Text("Log one more session to see a trend line")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(16)
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
