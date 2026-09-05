//
//  ClaudeSummaryService.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 05/09/2026.
//

import Foundation

enum ClaudeSummaryError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Claude API key in Settings to generate AI summaries."
        case .invalidResponse:
            return "Received an unexpected response from Claude."
        case .apiError(let message):
            return "Claude API error: \(message)"
        }
    }
}

enum ClaudeSummaryService {
    static let defaultModel = "claude-sonnet-5"

    static func buildPrompt(report: WorkoutReport, phase: TrainingPhase, weightUnit: WeightUnit) -> String {
        var lines: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        lines.append("You are a knowledgeable strength coach reviewing a lifter's training data.")
        lines.append("Focus: \(phase.rawValue).")
        lines.append("Period: \(dateFormatter.string(from: report.startDate)) to \(dateFormatter.string(from: report.endDate)).")
        lines.append("")
        lines.append("SUMMARY STATS")
        lines.append("- Workouts: \(report.totalWorkouts)")
        lines.append("- Total sets: \(report.totalSets)")
        lines.append("- Total reps: \(report.totalReps)")
        lines.append("- Total training volume: \(String(format: "%.0f", weightUnit.fromKg(report.totalVolume))) \(weightUnit.label)")
        lines.append("")

        if !report.liftProgress.isEmpty {
            lines.append("LIFT PROGRESS")
            for lift in report.liftProgress {
                switch lift.metric {
                case .weight:
                    if let start = lift.earliestWeight, let end = lift.bestWeight {
                        lines.append("- \(lift.exerciseName): \(String(format: "%.1f", weightUnit.fromKg(start))) -> \(String(format: "%.1f", weightUnit.fromKg(end))) \(weightUnit.label)")
                    }
                    if let oneRM = lift.estimatedOneRepMax {
                        lines.append("  Estimated 1RM: \(String(format: "%.1f", weightUnit.fromKg(oneRM))) \(weightUnit.label)")
                    }
                    if let ratio = lift.bodyweightRatio {
                        lines.append("  Bodyweight ratio: \(String(format: "%.2f", ratio))x")
                    }
                    if lift.deloadSignal {
                        lines.append("  Note: effort has risen 3 straight weeks without a matching weight increase (possible deload signal).")
                    }
                case .reps:
                    if let start = lift.earliestReps, let end = lift.bestReps {
                        lines.append("- \(lift.exerciseName) (bodyweight reps): \(start) -> \(end)")
                    }
                    if lift.addedWeightSeen, let maxAdded = lift.maxAddedWeight {
                        lines.append("  Added external weight this period, up to \(String(format: "%.1f", weightUnit.fromKg(maxAdded))) \(weightUnit.label).")
                    }
                case .assisted:
                    if let start = lift.earliestEffectiveLoad, let end = lift.bestEffectiveLoad {
                        lines.append("- \(lift.exerciseName) (assisted, effective load): \(String(format: "%.1f", weightUnit.fromKg(start))) -> \(String(format: "%.1f", weightUnit.fromKg(end))) \(weightUnit.label)")
                    }
                }
            }
            lines.append("")
        }

        if !report.weeklyStats.isEmpty {
            lines.append("WEEKLY BREAKDOWN")
            for week in report.weeklyStats {
                var line = "- Week of \(dateFormatter.string(from: week.weekStart)): \(String(format: "%.0f", weightUnit.fromKg(week.totalVolume))) \(weightUnit.label) volume, \(week.workoutCount) workout(s)"
                if let effort = week.avgEffort {
                    line += ", avg effort \(String(format: "%.1f", effort))/10"
                }
                lines.append(line)
            }
            lines.append("")
        }

        let voice = phase == .strength ? "strength-focused" : "bodybuilding-focused"
        lines.append("Based only on this data, write a short (3-5 sentence) natural-language summary of how this training period went, in a \(voice) voice. Call out genuine progress, any stagnation or regression, and one concrete, specific suggestion for the next period. Do not invent numbers not shown above. Do not use markdown formatting.")

        return lines.joined(separator: "\n")
    }

    static func generateSummary(report: WorkoutReport, phase: TrainingPhase, weightUnit: WeightUnit, apiKey: String, model: String = defaultModel) async throws -> String {
        guard !apiKey.isEmpty else { throw ClaudeSummaryError.missingAPIKey }

        let prompt = buildPrompt(report: report, phase: phase, weightUnit: weightUnit)

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 400,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeSummaryError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
                ?? "HTTP \(httpResponse.statusCode)"
            throw ClaudeSummaryError.apiError(message)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw ClaudeSummaryError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
