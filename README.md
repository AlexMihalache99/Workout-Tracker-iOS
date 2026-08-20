# WorkoutTracker
WorkoutTracker is an iOS strength training log built with SwiftUI and SwiftData. It helps track workouts, exercises, warm-up sets, working sets, training effort, personal records for the main lifts, and generates progress reports over custom training periods.
## Features
- Log workouts with an optional name, date, exercises, notes, and sets.
- Add warm-up and working sets with weight, reps, RPE, or RIR. Sets always display warm-ups before working sets, regardless of entry order.
- Track workout totals such as working sets, reps, and volume.
- View personal record progress for the main lifts with Swift Charts.
- Browse seeded exercises including Deadlift, Bench Press, Squat, Overhead Press, Barbell Row, and Pull-Up.
- Search the exercise list when adding an exercise to a workout, or add a custom exercise inline if it isn't in the catalog yet.
- Generate a training report over a custom date range, with a Strength/Bodybuilding focus toggle. Reports include per-lift progress (period-best vs. first session, estimated 1RM), weekly volume, and best/toughest week detection based on average RPE/RIR.
- Switch between kilograms and pounds in Settings while storing weights internally in kilograms.
- Workouts are only saved to the database when explicitly saved — starting a new workout and backing out (Discard, or swiping the sheet away) leaves no trace.
- Uses a dark SwiftUI interface with a competition-plate color system (red/blue/yellow per main lift) and shared app theme styling.
## Tech Stack
- SwiftUI for the app interface
- SwiftData for local persistence
- Swift Charts for personal record visualizations
- AppStorage for user unit preferences
## Project Structure
| File | Purpose |
| --- | --- |
| `WorkoutTrackerApp.swift` | App entry point and SwiftData model container setup. |
| `ContentView.swift` | Main tab layout for Workouts, Report, PRs, Exercises, and Settings. |
| `Workout.swift` | Workout model and computed workout summaries. |
| `Exercise.swift` | Exercise model with category and main-lift metadata. |
| `ExerciseEntry.swift` | Links exercises to workouts and computes exercise totals, including sorted (warm-up first) set ordering. |
| `SetEntry.swift` | Set model for warm-up and working sets. |
| `WorkoutListView.swift` | Workout history and navigation into workout details. |
| `NewWorkoutView.swift` | Workout creation flow; workout is only persisted on Save. |
| `SetEditorView.swift` | Set entry form, with locale-aware decimal parsing (handles both `.` and `,`). |
| `ExercisePickerView.swift` | Searchable exercise selection flow with inline "add custom exercise." |
| `ExerciseDetailView.swift` | Exercise-specific history/details. |
| `PRDashboardView.swift` | Personal record cards and progress charts. |
| `ReportGenerator.swift` | Pure calculation layer for training reports — period totals, weekly breakdown, per-lift progress, and phase-based insights. |
| `ReportView.swift` | Report generation UI — period and focus selection, results display. |
| `SettingsView.swift` | Unit preference settings. |
| `ExerciseSeeder.swift` | Seeds default exercises on first launch. |
| `WeightUnit.swift` | Unit conversion helpers. |
| `Theme.swift` | Shared colors, typography, and visual styling. |
| `DeleteConfirmationOverlay.swift` | Themed confirmation overlay for deleting or discarding workouts. |
## Getting Started
1. Open `WorkoutTracker.xcodeproj` in Xcode.
2. Select the `WorkoutTracker` scheme.
3. Choose an iOS simulator or a connected iPhone.
4. For a physical device, select your Apple ID under **Signing & Capabilities → Team**. A free Apple ID works for personal installs but expires after 7 days — reconnect and rebuild to renew.
5. Build and run the app.
On first launch, the app seeds a default exercise list if no exercises exist yet.
## Data Model
The app persists four SwiftData models:
- `Workout`: date, optional name, optional notes, and related exercise entries.
- `Exercise`: reusable exercise definitions and main-lift tracking metadata.
- `ExerciseEntry`: an exercise performed in a workout, with related sets, plus a back-reference to its parent workout.
- `SetEntry`: set type, set number, weight, reps, and optional effort metric (RPE or RIR), plus a back-reference to its parent exercise entry.
Deleting a workout cascades through its exercise entries and sets. Objects created while building a new workout aren't inserted into the model context until the workout is saved, so discarding an in-progress workout cleanly leaves no orphaned data.
## Reports
Reports are generated on demand for any date range, using only the sets already logged — no separate data entry required.
- **Strength focus** surfaces top-set weight progression per main lift (first session vs. period-best) and an estimated one-rep max via the Epley formula.
- **Bodybuilding focus** surfaces weekly volume trend and training frequency/consistency.
- Both modes identify the week with the lowest average effort (best week) and highest average effort (toughest week), based on a normalized 0–10 scale combining RPE and RIR.
## Notes
Weights are stored in kilograms internally. The selected display unit only changes how values are entered and presented, so switching between kg and lb does not rewrite past workout data. The main lifts (Deadlift, Bench Press, Squat) are the only exercises with PR tracking and report insights; other exercises get full logging and history but not PR/report treatment.
