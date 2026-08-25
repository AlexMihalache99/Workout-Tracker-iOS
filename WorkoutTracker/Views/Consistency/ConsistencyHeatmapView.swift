//
//  ConsistencyHeatmapView.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 24/08/2026.
//


import SwiftUI
import SwiftData

struct ConsistencyHeatmapView: View {
    @Query(sort: \Workout.date) private var allWorkouts: [Workout]

    private var stats: ConsistencyStats {
        ConsistencyCalculator.build(workouts: allWorkouts)
    }

    private var weekColumns: [[DayActivity]] {
        stride(from: 0, to: stats.days.count, by: 7).map {
            Array(stats.days[$0..<min($0 + 7, stats.days.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CONSISTENCY")
                    .font(.system(size: 12, weight: .bold)).tracking(1.2)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if stats.currentWeekStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(PlateColor.deadlift)
                            .font(.caption)
                        Text("\(stats.currentWeekStreak) wk streak")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(Array(weekColumns.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 3) {
                            ForEach(week) { day in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color(for: day.intensityLevel))
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 20) {
                statItem("Longest streak", "\(stats.longestWeekStreak) wk")
                statItem("Avg / week", String(format: "%.1f", stats.avgSessionsPerWeek))
            }
        }
        .cardStyle()
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 0: return AppTheme.textSecondary.opacity(0.12)
        case 1: return AppTheme.accent.opacity(0.3)
        case 2: return AppTheme.accent.opacity(0.55)
        case 3: return AppTheme.accent.opacity(0.8)
        default: return AppTheme.accent
        }
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
            Text(label).font(.caption2).foregroundStyle(AppTheme.textSecondary)
        }
    }
}