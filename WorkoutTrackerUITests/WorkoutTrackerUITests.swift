//
//  WorkoutTrackerUITests.swift
//  WorkoutTrackerUITests
//
//  UI tests covering the core workout flow: create a workout, add an
//  exercise, log a working set, save, and verify it appears in history.
//
//  Created by Alexandru Mihalache on 26/08/2026.
//

import XCTest

final class WorkoutTrackerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMode"]
        app.launch()
        return app
    }

    func testLogAndSaveWorkoutAppearsInHistory() throws {
        let app = launchApp()

        // Start a new workout
        app.buttons["workoutList.newWorkoutButton"].tap()

        let nameField = app.textFields["newWorkout.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("UI Test Workout")

        // Add an exercise
        app.buttons["newWorkout.addExerciseButton"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Bench Press")

        let benchRow = app.buttons["exercisePicker.row.Bench Press"]
        XCTAssertTrue(benchRow.waitForExistence(timeout: 5))
        benchRow.tap()

        // Log a working set
        let workingSetButtonPredicate = NSPredicate(format: "identifier BEGINSWITH 'newWorkout.workingSetButton.'")
        let workingSetButton = app.buttons.matching(workingSetButtonPredicate).firstMatch
        XCTAssertTrue(workingSetButton.waitForExistence(timeout: 5))
        workingSetButton.tap()

        let weightField = app.textFields["setEditor.weightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        weightField.tap()
        weightField.typeText("100")

        let repsField = app.textFields["setEditor.repsField"]
        repsField.tap()
        repsField.typeText("5")

        app.buttons["setEditor.saveButton"].tap()

        // Save the workout
        let saveButton = app.buttons["newWorkout.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        // Verify it shows up back in the workout list, and that it's
        // specifically the workout just created (not just any row).
        let workoutRowPredicate = NSPredicate(format: "identifier BEGINSWITH 'workoutList.row.'")
        let workoutRow = app.buttons.matching(workoutRowPredicate).firstMatch
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 5))
        XCTAssertTrue(workoutRow.label.contains("UI Test Workout"))
    }

    func testDiscardEmptyWorkoutLeavesNoTrace() throws {
        let app = launchApp()

        let noWorkoutsText = app.staticTexts["No Workouts Yet"]
        XCTAssertTrue(noWorkoutsText.waitForExistence(timeout: 5))

        app.buttons["workoutList.newWorkoutButton"].tap()

        let discardButton = app.buttons["newWorkout.discardButton"]
        XCTAssertTrue(discardButton.waitForExistence(timeout: 5))
        discardButton.tap()

        // Empty workout discards immediately without a confirmation prompt
        XCTAssertTrue(noWorkoutsText.waitForExistence(timeout: 5))
    }
}
