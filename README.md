# WorkoutTracker
WorkoutTracker is an iOS strength training log built with SwiftUI and SwiftData. It helps track workouts, exercises, warm-up sets, working sets, training effort, personal records across weight, bodyweight-rep, and assisted-bodyweight exercises, and generates progress reports over custom training periods.
## Features
- Log workouts with an optional name, date, exercises, notes, and sets.
- Add warm-up and working sets with weight, reps, RPE, or RIR. Sets always display warm-ups before working sets, regardless of entry order.
- Track workout totals such as working sets, reps, and volume.
- Per-exercise PR tracking with three metrics, selectable per exercise from its detail screen:
  - **Weight** — track max weight, for barbell lifts like Deadlift, Bench Press, and Squat.
  - **Reps** — track max reps at bodyweight (0 kg), for movements like Chin-Up and Pull-Up. Also flags if you've started adding external weight.
  - **Assisted** — for machine-assisted movements like Assisted Pull-Up/Dip/Chin-Up, where the logged weight is machine assistance, not resistance. The app computes effective load moved (bodyweight − assistance) and tracks progress as assistance decreases.
- Set a current bodyweight in Settings, used to show weight-tracked lifts as a multiple of bodyweight (e.g. "1.67x bodyweight") and to compute effective load for assisted exercises.
- View personal record progress with Swift Charts, styled per tracking metric.
- Browse a large seeded exercise catalog covering main lifts, assisted/weighted bodyweight variants, and common accessories.
- Search the exercise list when adding an exercise to a workout, or add a custom exercise inline if it isn't in the catalog yet.
- Repeat a past workout to start a new one pre-loaded with the same exercises, each showing a "last time" reference (weight × reps, RPE/RIR) for context — no numbers are carried over automatically.
- Rest timer starts automatically after logging a working set, with a floating countdown bar, quick +30s adjustment, a skip option, and a local notification if the app is backgrounded. Default duration is configurable (30s–5min); individual working sets can override it via press-and-hold for heavier top sets that need longer rest.
- Generate a training report over a custom date range, with a Strength/Bodybuilding focus toggle. Reports surface metric-appropriate progress for every tracked exercise (weight delta and estimated 1RM, reps delta and added-weight milestones, or effective-load delta), plus weekly volume and best/toughest week detection based on average RPE/RIR.
- Export all workout data as a JSON backup, and import it back in later — with a choice between replacing all data (clean restore) or merging with what's already in the app. Since there's no cloud sync, this is the safety net against reinstalls, app updates, or a lost/replaced phone.
- Switch between kilograms and pounds in Settings while storing weights internally in kilograms.
- Workouts are only saved to the database when explicitly saved — starting a new workout and backing out (Discard, or swiping the sheet away) leaves no trace.
- Uses a dark SwiftUI interface with a competition-plate color system (red/blue/yellow per main lift) and shared app theme styling.
## Tech Stack
- SwiftUI for the app interface
- SwiftData for local persistence
- Swift Charts for personal record visualizations
- Combine for the rest timer's observable state
- UserNotifications for rest-complete alerts
- AppStorage for user unit, bodyweight, and rest timer preferences
- SwiftUI's `.fileExporter`/`.fileImporter` for JSON backup export/import
## Project Structure
| File | Purpose |
| --- | --- |
| `WorkoutTrackerApp.swift` | App entry point, SwiftData model container setup, and notification authorization request. |
| `ContentView.swift` | Main tab layout for Workouts, Report, PRs, Exercises, and Settings. Runs one-time PR-metric migration on launch. |
| `Workout.swift` | Workout model and computed workout summaries. |
| `Exercise.swift` | Exercise model with category and `prMetric` (weight / reps / assisted / untracked). |
| `ExerciseEntry.swift` | Links exercises to workouts and computes exercise totals, including sorted (warm-up first) set ordering and a transient "last time" display label used by Repeat Workout. |
| `SetEntry.swift` | Set model for warm-up and working sets. |
| `WorkoutListView.swift` | Workout history, navigation into workout details, and the Repeat Workout swipe action. |
| `NewWorkoutView.swift` | Workout creation flow; workout is only persisted on Save. Hosts the rest timer bar and per-set rest duration override. |
| `SetEditorView.swift` | Set entry form, with locale-aware decimal parsing (handles both `.` and `,`). Labels the weight field "Assistance" instead of "Weight" for assisted-tracked exercises. |
| `ExercisePickerView.swift` | Searchable exercise selection flow with inline "add custom exercise." |
| `ExerciseDetailView.swift` | Exercise-specific history/details, plus the PR Tracking picker (Not Tracked / Weight / Reps / Assisted) and the corresponding personal-record display. |
| `PRDashboardView.swift` | Personal record cards and progress charts, with a dedicated card type per tracking metric (weight, reps, assisted/effective-load). |
| `ReportGenerator.swift` | Pure calculation layer for training reports — period totals, weekly breakdown, per-exercise progress across all three PR metrics, and phase-based insights. |
| `ReportView.swift` | Report generation UI — period and focus selection, results display with metric-aware progress lines and delta badges. |
| `RestTimerManager.swift` | Observable countdown timer, backed by an end-date for accuracy, plus local notification scheduling for rest completion. |
| `RestTimerBar.swift` | Floating themed rest timer UI — progress ring, countdown, +30s, and skip. |
| `BackupModels.swift` | Versioned, Codable backup format and `BackupManager`, which builds/encodes a backup from the store and decodes/imports one back in (Replace or Merge). |
| `BackupDocument.swift` | `FileDocument` wrapper so SwiftUI's `.fileExporter` can save the backup JSON. |
| `SettingsView.swift` | Unit preference, current bodyweight, default rest timer duration, and backup export/import. |
| `ExerciseSeeder.swift` | Seeds the default exercise catalog on first launch, including default PR-metric assignments. Also runs a one-time migration (`migratePRMetricIfNeeded`) that derives `prMetric` for installs seeded before the field existed, without overwriting manual tracking choices made afterward. |
| `WeightUnit.swift` | Unit conversion helpers. |
| `Theme.swift` | Shared colors, typography, and visual styling. |
| `DeleteConfirmationOverlay.swift` | Themed confirmation overlay for deleting or discarding workouts. |
## Getting Started
1. Open `WorkoutTracker.xcodeproj` in Xcode.
2. Select the `WorkoutTracker` scheme.
3. Choose an iOS simulator or a connected iPhone.
4. For a physical device, select your Apple ID under **Signing & Capabilities → Team**. A free Apple ID works for personal installs but expires after 7 days — reconnect and rebuild to renew.
5. Build and run the app.
6. Allow notifications when prompted, so rest timer alerts still arrive if the app is backgrounded.
On first launch, the app seeds a default exercise list if no exercises exist yet.
## Data Model
The app persists four SwiftData models:
- `Workout`: date, optional name, optional notes, and related exercise entries.
- `Exercise`: reusable exercise definitions, category, and `prMetric` (`.weight`, `.reps`, `.assisted`, or `nil` for untracked).
- `ExerciseEntry`: an exercise performed in a workout, with related sets, a back-reference to its parent workout, and a transient (non-persisted) `lastSessionLabel` used to show reference numbers when repeating a workout.
- `SetEntry`: set type, set number, weight (or assistance amount, for assisted-tracked exercises), reps, and optional effort metric (RPE or RIR), plus a back-reference to its parent exercise entry.
Deleting a workout cascades through its exercise entries and sets. Objects created while building a new workout aren't inserted into the model context until the workout is saved, so discarding an in-progress workout cleanly leaves no orphaned data. The same applies to a repeated workout — nothing is written until Save.

**Note on SwiftData `#Predicate`:** avoid comparing an optional `Codable` enum property (like `prMetric`) to `nil` inside a `#Predicate` — it isn't reliably translated to SQL and can crash with a "keypath not found" error. Fetch unfiltered with `@Query` and filter in-memory with a plain Swift `.filter` instead.
## PR Tracking
Each exercise can be set to one of three tracking metrics (or left untracked) from its detail screen:
- **Weight** — the classic case, used for barbell lifts. PR is the heaviest working-set weight in a session, tracked across all sessions. Reports include an estimated one-rep max (Epley formula) and, if bodyweight is set, a bodyweight-multiple ratio.
- **Reps** — for bodyweight movements. Only sets logged at 0 kg count toward the reps PR, since reps at different added weights aren't directly comparable. If a set with added weight is logged, that's called out separately in reports as a milestone rather than folded into the reps trend.
- **Assisted** — for machine-assisted movements. The weight field is relabeled "Assistance," and the app computes effective load moved as bodyweight − assistance. Progress means less assistance over time, so PR is the session with the least assistance (highest effective load). Requires bodyweight to be set in Settings.
Bodyweight is entered once in Settings (unit-aware, stored internally in kg) and is used both for the bodyweight-ratio line on weight-tracked lifts and as the basis for all effective-load calculations on assisted-tracked exercises.
## Repeat Workout
Swiping a past workout (leading edge) offers **Repeat**, which opens a new workout pre-loaded with the same exercises in the same order. Only the exercise list is copied — weight, reps, and RPE/RIR are always left blank so each session's numbers are entered fresh. Each exercise shows a "Last time: weight × reps, RPE/RIR" line (pulled from that exercise's heaviest working set in the source workout) as reference while logging today's numbers.
## Rest Timer
Logging a working set (not a warm-up) automatically starts a rest countdown, shown as a floating bar above the tab bar for the duration of the rest period. The bar shows a progress ring, time remaining, a +30s button, and a skip option. A local notification is scheduled in parallel so rest completion is still signaled if the phone is locked or the app is backgrounded. The default duration is set in Settings (30s–5min); pressing and holding "Working Set" on a given exercise offers one-off overrides (90s/2min/3min/5min) for sets that need more or less rest than the default, such as a heavy top set. The timer is cancelled on Discard, Save, or leaving the workout screen, so no stray notification fires after a workout is finished or abandoned.
## Reports
Reports are generated on demand for any date range, using only the sets already logged — no separate data entry required. Every exercise with PR tracking enabled gets a progress card, styled to its metric:
- **Weight-tracked exercises**: top-set weight progression (first session vs. period-best), estimated one-rep max, and bodyweight ratio if set.
- **Reps-tracked exercises**: bodyweight rep progression (first session vs. period-best), plus a called-out milestone if external weight was added during the period.
- **Assisted-tracked exercises**: effective-load progression (first session vs. period-best) as assistance decreases.
The Strength/Bodybuilding focus toggle changes the surrounding narrative rather than which exercises appear: Strength focus adds 1RM and bodyweight-ratio detail to weight-tracked lifts; Bodybuilding focus adds weekly volume trend and training-frequency insights alongside the same per-exercise progress cards. Both modes identify the week with the lowest average effort (best week) and highest average effort (toughest week), based on a normalized 0–10 scale combining RPE and RIR.
## Backup & Restore
Since the app has no cloud sync and all data lives only in local SwiftData storage on-device, Settings includes an **Export Backup** / **Import Backup** pair to guard against losing data on a reinstall, app update, or new phone.
- **Export** writes a versioned, human-readable JSON file containing every exercise (including its PR tracking metric) and workout (including all sets, weights, reps, and RPE/RIR), via the standard iOS file picker — saving to iCloud Drive is recommended so the backup survives independently of the app itself.
- **Import** reads a previously exported file and offers a choice of two modes:
  - **Replace All Data** — deletes everything currently in the app, then restores exactly what's in the backup. Use this after a reinstall or update.
  - **Merge** — adds the backup's workouts on top of what's already in the app, matching exercises by name so the catalog isn't duplicated.
Typical update flow: **Export Backup** before updating or reinstalling → **Import Backup → Replace All Data** afterward to restore everything. Note that a backup taken before the PR-metric feature existed won't include tracking-metric choices for individual exercises — re-apply those from Exercise Detail after such an import; main lifts recover automatically via the migration.
## Notes
Weights are stored in kilograms internally. The selected display unit only changes how values are entered and presented, so switching between kg and lb does not rewrite past workout data.
