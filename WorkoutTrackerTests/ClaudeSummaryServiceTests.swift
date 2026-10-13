//
//  ClaudeSummaryServiceTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 05/09/2026.
//

import XCTest
@testable import WorkoutTracker

final class ClaudeSummaryServiceTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2   // Monday
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func makeReport(
        phase: TrainingPhase = .strength,
        weeks: [WeeklyStat] = [],
        lifts: [LiftProgress] = []
    ) -> WorkoutReport {
        WorkoutReport(
            startDate: date(2026, 7, 6), endDate: date(2026, 8, 30), phase: phase,
            totalWorkouts: 10, totalSets: 80, totalReps: 400, totalVolume: 50_000,
            weeklyStats: weeks, liftProgress: lifts,
            lowestEffortWeek: nil, highestEffortWeek: nil, insights: []
        )
    }

    private func block() -> TrainingBlockContext {
        // Monday Jun 1 2026 starts week 1; Aug 3 is block week 10.
        TrainingBlockContext(startDate: date(2026, 6, 1), lengthWeeks: 10, testingWeek: 10, notes: "")
    }

    // MARK: - Prompt

    func test_userPrompt_usesFocusForPhase() {
        let strength = ClaudeSummaryService.buildPrompt(report: makeReport(), phase: .strength, weightUnit: .kg, calendar: calendar)
        let bodybuilding = ClaudeSummaryService.buildPrompt(report: makeReport(phase: .bodybuilding), phase: .bodybuilding, weightUnit: .kg, calendar: calendar)

        XCTAssertTrue(strength.user.contains("FOCUS: STRENGTH"))
        XCTAssertTrue(bodybuilding.user.contains("FOCUS: BODYBUILDING"))
    }

    func test_systemPrompt_demandsJSONAndForbidsRestatingStats() {
        let prompt = ClaudeSummaryService.buildPrompt(report: makeReport(), phase: .strength, weightUnit: .kg, calendar: calendar)

        XCTAssertTrue(prompt.system.contains("\"headline\""))
        XCTAssertTrue(prompt.system.contains("\"nextBlock\""))
        XCTAssertTrue(prompt.system.contains("Do NOT restate numbers"))
    }

    func test_weeklyBreakdown_marksOnlyTheTestingWeek() {
        let weeks = [
            WeeklyStat(weekStart: date(2026, 8, 3), totalVolume: 9_000, workoutCount: 3, avgEffort: 9.5),
            WeeklyStat(weekStart: date(2026, 8, 10), totalVolume: 14_000, workoutCount: 4, avgEffort: 7.0)
        ]
        let prompt = ClaudeSummaryService.buildPrompt(
            report: makeReport(weeks: weeks), phase: .strength, weightUnit: .kg,
            block: block(), calendar: calendar
        )
        let lines = prompt.user.components(separatedBy: "\n")

        let testingLine = lines.first { $0.contains("Week of Aug 3") }
        let nextLine = lines.first { $0.contains("Week of Aug 10") }
        XCTAssertTrue(testingLine?.contains("PLANNED 1RM TESTING WEEK") ?? false)
        XCTAssertTrue(testingLine?.contains("block week 10/10") ?? false)
        XCTAssertFalse(nextLine?.contains("TESTING") ?? true)
        XCTAssertTrue(nextLine?.contains("block week 1/10") ?? false)
    }

    func test_noBlockContext_omitsBlockSection() {
        let prompt = ClaudeSummaryService.buildPrompt(report: makeReport(), phase: .strength, weightUnit: .kg, calendar: calendar)
        XCTAssertFalse(prompt.user.contains("TRAINING BLOCK CONTEXT"))
    }

    func test_notes_areIncludedOrExplicitlyReportedAbsent() {
        let withNotes = ClaudeSummaryService.buildPrompt(
            report: makeReport(), phase: .strength, weightUnit: .kg,
            notes: [WorkoutNoteEntry(date: date(2026, 8, 12), workoutName: "Pull Day", text: "Slept badly,\nlower back tight")],
            calendar: calendar
        )
        XCTAssertTrue(withNotes.user.contains("Pull Day"))
        XCTAssertTrue(withNotes.user.contains("Slept badly, lower back tight"))   // newline collapsed

        let without = ClaudeSummaryService.buildPrompt(report: makeReport(), phase: .strength, weightUnit: .kg, calendar: calendar)
        XCTAssertTrue(without.user.contains("No workout notes were written"))
    }

    func test_bodyweightOnlyLift_isFlaggedNotReportedAsMissing() {
        var dip = LiftProgress(exerciseName: "Weighted Dip", metric: .weight)
        dip.bodyweightOnly = true
        let prompt = ClaudeSummaryService.buildPrompt(report: makeReport(lifts: [dip]), phase: .strength, weightUnit: .kg, calendar: calendar)

        XCTAssertTrue(prompt.user.contains("Weighted Dip: logged at 0 kg external load"))
    }

    // MARK: - Notes collection

    func test_collectNotes_filtersByPeriodIncludingEndDate_andSkipsEmpty() {
        let inside = Workout(date: date(2026, 8, 30, hour: 18), name: "Last Day", notes: "  felt strong  ")
        let before = Workout(date: date(2026, 7, 1), name: "Early", notes: "too early")
        let blank = Workout(date: date(2026, 8, 1), name: "Blank", notes: "   ")
        let none = Workout(date: date(2026, 8, 2), name: "None", notes: nil)

        let notes = ClaudeSummaryService.collectNotes(
            workouts: [inside, before, blank, none],
            start: date(2026, 7, 6), end: date(2026, 8, 30), calendar: calendar
        )

        XCTAssertEqual(notes.map { $0.workoutName }, ["Last Day"])
        XCTAssertEqual(notes.first?.text, "felt strong")
    }

    func test_collectNotes_truncatesAndKeepsMostRecent() {
        let workouts = (1...5).map {
            Workout(date: date(2026, 8, $0), name: "W\($0)", notes: String(repeating: "x", count: 50))
        }
        let notes = ClaudeSummaryService.collectNotes(
            workouts: workouts, start: date(2026, 8, 1), end: date(2026, 8, 30),
            calendar: calendar, limit: 2, maxCharacters: 10
        )

        XCTAssertEqual(notes.map { $0.workoutName }, ["W4", "W5"])
        XCTAssertEqual(notes.first?.text.count, 10)
    }

    // MARK: - Parsing

    func test_parseSummary_acceptsBareFencedAndProseWrappedJSON() {
        let json = #"{"headline":"Solid block","wins":["a","b"],"watchouts":[],"nextBlock":["c"]}"#
        let expected = AISummary(headline: "Solid block", wins: ["a", "b"], watchouts: [], nextBlock: ["c"])

        XCTAssertEqual(ClaudeSummaryService.parseSummary(json), expected)
        XCTAssertEqual(ClaudeSummaryService.parseSummary("```json\n\(json)\n```"), expected)
        XCTAssertEqual(ClaudeSummaryService.parseSummary("Here you go:\n\(json)\nHope that helps."), expected)
    }

    func test_parseSummary_toleratesMissingArrays() {
        let summary = ClaudeSummaryService.parseSummary(#"{"headline":"Only a headline"}"#)
        XCTAssertEqual(summary, AISummary(headline: "Only a headline", wins: [], watchouts: [], nextBlock: []))
    }

    func test_parseSummary_returnsNilForNonJSON() {
        XCTAssertNil(ClaudeSummaryService.parseSummary("Strong block overall, keep going."))
        XCTAssertNil(ClaudeSummaryService.parseSummary(#"{"wins":["no headline"]}"#))
    }

    // MARK: - API

    func test_generateSummary_throwsMissingAPIKeyForEmptyKey() async {
        do {
            _ = try await ClaudeSummaryService.generateSummary(
                report: makeReport(), phase: .strength, weightUnit: .kg,
                block: nil, notes: [], apiKey: ""
            )
            XCTFail("Expected missingAPIKey")
        } catch {
            guard case ClaudeSummaryError.missingAPIKey = error else {
                XCTFail("Expected missingAPIKey, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Response text extraction

    func test_extractText_readsTextBlockThatComesAfterAThinkingBlock() throws {
        let body = """
        {"stop_reason":"end_turn","content":[
          {"type":"thinking","thinking":"working it out..."},
          {"type":"text","text":"{\\"headline\\":\\"Solid block\\"}"}
        ]}
        """.data(using: .utf8)!

        XCTAssertEqual(try ClaudeSummaryService.extractText(from: body), #"{"headline":"Solid block"}"#)
    }

    func test_extractText_joinsMultipleTextBlocks() throws {
        let body = #"{"content":[{"type":"text","text":"first"},{"type":"text","text":"second"}]}"#.data(using: .utf8)!

        XCTAssertEqual(try ClaudeSummaryService.extractText(from: body), "first\nsecond")
    }

    func test_extractText_reportsStopReasonAndBlockTypesWhenNoText() {
        let body = #"{"stop_reason":"max_tokens","content":[{"type":"thinking","thinking":"..."}]}"#.data(using: .utf8)!

        XCTAssertThrowsError(try ClaudeSummaryService.extractText(from: body)) { error in
            guard case ClaudeSummaryError.emptyResponse(let detail) = error else {
                return XCTFail("Expected emptyResponse, got \(error)")
            }
            XCTAssertTrue(detail.contains("max_tokens"))
            XCTAssertTrue(detail.contains("thinking"))
        }
    }

    func test_extractText_throwsForNonJSONBody() {
        XCTAssertThrowsError(try ClaudeSummaryService.extractText(from: Data("<html>oops</html>".utf8))) { error in
            guard case ClaudeSummaryError.emptyResponse = error else {
                return XCTFail("Expected emptyResponse, got \(error)")
            }
        }
    }
}
