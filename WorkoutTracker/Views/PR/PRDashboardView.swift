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
    @Query private var allExercises: [Exercise]

    private var trackedExercises: [Exercise] {
        allExercises.filter { $0.prMetric != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if trackedExercises.isEmpty {
                        ContentUnavailableView(
                            "No Tracked Exercises",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Turn on PR tracking for an exercise from its detail screen.")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(sortedExercises) { exercise in
                            if exercise.prMetric == .weight {
                                WeightProgressCard(exercise: exercise)
                            } else if exercise.prMetric == .reps {
                                RepsProgressCard(exercise: exercise)
                            } else if exercise.prMetric == .assisted {
                                AssistedProgressCard(exercise: exercise)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Personal Records")
        }
    }

    private var sortedExercises: [Exercise] {
        trackedExercises.sorted { lhs, rhs in
            if lhs.category != rhs.category {
                return lhs.category == "Big 3"
            }
            return lhs.name < rhs.name
        }
    }
}

private struct WeightProgressCard: View {
    let exercise: Exercise
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("bodyweightKg") private var bodyweightKg: Double = 0
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

    private var bodyweightRatio: String? {
        guard bodyweightKg > 0, let pr = personalRecord else { return nil }
        return String(format: "%.2fx bodyweight", pr / bodyweightKg)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(plateColor).frame(width: 5)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.textSecondary)

                        if let pr = personalRecord {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(weightUnit.fromKg(pr), specifier: "%.1f")")
                                    .font(.heroNumber())
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(weightUnit.label)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            if let ratio = bodyweightRatio {
                                Text(ratio)
                                    .font(.system(size: 12, weight: .medium))
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
                        LineMark(x: .value("Date", point.date), y: .value("Weight", weightUnit.fromKg(point.maxWeight)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(plateColor)
                        PointMark(x: .value("Date", point.date), y: .value("Weight", weightUnit.fromKg(point.maxWeight)))
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


private struct RepsProgressCard: View {
    let exercise: Exercise

    @Query private var allEntries: [ExerciseEntry]

    init(exercise: Exercise) {
        self.exercise = exercise
        let name = exercise.name
        _allEntries = Query(filter: #Predicate<ExerciseEntry> { $0.exercise?.name == name })
    }

    private struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxReps: Int
    }

    private var plateColor: Color { PlateColor.forExercise(exercise.name) }

    // Only bodyweight (0kg) sets count toward the reps PR
    private var dataPoints: [DataPoint] {
        allEntries
            .compactMap { entry -> DataPoint? in
                guard let date = entry.workout?.date else { return nil }
                let bodyweightSets = entry.workingSets.filter { $0.weight == 0 }
                guard let sessionMax = bodyweightSets.map({ $0.reps }).max() else { return nil }
                return DataPoint(date: date, maxReps: sessionMax)
            }
            .sorted { $0.date < $1.date }
    }

    private var personalRecord: Int? { dataPoints.map { $0.maxReps }.max() }
    private var lastSessionReps: Int? { dataPoints.last?.maxReps }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(plateColor).frame(width: 5)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.textSecondary)

                        if let pr = personalRecord {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(pr)")
                                    .font(.heroNumber())
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("reps")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Text("at bodyweight")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            Text("No bodyweight sets yet")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    Spacer()
                    if let pr = personalRecord, let last = lastSessionReps, dataPoints.count > 1 {
                        Image(systemName: last == pr ? "flame.fill" : "arrow.up.right")
                            .foregroundStyle(last == pr ? plateColor : .green)
                            .font(.title3)
                    }
                }

                if dataPoints.count >= 2 {
                    Chart(dataPoints) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Reps", point.maxReps))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(plateColor)
                        PointMark(x: .value("Date", point.date), y: .value("Reps", point.maxReps))
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
                    Text("Log one more bodyweight session to see a trend line")
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

private struct AssistedProgressCard: View {
    let exercise: Exercise
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("bodyweightKg") private var bodyweightKg: Double = 0
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
        let effectiveLoad: Double
    }

    private var plateColor: Color { PlateColor.forExercise(exercise.name) }

    // Least assistance in a session = highest effective load = best session
    private var dataPoints: [DataPoint] {
        guard bodyweightKg > 0 else { return [] }
        return allEntries
            .compactMap { entry -> DataPoint? in
                guard let date = entry.workout?.date,
                      let minAssistance = entry.workingSets.map({ $0.weight }).min() else { return nil }
                return DataPoint(date: date, effectiveLoad: bodyweightKg - minAssistance)
            }
            .sorted { $0.date < $1.date }
    }

    private var personalRecord: Double? { dataPoints.map { $0.effectiveLoad }.max() }
    private var lastSessionLoad: Double? { dataPoints.last?.effectiveLoad }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(plateColor).frame(width: 5)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.textSecondary)

                        if bodyweightKg <= 0 {
                            Text("Set bodyweight in Settings")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        } else if let pr = personalRecord {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(weightUnit.fromKg(pr), specifier: "%.1f")")
                                    .font(.heroNumber())
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(weightUnit.label)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Text("effective load moved")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            Text("No data yet")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    Spacer()
                    if let pr = personalRecord, let last = lastSessionLoad, dataPoints.count > 1 {
                        Image(systemName: last == pr ? "flame.fill" : "arrow.up.right")
                            .foregroundStyle(last == pr ? plateColor : .green)
                            .font(.title3)
                    }
                }

                if dataPoints.count >= 2 {
                    Chart(dataPoints) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Load", weightUnit.fromKg(point.effectiveLoad)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(plateColor)
                        PointMark(x: .value("Date", point.date), y: .value("Load", weightUnit.fromKg(point.effectiveLoad)))
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
