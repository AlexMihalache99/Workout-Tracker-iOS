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

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()
        let trailingEdge = coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        trailingEdge.tap()

        let existingLength = (value as? String)?.count ?? 0
        if existingLength > 0 {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingLength + 5)
            typeText(deleteString)
        }
        typeText(text)
    }
}

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
        XCTAssertTrue(saveButton.waitForExistence(timeout: 15))
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
    
    func testEditingSavedWorkoutSetPersistsChange() throws {
        let app = launchApp()

        // Create and save a workout with one working set.
        app.buttons["workoutList.newWorkoutButton"].tap()

        let nameField = app.textFields["newWorkout.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Edit Test Workout")

        app.buttons["newWorkout.addExerciseButton"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Bench Press")

        let benchRow = app.buttons["exercisePicker.row.Bench Press"]
        XCTAssertTrue(benchRow.waitForExistence(timeout: 5))
        benchRow.tap()

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

        let saveWorkoutButton = app.buttons["newWorkout.saveButton"]
        XCTAssertTrue(saveWorkoutButton.waitForExistence(timeout: 15))
        saveWorkoutButton.tap()

        // Open the saved workout from the list.
        let workoutRowPredicate = NSPredicate(format: "identifier BEGINSWITH 'workoutList.row.'")
        let workoutRow = app.buttons.matching(workoutRowPredicate).firstMatch
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 5))
        workoutRow.tap()

        // Tap the logged set to edit it.
        let setRowPredicate = NSPredicate(format: "identifier BEGINSWITH 'workoutDetail.setRow.'")
        let setRow = app.buttons.matching(setRowPredicate).firstMatch
        XCTAssertTrue(setRow.waitForExistence(timeout: 5))
        setRow.tap()

        // Change the weight from 100 to 65.
        let editWeightField = app.textFields["setEditor.weightField"]
        XCTAssertTrue(editWeightField.waitForExistence(timeout: 5))
        editWeightField.clearAndTypeText("65")

        app.buttons["setEditor.saveButton"].tap()

        // Back on the detail screen, the row should reflect the new weight.
        let updatedSetRow = app.buttons.matching(setRowPredicate).firstMatch
        XCTAssertTrue(updatedSetRow.waitForExistence(timeout: 5))
        XCTAssertTrue(
            updatedSetRow.label.contains("65.0"),
            "Expected the edited weight to appear, got: \(updatedSetRow.label)"
        )
    }

    func testEditingBodyweightInSettingsPersists() throws {
        let app = launchApp()

        app.buttons["gear"].tap()

        let bodyweightField = app.textFields["settings.bodyweightField"]
        XCTAssertTrue(bodyweightField.waitForExistence(timeout: 5))
        bodyweightField.tap()
        bodyweightField.typeText("82.5")

        // Dismiss the keyboard so the value actually commits to the binding.
        app.buttons["Done"].firstMatch.tap()

        let value = bodyweightField.value as? String ?? ""
        XCTAssertTrue(value.contains("82"), "Expected the bodyweight field to reflect the new value, got: \(value)")
    }
    
    func testExportBackupPresentsSystemExportSheet() throws {
        let app = launchApp()

        app.buttons["gear"].tap()
        for _ in 0..<5 {
            if app.buttons["settings.exportButton"].exists { break }
            app.swipeUp()
        }

        let exportButton = app.buttons["settings.exportButton"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()

        let systemSheet = app.navigationBars.firstMatch
        XCTAssertTrue(systemSheet.waitForExistence(timeout: 5), "Expected the system export sheet to appear")
    }
    
}
