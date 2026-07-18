# WorkoutTracker

WorkoutTracker is an iOS strength training log built with SwiftUI and SwiftData. It helps track workouts, exercises, warm-up sets, working sets, training effort, and personal records for the main lifts.

## Features

- Log workouts with an optional name, date, exercises, notes, and sets.
- Add warm-up and working sets with weight, reps, RPE, or RIR.
- Track workout totals such as working sets, reps, and volume.
- View personal record progress for the main lifts with Swift Charts.
- Browse seeded exercises including Deadlift, Bench Press, Squat, Overhead Press, Barbell Row, and Pull-Up.
- Switch between kilograms and pounds in Settings while storing weights internally in kilograms.
- Uses a dark SwiftUI interface with shared app theme styling.

## Tech Stack

- SwiftUI for the app interface
- SwiftData for local persistence
- Swift Charts for personal record visualizations
- AppStorage for user unit preferences

## Project Structure

| File | Purpose |
| --- | --- |
| `WorkoutTrackerApp.swift` | App entry point and SwiftData model container setup. |
| `ContentView.swift` | Main tab layout for Workouts, PRs, Exercises, and Settings. |
| `Workout.swift` | Workout model and computed workout summaries. |
| `Exercise.swift` | Exercise model with category and main-lift metadata. |
| `ExerciseEntry.swift` | Links exercises to workouts and computes exercise totals. |
| `SetEntry.swift` | Set model for warm-up and working sets. |
| `WorkoutListView.swift` | Workout history and navigation into workout details. |
| `NewWorkoutView.swift` | Workout creation flow. |
| `SetEditorView.swift` | Set entry form. |
| `ExercisePickerView.swift` | Exercise selection flow. |
| `ExerciseDetailView.swift` | Exercise-specific history/details. |
| `PRDashboardView.swift` | Personal record cards and progress charts. |
| `SettingsView.swift` | Unit preference settings. |
| `ExerciseSeeder.swift` | Seeds default exercises on first launch. |
| `WeightUnit.swift` | Unit conversion helpers. |
| `Theme.swift` | Shared colors, typography, and visual styling. |

## Getting Started

1. Open `WorkoutTracker.xcodeproj` in Xcode.
2. Select the `WorkoutTracker` scheme.
3. Choose an iOS simulator or a connected iPhone.
4. Build and run the app.

On first launch, the app seeds a default exercise list if no exercises exist yet.

## Data Model

The app persists four SwiftData models:

- `Workout`: date, optional name, optional notes, and related exercise entries.
- `Exercise`: reusable exercise definitions and main-lift tracking metadata.
- `ExerciseEntry`: an exercise performed in a workout, with related sets.
- `SetEntry`: set type, set number, weight, reps, and optional effort metric.

Deleting a workout cascades through its exercise entries and sets.

## Notes

Weights are stored in kilograms internally. The selected display unit only changes how values are entered and presented, so switching between kg and lb does not rewrite past workout data.
