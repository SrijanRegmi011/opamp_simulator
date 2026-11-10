# ⚡ Op-Amp Virtual Lab: Inverting & Non-Inverting Operational Amplifier Simulator

[![Flutter Android APK Build](https://github.com/SrijanRegmi011/opamp_simulator/actions/workflows/build_apk.yml/badge.svg)](https://github.com/SrijanRegmi011/opamp_simulator/actions/workflows/build_apk.yml)
[![PostgreSQL 16](https://img.shields.io/badge/Database-PostgreSQL_16-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)

An engineering virtual laboratory application designed for Electronics and Communication Engineering (ECE) students to study the fundamental closed-loop and saturation properties of the **IC 741 Operational Amplifier**.

---

## 📱 Android Mobile APK Download

### Direct Download Link:
👉 **[Download app-release.apk](https://github.com/SrijanRegmi011/opamp_simulator/releases/latest/download/app-release.apk)**

> [!TIP]
> The release APK is automatically compiled and published on every commit using the **GitHub Actions CI/CD Pipeline** (`.github/workflows/build_apk.yml`).

### How to Install on Android:
1. Download the `app-release.apk` file directly on your Android smartphone.
2. Tap the downloaded file in your browser or **Files > Downloads** folder.
3. If prompted by Android security, select **Settings** and allow **Install Unknown Apps** (or tap **Install Anyway**).
4. Launch **Op-Amp Virtual Lab** and explore!

---

## 🔬 Key Experiment & Simulation Features

1. **Realistic Drag-and-Drop Breadboard Workbench:**
   - Accurate pinout representation for **IC 741 DIP-8**:
     - Pin 2: Inverting Input $(-)$
     - Pin 3: Non-Inverting Input $(+)$
     - Pin 4: Negative Supply Rail $(-V_{ee} = -15\text{V})$
     - Pin 6: Output $(V_o)$
     - Pin 7: Positive Supply Rail $(+V_{cc} = +15\text{V})$
   - Precision components: Input Resistor $R_1$, Feedback Resistor $R_f$, Dual DC Power Supply, Signal Source $V_{in}$, Earth Ground, and Digital Voltmeter.
   - Interactive bezier-curve wiring system with pin connection validation and error alerts.
   - **Auto-Wire Mode** for quick verification of theoretical operation.

2. **Mathematical Precision & Saturation Clamping:**
   - **Inverting Configuration:**
     $$A_v = - \frac{R_f}{R_1}, \quad V_o = - \left(\frac{R_f}{R_1}\right) \cdot V_{in}$$
     Imparts a $180^\circ$ phase inversion.
   - **Non-Inverting Configuration:**
     $$A_v = 1 + \frac{R_f}{R_1}, \quad V_o = \left(1 + \frac{R_f}{R_1}\right) \cdot V_{in}$$
     Maintains exact zero-degree phase alignment.
   - **Hardware Rail Saturation:**
     $$V_{sat} = \pm (|V_{cc}| - V_{drop}) = \pm (15\text{V} - 1.5\text{V}) = \pm 13.5\text{V}$$
     Output clamps non-linearly when the mathematical product exceeds $\pm 13.5\text{V}$.

3. **Dual-Trace Oscilloscope & Voltage Transfer Curve:**
   - Real-time animated sinusoidal signal simulation for both input $V_{in}(t)$ and amplified output $V_o(t)$.
   - Dynamic transfer curve ($V_o$ vs $V_{in}$) highlighting the linear operating range and clipped saturation knees.

4. **Observation Table Logging & CSV Export:**
   - Logs $V_{in}$, $R_1$, $R_f$, theoretical $V_o$, measured $V_o$, gain error $\%$, and amplifier state.
   - 1-click clipboard CSV export.

5. **Formal Engineering Lab Report Generator:**
   - Automatically compiles student metadata, apparatus, circuit diagrams, recorded observations, and calculation conclusions.
   - Print & PDF export ready for academic submission.

6. **Dynamic Randomized Pretest & Posttest Quizzes:**
   - Parameterized question generation covering op-amp fundamentals, virtual ground, bandwidth, CMRR, and closed-loop gains.

---

## 🗄️ PostgreSQL Database Architecture

The backend database is designed with **PostgreSQL 16**, storing student records, laboratory observations, circuit verifications, and quiz submissions.

```
┌─────────────────────────┐       ┌───────────────────────────────┐
│        students         │       │          experiments          │
├─────────────────────────┤       ├───────────────────────────────┤
│ roll_no (PK)            │       │ experiment_id (PK)            │
│ name                    │       │ title, code, aim              │
│ branch, college, batch  │       │ r1_default, rf_default        │
│ created_at, updated_at  │       │ vcc, vee, v_sat               │
└────────────┬────────────┘       └───────────────┬───────────────┘
             │ 1                                  │ 1
             │                                    │
             ├──────────────┬─────────────────────┤
             │ N            │ N                   │ N
┌────────────▼────────────┐ │ ┌───────────────────▼───────────┐ ┌─▼──────────────────────┐
│   experiment_readings   │ │ │       circuit_verifications   │ │      lab_reports        │
├─────────────────────────┤ │ ├───────────────────────────────┤ ├─────────────────────────┤
│ id (PK)                 │ │ │ id (PK)                       │ │ id (PK)                 │
│ student_roll_no (FK)    │ │ │ student_roll_no (FK)          │ │ student_roll_no (FK)    │
│ serial_no, mode         │ │ │ mode, wires_data (JSONB)      │ │ report_title, date      │
│ r1_ohm, rf_ohm          │ │ │ is_complete, missing_conns    │ │ readings_summary (JSONB)│
│ vin_volts, expected_vo  │ │ │ verified_at                   │ │ conclusion              │
│ measured_vo, is_sat     │ │ └───────────────────────────────┘ └─────────────────────────┘
│ recorded_at             │ │
└─────────────────────────┘ │
             ┌──────────────┴──────────────┐
             │ N                           │
┌────────────▼────────────┐ ┌──────────────▼──────────────────┐
│    quiz_submissions     │ │         quiz_questions          │
├─────────────────────────┤ ├─────────────────────────────────┤
│ id (PK)                 │ │ id (PK), quiz_type (pre/post)   │
│ student_roll_no (FK)    │ │ question, option_a..d           │
│ quiz_type, total, score │ │ correct_index, explanation      │
│ details_json (JSONB)    │ └─────────────────────────────────┘
└─────────────────────────┘
```

### Starting the PostgreSQL Database with Docker:
```bash
docker compose -f backend/docker-compose.yml up -d
```
- **PostgreSQL Database:** `localhost:5432` (Database: `opamp_vlab`, User: `postgres`, Password: `postgrespassword`)
- **pgAdmin Web Console:** `http://localhost:5050` (Email: `admin@vlab.edu`, Password: `adminpassword`)
- Automatic schema initialization runs `backend/db/schema.sql` on startup.

---

## 🚀 Dart Backend REST API Server

A pure **Dart HTTP server** connects the Flutter application to PostgreSQL.

### Starting the Backend:
```bash
dart run backend/bin/server.dart
```

### Endpoints Reference:
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | Server & Database connectivity health check |
| `POST` | `/api/students` | Register or update student credentials |
| `GET` | `/api/students/{rollNo}` | Fetch student profile |
| `POST` | `/api/readings` | Save observation table reading to PostgreSQL |
| `GET` | `/api/readings/{rollNo}` | Fetch all readings logged by student |
| `DELETE` | `/api/readings/{rollNo}` | Clear reading observations for student |
| `POST` | `/api/circuits/verify` | Validate breadboard wiring against rules |
| `GET` | `/api/quizzes/{type}` | Get questions for `pretest` or `posttest` |
| `POST` | `/api/quizzes/submit` | Evaluate and persist quiz scores |
| `POST` | `/api/reports` | Archive generated lab report snapshot |
| `GET` | `/api/reports/{rollNo}` | Retrieve archived lab reports |
| `GET` | `/api/summary/{rollNo}` | Dashboard analytical summary |

---

## 💻 Running the Flutter Application Locally

### Prerequisites:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.0.0)
- Android Studio or VS Code with Flutter extension

### Build & Run Commands:
```bash
# 1. Install dependencies
flutter pub get

# 2. Run unit and simulation mathematics tests
flutter test

# 3. Run application on connected device or emulator
flutter run

# 4. Build Android Release APK
flutter build apk --release
```
The output APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📂 Project Directory Structure

```
├── .github/
│   └── workflows/
│       └── build_apk.yml          # Automated CI/CD pipeline for Android APK
├── android/                       # Native Android project configuration
├── backend/
│   ├── bin/
│   │   ├── server.dart            # Pure Dart REST API Backend Server
│   │   └── init_db.dart           # Database migration & initialization runner
│   ├── db/
│   │   └── schema.sql             # PostgreSQL DDL tables, views, triggers & seeds
│   ├── docker-compose.yml         # 1-command PostgreSQL 16 + pgAdmin container setup
│   └── pubspec.yaml               # Backend Dart package specification
├── lib/
│   ├── services/
│   │   └── api_service.dart       # Dart HTTP client connecting to PostgreSQL API
│   └── main.dart                  # Complete Virtual Lab UI, physics engine & state
├── test/
│   ├── simulation_math_test.dart  # Unit tests for Inverting, Non-Inverting & Saturation
│   └── widget_test.dart           # Smoke UI widget tests
├── .gitignore                     # Git ignore rules for Flutter, Dart, & PostgreSQL
├── analysis_options.yaml          # Dart code analyzer and lint configuration
├── pubspec.yaml                   # Flutter application dependencies & metadata
└── README.md                      # Comprehensive project documentation
```

---

## 👥 Contributors & Academic Context

- **Course:** Linear Integrated Circuits & Electronics Laboratory
- **Author / Student:** Rajiv Ghimire / Srijan Regmi
- **Institution:** Department of Electronics & Communication Engineering
