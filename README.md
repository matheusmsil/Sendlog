# Sendlog

An iPhone app for logging climbing and strength training, with Apple Watch workout data pulled from Apple Health.

## Features

- **Strength sessions**: exercises with sets (weight in kg + reps). "Add set" repeats the previous set; volume is totalled per exercise.
- **Climbing sessions**: built from *blocks*, each with a format and an optional variation:
  - **Circuit**: each boulder once
  - **Repeats**: each boulder N times (e.g. 5 boulders × 2, one leg)
  - **Projecting**: count attempts and mark sends
  - **Free climbing**
  Tap the circles on a boulder to tick off each ascent.
- **Apple Watch**: import a recent workout as a new session, or link one to an existing session (duration, active energy, avg/max heart rate).
- **Activation & mobility blocks** in any session: pick from presets (scapular pull-ups, finger rolls, frog stretch…) or add your own, set sets × reps/time and tick them off.
- **Portuguese (pt-BR)** interface, keeping climbing jargon in English.
- **Plans with weekdays**: **Treino de hoje** on the Log page starts the day's plan in one tap.
- **Gym** field on each session.
- **iCloud backup**: training and plans sync to the user's iCloud (Apple ID on the iPhone), so changing phones keeps the data. Apple Health stats stay on the device.
- **Plans (templates)**: write the sessions your coach sends once (blocks, boulders, sets, weights, coach notes) and tap **Start** to log that day's session. Also available from **+ › Start a plan** on the Log page, or save any logged session as a plan from its ••• menu.
- **Log periods**: the Log page summary and list can show a week, month, 3 months or a year, with arrows to go back through earlier periods.
- **Boulder tags**: wall angle, hold types and flash, for style analysis.
- **Progress tab** with four dashboards (4 weeks to 1 year, tap any mark for details):
  - **Overview**: sessions, training time, week streak, effort, activation/mobility habits.
  - **Climbing**: hardest/flash/consolidated grade, grade pyramid with advice, grade progression, attempts to send, send rate by wall angle and hold type with a "train next" weakness, project tracker.
  - **Load**: training load (RPE × minutes), acute:chronic load ratio with injury-risk zones, training calendar.
  - **Strength**: hangboard and weighted pull-up strength-to-weight, per-exercise best set, estimated 1RM and volume.
- Swipe a session → **Repeat** to start a new one with the same exercises/boulders.

## Running

Open `Sendlog.xcodeproj` in Xcode (iOS 18+). To run on your iPhone, select your team under
*Signing & Capabilities* and change the bundle identifier if needed; HealthKit requires a real device
with paired Apple Watch data to show workouts.

### Sample data (debug builds)

Launch with the `-seedSampleData` argument (Xcode: Product › Scheme › Edit Scheme › Run › Arguments) to fill an
empty database with 12 weeks of example training. `-openProgress` starts on the Progress tab; `-dashboard climbing` (or `load`, `strength`) picks a dashboard.

## Publishing

See [app-store/README.md](app-store/README.md) for the App Store listing, screenshots, privacy answers and the step-by-step release checklist. Support and privacy pages live in `site/` (GitHub Pages).
