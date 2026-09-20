# AttendX — Secure Attendance. Smarter Campus.

A Flutter mobile UI for a university attendance system, built as a final-year
project MVP. Two roles — **Student** and **Lecturer** — with full navigation,
a mocked-but-realistic mark-attendance flow (QR → BLE → face/liveness →
success), a lecturer live QR session screen, offline-state UI, and a reusable
design system. No backend is wired up yet — everything runs on mock
services that implement clean abstract interfaces, so a real backend can be
plugged in later without touching any screen.

## 1. Getting the project running

This repo was generated as a **pure Dart/Flutter `lib/` package** (no
`android/`, `ios/`, etc. platform folders, since those are large,
machine-generated binaries that can't be authored by hand). Adding them
takes one command:

```bash
cd attendx

# 1. Generate the platform folders (android, ios, etc.) for this existing project.
#    This does NOT touch lib/ or pubspec.yaml — it's the officially supported
#    way to add platform support to a project that started as Dart-only.
flutter create .

# 2. Get packages
flutter pub get

# 3. Run it
flutter run
```

If `flutter create .` asks about an org identifier, any value works for the
demo (e.g. `com.example.attendx`).

## 2. Demo login

The login screen accepts any email/ID with a password of 4+ characters.

- To sign in as a **student**: use any identifier, e.g. `student@uni.edu.ng`
- To sign in as a **lecturer**: include "staff" or "lec" in the identifier,
  e.g. `staff@uni.edu.ng`

Registration works the same way — pick a role at the top of the form.

## 3. Project structure

```
lib/
  core/
    theme/          # Colors, typography, component theming (AppTheme)
    constants/       # App-wide constants (name, tagline, default threshold)
    router/          # go_router top-level route table
    state/           # AppState — session + service locator (ChangeNotifier)
  features/
    auth/            # Splash, Login, Register
    student/         # Student shell + Home, Courses, Attendance, Profile
    lecturer/         # Lecturer shell + Dashboard, Courses, Sessions, Records, Export, Profile
  shared/
    models/          # User/Student/Lecturer, Course, AttendanceSession, AttendanceRecord, etc.
    services/        # Abstract service interfaces + Mock*Service implementations
    mock/            # Centralized mock/demo data (MockData) — delete once backend is live
    widgets/         # Reusable design-system components
```

## 4. Swapping in a real backend

Every piece of data in the app flows through an abstract service interface
in `lib/shared/services/`:

- `AuthService` — login, register, logout
- `CourseService` — fetch/create/update courses
- `AttendanceService` — student attendance history + recording attendance
- `SessionService` — lecturer live session start/pause/end + live counts
- `VerificationService` — the QR → BLE → identity → attendance pipeline
- `SyncService` — offline/online + background sync state
- `ExportService` — CSV/Excel export generation

Each currently has a `Mock*Service` implementation (in-memory, with
simulated network delay). To connect a real backend:

1. Create a new class implementing the relevant interface, e.g.
   `RestCourseService implements CourseService`, calling your REST API.
2. Swap the instantiation in `lib/core/state/app_state.dart` (the
   `AppState` constructor wires up which implementation is used).

No screen, widget, or model needs to change — they all depend on the
interfaces, not the mock implementations.

### What's mocked vs. real logic

- **QR / TOTP generation and validation** — mocked random hex string,
  rotated every 8s in `MockSessionService`. Swap for real cryptographic
  TOTP once the backend is ready.
- **BLE proximity check** — mocked timed transition in
  `MockVerificationService`. Swap for real BLE RSSI-based proximity.
- **Face / liveness verification** — mocked timed transition in the same
  service. Swap for the real ML pipeline (camera capture + liveness model).
- **Offline sync** — `MockSyncService` exposes `SyncState` and
  `triggerSync()`; wire it to real connectivity + background sync logic.
- **CSV/Excel export** — `MockExportService` returns a fake filename after
  a delay; wire it to real file generation.

## 5. Design system

Reusable components live in `lib/shared/widgets/`:
`AppButton`, `AppTextField`, `CourseCard`, `AttendanceRecordCard`,
`StatisticCard`, `StatusBadge`, `VerificationStepper`, `QrScannerFrame`,
`AttendanceProgress`, `EmptyState`, `ErrorState`, `LoadingState`,
`OfflineBanner`. Colors, spacing and radii are centralized in
`lib/core/theme/`.

## 6. Notes

- Built and reviewed without a local Flutter SDK in this environment, so
  please run `flutter analyze` after `flutter pub get` to catch anything
  version-specific to the Flutter SDK you're using. All imports and class
  references were verified programmatically, but live compilation should
  still be your final check before a defense/demo.
- Target: Android first (Material 3, `NavigationBar`), but layouts use
  relative sizing and should adapt reasonably to other screen sizes.
