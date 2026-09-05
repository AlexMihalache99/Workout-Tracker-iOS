# WorkoutTracker
WorkoutTracker is an iOS strength training log built with SwiftUI and SwiftData. It helps track workouts, exercises, warm-up sets, working sets, training effort, personal records across weight, bodyweight-rep, and assisted-bodyweight exercises, and generates progress reports over custom training periods.
## Features
- Log workouts with an optional name, date, exercises, notes, and sets.
- Add warm-up and working sets with weight, reps, RPE, or RIR. Sets always display warm-ups before working sets, regardless of entry order.
- Track workout totals such as working sets, reps, and volume — computed with a bodyweight-aware training-volume calculation, so bodyweight and assisted exercises contribute a meaningful load figure instead of reading as zero or backwards.
- Per-exercise PR tracking with three metrics, selectable per exercise from its detail screen:
  - **Weight** — track max weight, for barbell lifts like Deadlift, Bench Press, and Squat.
  - **Reps** — track max reps at bodyweight (0 kg), for movements like Chin-Up and Pull-Up. Also flags if you've started adding external weight.
  - **Assisted** — for machine-assisted movements like Assisted Pull-Up/Dip/Chin-Up, where the logged weight is machine assistance, not resistance. The app computes effective load moved (bodyweight − assistance, floored at zero) and tracks progress as assistance decreases.
- Set a current bodyweight in Settings, used to show weight-tracked lifts as a multiple of bodyweight (e.g. "1.67x bodyweight") and to compute effective load for assisted exercises.
- View personal record progress with Swift Charts, styled per tracking metric, powered by a single shared calculation layer (`PRCalculator`) used both on the PR Dashboard and in Reports.
- Browse a large seeded exercise catalog covering main lifts, assisted/weighted bodyweight variants, and common accessories.
- Search the exercise list when adding an exercise to a workout, or add a custom exercise inline if it isn't in the catalog yet.
- Suggested warm-up ramp — generates a standard percentage-based warm-up (bar, 40%, 60%, 80% of a target working weight), rounded to loadable increments, with a plate breakdown per step and a one-tap "Add All" to log them as warm-up sets. Available only for Deadlift, Bench Press, Squat, and Overhead Press, since those are the exercises plate math actually applies to.
- Plate calculator — given a target weight and configurable bar weight, shows the plates to load per side using a standard Olympic plate set, with a visual bar representation. Accessible from the set editor's weight field, for the same four barbell lifts as the warm-up suggester (hidden for every other exercise, including assisted-tracked ones, since that number represents machine assistance rather than barbell load).
- Repeat a past workout to start a new one pre-loaded with the same exercises, each showing a "last time" reference (weight × reps, RPE/RIR) for context — no numbers are carried over automatically.
- Rest timer starts automatically after logging a working set, with a floating countdown bar, quick +30s adjustment, a skip option, and a local notification if the app is backgrounded. Default duration is configurable (30s–5min); individual working sets can override it via press-and-hold for heavier top sets that need longer rest — the override applies to that one set only and resets immediately after, rather than silently carrying over to the next exercise.
- Consistency tracking — a heat-map card at the top of the workout list showing training activity over a rolling ~20-week window (intensity by sets logged per day), plus current/longest weekly streaks and average sessions per week. Both the streak calculation and the average are bounded against future-dated entries, so a mis-dated workout can't inflate either figure.
- Search workout history by name or date, and filter by exercise, from the Workouts tab.
- Generate a training report over a custom date range (inclusive of the entire selected end date, not just midnight of it), with a Strength/Bodybuilding focus toggle. Reports surface metric-appropriate progress for every tracked exercise (weight delta and estimated 1RM, reps delta and added-weight milestones, or effective-load delta), plus weekly volume and effort-based week detection.
- Sync completed workouts to Apple Health as strength-training sessions, and pull your latest bodyweight from Health into Settings — both opt-in via a single toggle. See **Apple Health Sync** below.
- Export all workout data as a JSON backup, and import it back in later — with a choice between replacing all data (clean restore) or merging with what's already in the app, with idempotent merge (re-importing the same backup doesn't duplicate). Since there's no cloud sync, this is the safety net against reinstalls, app updates, or a lost/replaced phone. See **Backup & Restore** below.
- Switch between kilograms and pounds in Settings while storing weights internally in kilograms.
- Workouts are only saved to the database when explicitly saved — starting a new workout and backing out (Discard, or swiping the sheet away) leaves no trace.
- Uses a dark SwiftUI interface with a competition-plate color system (red/blue/yellow per main lift) and shared app theme styling.
## Tech Stack
- SwiftUI for the app interface
- SwiftData for local persistence
- Swift Charts for personal record visualizations
- Combine for the rest timer's observable state
- UserNotifications for rest-complete alerts
- HealthKit for optional Apple Health workout/bodyweight sync
- AppStorage for user unit, bodyweight, bar weight, plate inventory, and rest timer preferences
- SwiftUI's `.fileExporter`/`.fileImporter` for JSON backup export/import
## Project Structure
```
WorkoutTracker/
├─ WorkoutTrackerApp.swift — app entry point, SwiftData container, notification auth
├─ ContentView.swift — root TabView, one-time PR-metric migration on launch
├─ Theme.swift — shared colors, typography, visual styling
├─ ExerciseSeeder.swift — seeds default exercise catalog + PR-metric migration
├─ HealthKitManager.swift — Apple Health authorization, workout write, bodyweight read
│
├─ Models/
│ ├─ Workout.swift — Workout model, stable id, session timing, computed summaries
│ ├─ Exercise.swift — Exercise model, category, prMetric
│ ├─ ExerciseEntry.swift — links exercises to workouts, sorted sets, "last time" label
│ ├─ SetEntry.swift — warm-up/working set model, invariant-clamping init
│ └─ WeightUnit.swift — kg/lb conversion helpers
│
├─ Views/
│ ├─ Workouts/
│ │ ├─ WorkoutListView.swift — history, search/filter, heat-map, Repeat
│ │ ├─ NewWorkoutView.swift — workout creation, rest timer, warm-up suggestion entry
│ │ ├─ WorkoutSession.swift — draft-workout business logic (pairing, sets, save/discard)
│ │ ├─ WorkoutDetailView.swift — view/edit a saved workout, explicit-save commit points
│ │ └─ SetEditorView.swift — set entry form, plate calculator shortcut
│ ├─ Exercises/
│ │ ├─ ExercisePickerView.swift — searchable picker, inline custom-exercise add
│ │ └─ ExerciseDetailView.swift — history, PR Tracking picker, personal record
│ ├─ PR/
│ │ ├─ PRDashboardView.swift — PR cards per tracking metric, with charts
│ │ └─ PRCalculator.swift — shared PR calculation logic (used by dashboard and reports)
│ ├─ Reports/
│ │ ├─ ReportGenerator.swift — pure calculation layer for training reports
│ │ └─ ReportView.swift — report period/focus selection, results display
│ ├─ RestTimer/
│ │ ├─ RestTimerManager.swift — observable countdown, local notification scheduling
│ │ └─ RestTimerBar.swift — floating rest timer UI
│ ├─ PlateCalculator/
│ │ ├─ PlateCalculator.swift — plate breakdown calculation + eligibility rule
│ │ ├─ PlateCalculatorView.swift — plate calculator UI
│ │ ├─ WarmupSuggester.swift — warm-up ramp calculation logic
│ │ └─ WarmupSuggestionView.swift — warm-up suggestion UI
│ ├─ Consistency/
│ │ ├─ ConsistencyCalculator.swift — heat-map/streak calculation logic
│ │ └─ ConsistencyHeatmapView.swift — heat-map card UI
│ ├─ Settings/
│ │ └─ SettingsView.swift — units, bodyweight, bar weight, plate inventory, rest timer, Health, backup
│ └─ Shared/
│ └─ DeleteConfirmationOverlay.swift — themed delete/discard confirmation
│
└─ Backup/
├─ BackupModels.swift — versioned Codable backup format, BackupManager, BackupMigrator
└─ BackupDocument.swift — FileDocument wrapper for .fileExporter
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
- `Workout`: stable `id` (UUID, used for backup merge identity), date, optional name, optional notes, session start/end timestamps (used for real duration and Health sync), and related exercise entries.
- `Exercise`: reusable exercise definitions, category, `prMetric` (`.weight`, `.reps`, `.assisted`, or `nil` for untracked), and optional notes.
- `ExerciseEntry`: an exercise performed in a workout, with related sets, a back-reference to its parent workout, an optional `supersetGroupID`, and a transient (non-persisted) `lastSessionLabel` used to show reference numbers when repeating a workout.
- `SetEntry`: set type, set number, weight (or assistance amount, for assisted-tracked exercises), reps, and optional effort metric (RPE or RIR), plus a back-reference to its parent exercise entry. Construction clamps weight/reps to non-negative and RPE/RIR to their valid ranges, and resolves RPE/RIR mutual exclusivity automatically.

Deleting a workout cascades through its exercise entries and sets. Objects created while building a new workout aren't inserted into the model context until the workout is saved (via `WorkoutSession`), so discarding an in-progress workout cleanly leaves no orphaned data. The same applies to a repeated workout — nothing is written until Save.

Edits made directly to an already-saved workout or exercise (renaming, notes, PR-tracking changes, editing an individual set, deleting a set) are committed explicitly rather than relying on SwiftData's implicit autosave — text fields buffer locally and commit on blur/dismiss (avoiding per-keystroke save overhead) while discrete changes like Pickers and DatePickers save immediately.

## PR Tracking
Each exercise can be set to one of three tracking metrics (or left untracked) from its detail screen:
- **Weight** — the classic case, used for barbell lifts. PR is the heaviest working-set weight in a session, tracked across all sessions. Reports include an estimated one-rep max (Epley formula, computed independently of "heaviest set" — a lighter, higher-rep set can win on estimated 1RM even if it isn't the nominal PR) and, if bodyweight is set, a bodyweight-multiple ratio.
- **Reps** — for bodyweight movements. Only sets logged at 0 kg count toward the reps PR, since reps at different added weights aren't directly comparable. If a set with added weight is logged, that's called out separately in reports as a milestone rather than folded into the reps trend.
- **Assisted** — for machine-assisted movements. The weight field is relabeled "Assistance," and the app computes effective load moved as `max(bodyweight − assistance, 0)` — floored at zero so a data-entry mistake (assistance exceeding bodyweight) can't produce a negative training load. Progress means less assistance over time, so PR is the session with the least assistance (highest effective load). Requires bodyweight to be set in Settings.

Bodyweight is entered once in Settings (unit-aware, stored internally in kg) and is used for the bodyweight-ratio line on weight-tracked lifts, effective-load calculations on assisted-tracked exercises, and bodyweight-aware training volume for both reps-tracked and assisted-tracked exercises.

All PR calculation (weight PR, reps PR, assisted effective-load PR, and their trend data) lives in `PRCalculator`, shared between the PR Dashboard and Reports, so a fix or change to PR logic applies consistently everywhere it's shown.
## Plate Calculator & Warm-up Suggester
Both features are scoped to **Deadlift, Bench Press, Squat, and Overhead Press** — the exercises where barbell plate math is actually meaningful. Neither appears for dumbbell, machine, cable, or assisted-tracked exercises.

- **Plate Calculator** takes a target weight and the configured bar weight (default 20 kg, adjustable in Settings) and computes which plates to load per side from a standard Olympic set (25/20/15/10/5/2.5/1.25 kg), using a greedy largest-plate-first algorithm. An optional per-plate inventory limit (Settings → Plate Inventory) constrains the breakdown to plates you actually own; the "limited by inventory" warning only appears when the cap genuinely prevents reaching the target, not whenever a larger plate size happens to be capped but is still coverable by smaller plates. If the exact target still isn't achievable, it shows the closest achievable total instead. Opened from a button next to the weight field in the set editor, for both warm-up and working sets.
- **Warm-up Suggester** generates a standard ramp — bar × 8, 40% × 5, 60% × 3, 80% × 2 — from a target working weight (prefilled from the day's top working set if one's already logged), with each step rounded to a loadable 2.5 kg increment and shown with its own plate breakdown that also respects the configured plate inventory. "Add All" logs the full ramp as warm-up sets in one tap, ordered correctly ahead of working sets.

Both features share the same bar-weight setting, plate-rounding logic, and inventory constraint, and both convert their display to whichever unit (kg/lb) is currently selected while keeping the underlying plate math in real kg plate sizes.
## Repeat Workout
Swiping a past workout (leading edge) offers **Repeat**, which opens a new workout pre-loaded with the same exercises in the same order, including any superset pairing the original had. Only the exercise list (and pairing) is copied — weight, reps, and RPE/RIR are always left blank so each session's numbers are entered fresh. Each exercise shows a "Last time: weight × reps, RPE/RIR" line (pulled from that exercise's heaviest working set in the source workout) as reference while logging today's numbers.
## Rest Timer
Logging a working set (not a warm-up) automatically starts a rest countdown, shown as a floating bar above the tab bar for the duration of the rest period. The bar shows a progress ring, time remaining, a +30s button, and a skip option. A local notification is scheduled in parallel so rest completion is still signaled if the phone is locked or the app is backgrounded. The default duration is set in Settings (30s–5min); pressing and holding "Working Set" on a given exercise offers one-off overrides (90s/2min/3min/5min) for sets that need more or less rest than the default, such as a heavy top set — the override is consumed by that one set and reset immediately after, so it never silently carries over to the next set or exercise. The timer is cancelled on Discard, Save, or leaving the workout screen, so no stray notification fires after a workout is finished or abandoned.

Superset rest behavior: paired exercises don't rest between each other — the timer only starts once both exercises in the pair have logged the same number of working sets for that round (i.e. the round is complete), regardless of which exercise is logged first, how many total sets each ends up with, or whether the pair is later unlinked or one half deleted (both cases fall back to standalone-exercise behavior: always rest).
## Consistency Tracking
The Workouts tab opens with a heat-map card showing daily training activity over a rolling ~20-week window, horizontally scrollable to see further back. Each day's square intensity reflects how many working sets were logged that day, not just whether you trained. Alongside the grid: your current weekly streak (weeks in a row with at least one workout, shown with a flame while active), longest streak on record, and average sessions per week — normalized to however many weeks you've actually been logging, and bounded so a future-dated workout can't inflate either the streak or the average.
## Search & Filter
The Workouts tab supports searching by workout name or formatted date, and filtering the list down to workouts containing a specific exercise (via a menu listing only exercises you've actually used). Search and filter combine, and a dismissible chip shows the active exercise filter. A dedicated empty state distinguishes "no results for this search/filter" from "no workouts logged yet."
## Reports
Reports are generated on demand for any date range — inclusive of the entire selected end date, not just midnight of it — using only the sets already logged. Every exercise with PR tracking enabled gets a progress card, styled to its metric:
- **Weight-tracked exercises**: top-set weight progression (starting-period session vs. period-best), estimated one-rep max with its source set shown explicitly, and bodyweight ratio if set.
- **Reps-tracked exercises**: bodyweight rep progression (starting-period session vs. period-best), plus a called-out milestone if external weight was added during the period.
- **Assisted-tracked exercises**: effective-load progression (starting-period session vs. period-best) as assistance decreases.

The Strength/Bodybuilding focus toggle changes the surrounding narrative rather than which exercises appear: Strength focus adds 1RM and bodyweight-ratio detail to weight-tracked lifts; Bodybuilding focus adds weekly volume trend and training-frequency insights alongside the same per-exercise progress cards. Volume figures (both the report total and the weekly breakdown) use the same bodyweight-aware training-volume calculation as the rest of the app, so bodyweight/assisted sessions contribute correctly instead of reading as zero.

Both modes identify the week with the lowest average effort and highest average effort, based on a normalized 0–10 scale combining RPE and RIR — described as "effort" throughout, not "RPE," since the underlying score may be derived from either. A deload signal flags a weight-tracked exercise where effort has risen for three genuinely consecutive calendar weeks (not just three weeks with data, gapped or not) while top-set weight hasn't increased across any consecutive pair in that window, not just the first vs. last week.
## Apple Health Sync
Optional, off by default. When enabled in Settings:
- Completed workouts are written to Apple Health as strength-training sessions, using the workout's real session start/end time (not an estimate) and a MET-based active-energy estimate (METs × bodyweight × duration) using your configured bodyweight when available.
- A "Sync Bodyweight from Health" button in Settings pulls your most recent logged bodyweight from Health into the app.

Both directions require their own HealthKit authorization (workout write and active-energy write are separate permissions from Apple's side); the toggle only reports success once both are actually granted, and a failed sync is surfaced as a dismissible banner in Settings rather than failing silently.
## Backup & Restore
Since the app has no cloud sync and all data lives only in local SwiftData storage on-device, Settings includes an **Export Backup** / **Import Backup** pair to guard against losing data on a reinstall, app update, or new phone.
- **Export** writes a versioned, human-readable JSON file containing every exercise (name, category, PR tracking metric, notes) and every workout (stable id, session timing, all sets with weight/reps/RPE/RIR, and superset pairing), via the standard iOS file picker — saving to iCloud Drive is recommended so the backup survives independently of the app itself.
- **Import** reads a previously exported file and offers a choice of two modes:
  - **Replace All Data** — deletes everything currently in the app, then restores exactly what's in the backup, as a single atomic operation: a failure partway through the rebuild rolls back the whole import, including the initial deletion, rather than risking an emptied database. Use this after a reinstall or update.
  - **Merge** — adds the backup's workouts on top of what's already in the app. Workouts are matched by their stable id (falling back to a best-effort content signature — date, name, and exercise list — for backups exported before the id field existed), so re-importing the same file doesn't duplicate history. Existing exercises are left untouched rather than overwritten, so merging an older backup can't silently revert a PR-tracking change or note you've made since.
- A backup containing two exercises with the same name is rejected as malformed on import, rather than silently collapsing them into one.
- Older backup files (missing fields added in later versions) decode and migrate forward automatically; a version newer than the app supports is rejected with a clear error rather than attempting a partial import.

Typical update flow: **Export Backup** before updating or reinstalling → **Import Backup → Replace All Data** afterward to restore everything.
## Notes
Weights are stored in kilograms internally. The selected display unit only changes how values are entered and presented, so switching between kg and lb does not rewrite past workout data.

## Future Upgrades

Ideas and improvements I'm considering based on real usage, not yet scheduled:

- **AI-generated report summaries** — improved the generated report by taking into account workout notes, week 10 of strength training blocks being 1RMax week testing, so a drop in volume it's normal, text structure should be cleaner. 
- **Display large training volumes in tonnes** — once total volume passes 10,000 kg, show it in tonnes (T) instead of kg for readability (e.g. 202,199 kg → 202.2T), on the Report tab and anywhere else cumulative volume is shown.
- **Configurable plate-calculator eligibility** — the plate calculator and warm-up suggester currently only activate for a hardcoded list of exercises (Deadlift, Bench Press, Squat, Overhead Press). Make this a per-exercise setting instead, so any barbell lift the user adds can opt in.
- **iCloud sync between devices** — now that export/import backup (merge vs. replace) is solid and well-tested, a natural next step is automatic CloudKit sync instead of manual backup files.
- **Export reports as PDF/CSV** — let a generated report be shared or archived outside the app, not just viewed in-app.
- **Apple Watch companion** — log sets mid-workout without reaching for the phone.
- **PR-to-bodyweight ratio should reflect bodyweight at the time of the lift, not the current value** — the ratio shown on the PR Dashboard and in Reports currently recomputes every existing PR against today's Settings → Bodyweight value, so gaining or losing weight retroactively changes the ratio on lifts from months ago (e.g. 100kg at 90kg bodyweight shows 1.11x today, but if bodyweight later changes to 95kg, that same historical 100kg PR silently redisplays as 1.05x). The fix needs bodyweight to become a timestamped log rather than a single stored value, with each session snapshotting the bodyweight at the time it was logged — so a PR's ratio is fixed at the moment it happened and never moves again just because today's number changed.
- **Bodyweight history/log** — a simple timestamped log of bodyweight entries (manual or pulled from Health) rather than a single current value, so you can see your own weight trend over time, not just your lifts'.
- **Muscle-group tagging on exercises** — `Exercise.category` currently distinguishes "Big 3" vs. "Accessory" but nothing tracks push/pull/legs or specific muscle groups, so Bodybuilding-focus reports can't break volume down by muscle group, only by exercise or overall total.
- **Multiple bar types** — bar weight is a single global Settings value, which doesn't account for a trap bar, safety-squat bar, or women's bar all having different weights; the plate calculator and warm-up suggester would need to know which bar a given exercise uses.
- **Light appearance option** — the app currently forces dark mode (`.preferredColorScheme(.dark)`) as a deliberate design choice for the plate-color theme; worth revisiting if it's ever genuinely wanted, though the current palette was built specifically around a dark background.
- **In-app data validation / integrity check** — a "Check my data" utility in Settings that scans for known-messy states (e.g. a workout with zero exercises left after deletions, a set with implausible weight/rep combinations) and surfaces them, rather than relying on the model-level clamping alone to keep things sane.
- **Cold start lagging** - on a cold start, when the PR view is toggled, the app is lagging. Might need to optimise the charts.
