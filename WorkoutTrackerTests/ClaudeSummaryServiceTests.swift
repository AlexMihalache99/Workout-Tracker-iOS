//
//  ClaudeSummaryServiceTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 05/09/2026.
//


import XCTest
@testable import WorkoutTracker

final class ClaudeSummaryServiceTests: XCTestCase {
    func test_buildPrompt_includesPhaseAndDateRange() {
        let report = WorkoutReport(
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_701_000_000),
            phase: .strength, totalWorkouts: 4, totalSets: 20, totalReps: 100,
            totalVolume: 5000, weeklyStats: [], liftProgress: [],
            lowestEffortWeek: nil, highestEffortWeek: nil, insights: []
        )
        let prompt = ClaudeSummaryService.buildPrompt(report: report, phase: .strength, weightUnit: .kg)

        XCTAssertTrue(prompt.contains("Strength"))
        XCTAssertTrue(prompt.contains("strength-focused"))
        XCTAssertTrue(prompt.contains("Workouts: 4"))
        XCTAssertTrue(prompt.contains("Total sets: 20"))
    }

    func test_buildPrompt_usesBodybuildingVoiceWhenPhaseIsBodybuilding() {
        let report = WorkoutReport(
            startDate: Date(), endDate: Date(), phase: .bodybuilding,
            totalWorkouts: 1, totalSets: 5, totalReps: 25, totalVolume: 1000,
            weeklyStats: [], liftProgress: [], lowestEffortWeek: nil, highestEffortWeek: nil, insights: []
        )
        let prompt = ClaudeSummaryService.buildPrompt(report: report, phase: .bodybuilding, weightUnit: .kg)

        XCTAssertTrue(prompt.contains("bodybuilding-focused"))
    }

    func test_generateSummary_throwsMissingAPIKeyForEmptyKey() async {
        let report = WorkoutReport(
            startDate: Date(), endDate: Date(), phase: .strength,
            totalWorkouts: 0, totalSets: 0, totalReps: 0, totalVolume: 0,
            weeklyStats: [], liftProgress: [], lowestEffortWeek: nil, highestEffortWeek: nil, insights: []
        )
        do {
            _ = try await ClaudeSummaryService.generateSummary(report: report, phase: .strength, weightUnit: .kg, apiKey: "")
            XCTFail("Expected missingAPIKey to be thrown")
        } catch {
            guard case ClaudeSummaryError.missingAPIKey = error else {
                XCTFail("Expected missingAPIKey, got \(error)")
                return
            }
        }
    }
}