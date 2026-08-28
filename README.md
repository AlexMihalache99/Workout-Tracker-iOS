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
- Suggested warm-up ramp — generates a standard percentage-based warm-up (bar, 40%, 60%, 80% of a target working weight), rounded to loadable increments, with a plate breakdown per step and a one-tap "Add All" to log them as warm-up sets.
- Plate calculator — given a target weight and configurable bar weight, shows the plates to load per side using a standard Olympic plate set, with a visual bar representation. Accessible from the set editor's weight field.
- Repeat a past workout to start a new one pre-loaded with the same exercises, each showing a "last time" reference (weight × reps, RPE/RIR) for context — no numbers are carried over automatically.
- Rest timer starts automatically after logging a working set, with a floating countdown bar, quick +30s adjustment, a skip option, and a local notification if the app is backgrounded. Default duration is configurable (30s–5min); individual working sets can override it via press-and-hold for heavier top sets that need longer rest.
- Consistency tracking — a heat-map card at the top of the workout list showing training activity over a rolling ~20-week window (intensity by sets logged per day), plus current/longest weekly streaks and average sessions per week.
- Search workout history by name or date, and filter by exercise, from the Workouts tab.
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
- AppStorage for user unit, bodyweight, bar weight, and rest timer preferences
- SwiftUI's `.fileExporter`/`.fileImporter` for JSON backup export/import
## Project Structure
```
WorkoutTracker/
├─ WorkoutTrackerApp.swift      — app entry point, SwiftData container, notification auth
├─ ContentView.swift             — root TabView, one-time PR-metric migration on launch
├─ Theme.swift                   — shared colors, typography, visual styling
├─ ExerciseSeeder.swift          — seeds default exercise catalog + PR-metric migration
│
├─ Models/
│  ├─ Workout.swift              — Workout model + computed summaries
│  ├─ Exercise.swift             — Exercise model, category, prMetric
│  ├─ ExerciseEntry.swift        — links exercises to workouts, sorted sets, "last time" label
│  ├─ SetEntry.swift             — warm-up/working set model
│  └─ WeightUnit.swift           — kg/lb conversion helpers
│
├─ Views/
│  ├─ Workouts/
│  │  ├─ WorkoutListView.swift       — history, search/filter, heat-map, Repeat
│  │  ├─ NewWorkoutView.swift        — workout creation, rest timer, warm-up suggestion entry
│  │  ├─ WorkoutDetailView.swift     — view/edit a saved workout
│  │  └─ SetEditorView.swift         — set entry form, plate calculator shortcut
│  ├─ Exercises/
│  │  ├─ ExercisePickerView.swift    — searchable picker, inline custom-exercise add
│  │  └─ ExerciseDetailView.swift    — history, PR Tracking picker, personal record
│  ├─ PR/
│  │  └─ PRDashboardView.swift       — PR cards per tracking metric, with charts
│  ├─ Reports/
│  │  ├─ ReportGenerator.swift       — pure calculation layer for training reports
│  │  └─ ReportView.swift            — report period/focus selection, results display
│  ├─ RestTimer/
│  │  ├─ RestTimerManager.swift      — observable countdown, local notification scheduling
│  │  └─ RestTimerBar.swift          — floating rest timer UI
│  ├─ PlateCalculator/
│  │  ├─ PlateCalculator.swift       — plate breakdown calculation logic
│  │  ├─ PlateCalculatorView.swift   — plate calculator UI
│  │  ├─ WarmupSuggester.swift       — warm-up ramp calculation logic
│  │  └─ WarmupSuggestionView.swift  — warm-up suggestion UI
│  ├─ Consistency/
│  │  ├─ ConsistencyCalculator.swift — heat-map/streak calculation logic
│  │  └─ ConsistencyHeatmapView.swift — heat-map card UI
│  ├─ Settings/
│  │  └─ SettingsView.swift          — units, bodyweight, bar weight, rest timer, backup
│  └─ Shared/
│     └─ DeleteConfirmationOverlay.swift — themed delete/discard confirmation
│
└─ Backup/
   ├─ BackupModels.swift          — versioned Codable backup format + BackupManager
   └─ BackupDocument.swift        — FileDocument wrapper for .fileExporter
```
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
## Plate Calculator & Warm-up Suggester
- **Plate Calculator** takes a target weight and the configured bar weight (default 20 kg, adjustable in Settings) and computes which plates to load per side from a standard Olympic set (25/20/15/10/5/2.5/1.25 kg), using a greedy largest-plate-first algorithm. If the exact target isn't achievable with standard plates, it shows the closest achievable total instead. Opened from a button next to the weight field in the set editor (hidden for assisted-tracked exercises, since that number represents machine assistance rather than barbell load).
- **Warm-up Suggester** generates a standard ramp — bar × 8, 40% × 5, 60% × 3, 80% × 2 — from a target working weight (prefilled from the day's top working set if one's already logged), with each step rounded to a loadable 2.5 kg increment and shown with its own plate breakdown. "Add All" logs the full ramp as warm-up sets in one tap, ordered correctly ahead of working sets.
Both features share the same bar-weight setting and plate-rounding logic, and both convert their display to whichever unit (kg/lb) is currently selected while keeping the underlying plate math in real kg plate sizes.
## Repeat Workout
Swiping a past workout (leading edge) offers **Repeat**, which opens a new workout pre-loaded with the same exercises in the same order. Only the exercise list is copied — weight, reps, and RPE/RIR are always left blank so each session's numbers are entered fresh. Each exercise shows a "Last time: weight × reps, RPE/RIR" line (pulled from that exercise's heaviest working set in the source workout) as reference while logging today's numbers.
## Rest Timer
Logging a working set (not a warm-up) automatically starts a rest countdown, shown as a floating bar above the tab bar for the duration of the rest period. The bar shows a progress ring, time remaining, a +30s button, and a skip option. A local notification is scheduled in parallel so rest completion is still signaled if the phone is locked or the app is backgrounded. The default duration is set in Settings (30s–5min); pressing and holding "Working Set" on a given exercise offers one-off overrides (90s/2min/3min/5min) for sets that need more or less rest than the default, such as a heavy top set. The timer is cancelled on Discard, Save, or leaving the workout screen, so no stray notification fires after a workout is finished or abandoned.
## Consistency Tracking
The Workouts tab opens with a heat-map card showing daily training activity over a rolling ~20-week window, horizontally scrollable to see further back. Each day's square intensity reflects how many working sets were logged that day, not just whether you trained. Alongside the grid: your current weekly streak (weeks in a row with at least one workout, shown with a flame while active), longest streak on record, and average sessions per week — normalized to however many weeks you've actually been logging, so it doesn't understate consistency for newer histories shorter than the full window.
## Search & Filter
The Workouts tab supports searching by workout name or formatted date, and filtering the list down to workouts containing a specific exercise (via a menu listing only exercises you've actually used). Search and filter combine, and a dismissible chip shows the active exercise filter. A dedicated empty state distinguishes "no results for this search/filter" from "no workouts logged yet."
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

# Known Issues / Remediation Backlog

### P0 — breaks a feature or risks silent data loss
- [ ] Backup loses prMetric — BackupExercise does not store Exercise.prMetric, so exporting and importing an exercise can silently change how its training volume/PR calculations behave. (BackupModels.swift, Exercise.swift)
- [ ] Backup loses supersets — ExerciseEntry.supersetGroupID is not represented in the backup format, so restoring a workout silently removes all superset pairings/groups. (BackupModels.swift, ExerciseEntry.swift)
- [ ] Backup silently skips unknown exercises — importBackup uses guard let exercise = exerciseByName[...] else { continue }, meaning an exercise entry can disappear from an imported workout without an error or warning. This is direct silent data loss. (BackupModels.swift)
- [ ] Backup does not preserve workout session start/end times — Workout.sessionStartTime and Workout.sessionEndTime exist in the model but are absent from BackupWorkout, so duration information is lost after restore. (BackupModels.swift, Workout.swift)
- [ ] Backup does not preserve exercise notes — Exercise.notes is persistent user data but BackupExercise only stores name, category, and isMainLift. Export/import therefore loses exercise notes. (BackupModels.swift, Exercise.swift)

### P1 — real correctness/reliability issues, narrower scope
- [ ] Backup relies on exercise names as identity — import matches exercises exclusively through exercise.name. Renaming or having ambiguous duplicate names can cause an imported workout to attach to the wrong catalog exercise or create unintended catalog entries. (BackupModels.swift)
- [ ] Backup does not explicitly preserve exercise/workout ordering — the backup serializes arrays, but the persistence relationships do not establish an explicit ordering field. Relying on SwiftData relationship ordering makes exact restoration less robust. (BackupModels.swift, Workout.swift, ExerciseEntry.swift)
- [ ] Backup versioning has no migration layer — decode correctly rejects future versions, but there is no mechanism for migrating an older backup schema when the current model changes. This will become a compatibility problem once the backup format evolves beyond v1. (BackupModels.swift)
- [ ] Backup setType is stringly typed — BackupSet.setType uses arbitrary String values ("warmup" / "working") instead of a Codable representation of SetType, allowing invalid values to be silently interpreted as working during import. (BackupModels.swift, SetEntry.swift)
- [ ] Merge import does not reconcile existing exercise metadata — when an exercise with the same name already exists, the imported category, isMainLift, and eventually other metadata are ignored. The backup may therefore not fully restore the exported exercise configuration. (BackupModels.swift)
- [ ] Import is not designed as an atomic transaction — replace deletes existing data and saves before the backup has been completely reconstructed. A later import failure can therefore leave the user's database empty or partially restored. (BackupModels.swift)
- [ ] HealthKit workout writing depends on authorization state that must be kept in sync with requested permissions — workout and active-energy permissions are treated as required for successful writes, so any mismatch between requested/readable authorization and actual HealthKit permissions can make sync fail at runtime. (HealthKitManager.swift)
- [ ] HealthKit calorie calculation is only a rough sets × 6 estimate — workouts written to Apple Health receive an estimated active-energy value that is not based on workout duration, bodyweight, exercise intensity, or other physiological inputs. This can result in misleading Health data. (HealthKitManager.swift)
  
### P2 — cleanup / latent risk, no current functional impact
- [ ] Unit/UI test workflow is not clearly separated in Xcode — the project can run the unit tests successfully from the scheme/CLI, but the Xcode Test navigator/test-plan workflow does not currently provide the same clear test-result experience. This makes test execution/verification more confusing than necessary. (Xcode test configuration)
- [ ] Test coverage should be expanded around backup invariants — the existing backup tests cover round-trip basics, future-version rejection, replace, merge, and the missing-exercise case, but the critical invariants such as prMetric, supersets, notes, session times, ordering, and malformed set types need explicit regression tests. (BackupManagerTests.swift)
