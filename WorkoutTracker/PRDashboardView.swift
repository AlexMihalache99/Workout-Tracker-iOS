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
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        NavigationStack {
            List {
                if mainLifts.isEmpty {
                    ContentUnavailableView("No Main Lifts Found", systemImage: "chart.line.uptrend.xyaxis")
                } else {
                    ForEach(mainLifts) { lift in
                        Section {
                            LiftProgressCard(exercise: lift)
                        }
                    }
                }
            }
            .navigationTitle("Personal Records")
        }
    }
}

private struct LiftProgressCard: View {
    let exercise: Exercise

    @Query private var allEntries: [ExerciseEntry]
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    init(exercise: Exercise) {
        self.exercise = exercise
        let name = exercise.name
        _allEntries = Query(
            filter: #Predicate<ExerciseEntry> { $0.exercise?.name == name }
        )
    }

    // One data point per workout session: the heaviest working-set weight that day
    private struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
    }

    private var dataPoints: [DataPoint] {
        allEntries
            .compactMap { entry -> DataPoint? in
                guard let date = entry.workout?.date else { return nil }
                let sessionMax = entry.workingSets.map { $0.weight }.max()
                guard let sessionMax else { return nil }
                return DataPoint(date: date, maxWeight: sessionMax)
            }
            .sorted { $0.date < $1.date }
    }

    private var personalRecord: Double? {
        dataPoints.map { $0.maxWeight }.max()
    }

    private var lastSessionWeight: Double? {
        dataPoints.last?.maxWeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(exercise.name)
                        .font(.headline)
                    if let pr = personalRecord {
                        Text("\(weightUnit.fromKg(pr), specifier: "%.1f") \(weightUnit.label)")
                            .font(.system(size: 28, weight: .bold))
                    } else {
                        Text("No data yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let pr = personalRecord, let last = lastSessionWeight, dataPoints.count > 1 {
                    let isAtPR = last == pr
                    Image(systemName: isAtPR ? "flame.fill" : "arrow.up.right")
                        .foregroundStyle(isAtPR ? .orange : .green)
                        .font(.title2)
                }
            }

            if dataPoints.count >= 2 {
                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", weightUnit.fromKg(point.maxWeight))
                    )
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", weightUnit.fromKg(point.maxWeight))
                    )
                }
                .frame(height: 140)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else if dataPoints.count == 1 {
                Text("Log one more session to see a trend line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
