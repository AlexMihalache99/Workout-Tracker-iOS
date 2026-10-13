//
//  ClaudeSummaryService.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 05/09/2026.
//

import Foundation

// MARK: - Result types

struct AISummary: Codable, Equatable {
    var headline: String
    var wins: [String]
    var watchouts: [String]
    var nextBlock: [String]

    enum CodingKeys: String, CodingKey { case headline, wins, watchouts, nextBlock }

    init(headline: String, wins: [String], watchouts: [String], nextBlock: [String]) {
        self.headline = headline
        self.wins = wins
        self.watchouts = watchouts
        self.nextBlock = nextBlock
    }

    // Tolerant decoding: a missing array becomes empty instead of failing the whole summary.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        headline = try c.decode(String.self, forKey: .headline)
        wins = try c.decodeIfPresent([String].self, forKey: .wins) ?? []
        watchouts = try c.decodeIfPresent([String].self, forKey: .watchouts) ?? []
        nextBlock = try c.decodeIfPresent([String].self, forKey: .nextBlock) ?? []
    }
}

struct AISummaryResult: Equatable {
    let summary: AISummary?   // nil if the model's reply wasn't valid JSON
    let rawText: String       // always kept, used as the fallback display
}

struct WorkoutNoteEntry: Equatable {
    let date: Date
    let workoutName: String?
    let text: String
}

enum ClaudeSummaryError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your Claude API key in Settings to generate AI summaries."
        case .invalidResponse: return "Received an unexpected response from Claude."
        case .emptyResponse(let detail): return "Claude's reply contained no text (\(detail))."
        case .apiError(let message): return "Claude API error: \(message)"
        }
    }
}

// MARK: - Service

enum ClaudeSummaryService {
    static let defaultModel = "claude-sonnet-5-5"

    static let systemPrompt = """
    You are an experienced strength and physique coach reviewing one lifter's training log.

    The lifter can already see every raw statistic and auto-generated insight in their app. \
    Do NOT restate numbers or repeat what a chart would show. Your job is interpretation: \
    explain why the numbers look the way they do, connect the data to the lifter's own workout \
    notes, separate real signals from expected patterns, and give concrete prescriptions.

    Rules:
    - Use only the data provided. Never invent numbers, exercises, or events.
    - Quote a number only when a point depends on it; at most 6 numbers in total.
    - If training-block context is provided, treat planned patterns as expected, not as problems. \
    In a planned 1RM testing week, lower volume with higher top-set intensity is normal; judge that \
    week by whether top singles / estimated 1RMs improved, not by volume.
    - An exercise logged at 0 kg external load is a bodyweight movement, not missing data.
    - Treat workout notes as the lifter's own account. Cite them when they explain a pattern \
    (injury, sleep, soreness, technique, motivation).
    - If the data cannot support a conclusion, say so briefly instead of guessing.
    - Tone: direct and specific, like a coach. No hype, no filler, no generic advice.

    Output ONLY a JSON object (no markdown, no code fences) with exactly these keys:
    "headline": one sentence, max 25 words, your verdict on the period.
    "wins": array of 2-3 strings, each max 30 words: what genuinely went well and why it matters.
    "watchouts": array of 0-3 strings, each max 30 words: real risks or open questions. Empty if none.
    "nextBlock": array of 2-4 strings, each max 30 words: concrete instructions for the next block \
    (name the exercise and direction; give magnitudes only where the data supports them).
    """

    // MARK: Prompt building (pure, no network)

    static func buildPrompt(
        report: WorkoutReport,
        phase: TrainingPhase,
        weightUnit: WeightUnit,
        block: TrainingBlockContext? = nil,
        notes: [WorkoutNoteEntry] = [],
        calendar: Calendar = .current
    ) -> (system: String, user: String) {
        let fullDate = DateFormatter()
        fullDate.locale = Locale(identifier: "en_US")
        fullDate.timeZone = calendar.timeZone
        fullDate.dateStyle = .medium

        let shortDate = DateFormatter()
        shortDate.locale = Locale(identifier: "en_US")
        shortDate.timeZone = calendar.timeZone
        shortDate.dateFormat = "MMM d"

        func weight(_ kg: Double) -> String {
            "\(String(format: "%.1f", weightUnit.fromKg(kg))) \(weightUnit.label)"
        }

        let focus: String
        switch phase {
        case .strength:
            focus = "STRENGTH. Judge the period by top-set weight, estimated 1RM, bodyweight ratios, and whether effort trends support peaking or call for a reset."
        case .bodybuilding:
            focus = "BODYBUILDING. Judge the period by volume progression, frequency and consistency, effort distribution across weeks, and whether weekly volume is building sustainably."
        }

        var lines: [String] = []
        lines.append("PERIOD: \(fullDate.string(from: report.startDate)) to \(fullDate.string(from: report.endDate))")
        lines.append("FOCUS: \(focus)")
        lines.append("")

        if let block, block.lengthWeeks > 0 {
            lines.append("TRAINING BLOCK CONTEXT (set by the lifter)")
            var blockLine = "- Blocks run \(block.lengthWeeks) weeks and repeat back-to-back."
            if block.testingWeek > 0 {
                blockLine += " Week \(block.testingWeek) of each block is a planned 1RM testing week: lower volume with a spike in top-set intensity is EXPECTED there."
            }
            lines.append(blockLine)
            let extra = block.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !extra.isEmpty {
                lines.append("- Lifter's own note on the block: \(extra)")
            }
            lines.append("")
        }

        lines.append("TOTALS")
        lines.append("- Workouts: \(report.totalWorkouts), sets: \(report.totalSets), reps: \(report.totalReps), volume: \(weight(report.totalVolume))")
        lines.append("")

        if !report.liftProgress.isEmpty {
            lines.append("LIFT PROGRESS (starting-period top set -> period best)")
            for lift in report.liftProgress {
                switch lift.metric {
                case .weight:
                    if lift.bodyweightOnly {
                        lines.append("- \(lift.exerciseName): logged at 0 kg external load (bodyweight movement; not missing data)")
                        break
                    }
                    if let start = lift.earliestWeight, let best = lift.bestWeight {
                        var line = "- \(lift.exerciseName): \(weight(start)) -> \(weight(best))"
                        if let oneRM = lift.estimatedOneRepMax { line += ", est. 1RM \(weight(oneRM))" }
                        if let ratio = lift.bodyweightRatio { line += ", \(String(format: "%.2f", ratio))x bodyweight" }
                        lines.append(line)
                    }
                    if lift.deloadSignal {
                        lines.append("  (effort rose 3 straight weeks without a weight increase)")
                    }
                case .reps:
                    if let start = lift.earliestReps, let best = lift.bestReps {
                        lines.append("- \(lift.exerciseName) (bodyweight reps): \(start) -> \(best)")
                    }
                    if lift.addedWeightSeen, let added = lift.maxAddedWeight {
                        lines.append("  (added external weight this period, up to \(weight(added)))")
                    }
                case .assisted:
                    if let start = lift.earliestEffectiveLoad, let best = lift.bestEffectiveLoad {
                        lines.append("- \(lift.exerciseName) (assisted, effective load): \(weight(start)) -> \(weight(best))")
                    }
                }
            }
            lines.append("")
        }

        if !report.weeklyStats.isEmpty {
            lines.append("WEEKLY BREAKDOWN")
            for week in report.weeklyStats.sorted(by: { $0.weekStart < $1.weekStart }) {
                var label = shortDate.string(from: week.weekStart)
                if let block, block.lengthWeeks > 0 {
                    let blockWeek = block.blockWeek(forWeekStarting: week.weekStart, calendar: calendar)
                    label += " [block week \(blockWeek)/\(block.lengthWeeks)"
                    if block.isTestingWeek(forWeekStarting: week.weekStart, calendar: calendar) {
                        label += " - PLANNED 1RM TESTING WEEK"
                    }
                    label += "]"
                }
                var line = "- Week of \(label): \(weight(week.totalVolume)) volume, \(week.workoutCount) workout(s)"
                if let effort = week.avgEffort {
                    line += ", avg effort \(String(format: "%.1f", effort))/10"
                }
                lines.append(line)
            }
            lines.append("")
        }

        if notes.isEmpty {
            lines.append("No workout notes were written during this period.")
        } else {
            lines.append("LIFTER'S WORKOUT NOTES (their own words, oldest first)")
            for note in notes {
                let title = note.workoutName.map { " \"\($0)\"" } ?? ""
                let text = note.text.replacingOccurrences(of: "\n", with: " ")
                lines.append("- \(shortDate.string(from: note.date))\(title): \(text)")
            }
        }
        lines.append("")
        lines.append("Write the JSON summary now.")

        return (systemPrompt, lines.joined(separator: "\n"))
    }

    // MARK: Notes

    /// Notes the lifter wrote on workouts inside the report period. Most recent `limit` kept.
    static func collectNotes(
        workouts: [Workout],
        start: Date,
        end: Date,
        calendar: Calendar = .current,
        limit: Int = 25,
        maxCharacters: Int = 300
    ) -> [WorkoutNoteEntry] {
        // A date-only picker gives midnight; include the whole selected end day.
        let normalizedEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end

        let entries = workouts
            .filter { $0.date >= start && $0.date <= normalizedEnd }
            .compactMap { workout -> WorkoutNoteEntry? in
                guard let raw = workout.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !raw.isEmpty else { return nil }
                return WorkoutNoteEntry(date: workout.date, workoutName: workout.name, text: String(raw.prefix(maxCharacters)))
            }
            .sorted { $0.date < $1.date }

        return Array(entries.suffix(limit))
    }

    // MARK: Parsing (pure)

    /// Pulls the reply text out of a Messages API response body. Collects every `text`
    /// block rather than assuming the first block is text, since models can emit other
    /// block types (e.g. thinking) before the answer. When there is no text at all, the
    /// error carries the stop_reason and block types so the cause is visible.
    static func extractText(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "non-UTF8 body"
            throw ClaudeSummaryError.emptyResponse("body wasn't a JSON object: \(snippet)")
        }

        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            let types = blocks.compactMap { $0["type"] as? String }
            let stopReason = json["stop_reason"] as? String ?? "unknown"
            let typeList = types.isEmpty ? "none" : types.joined(separator: ", ")
            throw ClaudeSummaryError.emptyResponse("stop_reason: \(stopReason), content blocks: \(typeList)")
        }
        return text
    }

    /// Accepts bare JSON, JSON in code fences, or JSON surrounded by prose.
    static func parseSummary(_ raw: String) -> AISummary? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = text.firstIndex(of: "{"), let close = text.lastIndex(of: "}"), open <= close {
            text = String(text[open...close])
        }
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AISummary.self, from: data)
    }

    // MARK: Network

    static func generateSummary(
        report: WorkoutReport,
        phase: TrainingPhase,
        weightUnit: WeightUnit,
        block: TrainingBlockContext?,
        notes: [WorkoutNoteEntry],
        apiKey: String,
        model: String = defaultModel
    ) async throws -> AISummaryResult {
        guard !apiKey.isEmpty else { throw ClaudeSummaryError.missingAPIKey }

        let prompt = buildPrompt(report: report, phase: phase, weightUnit: weightUnit, block: block, notes: notes)

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,   // headroom so any hidden reasoning can't starve the visible answer
            "system": prompt.system,
            "messages": [["role": "user", "content": prompt.user]]
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

        let text = try extractText(from: data)
        return AISummaryResult(summary: parseSummary(text), rawText: text)
    }
}
