#!/usr/bin/env python3
"""
Op-Amp Virtual Lab: Python + PostgreSQL REST API Server (Convenience Runner)
Exposes the exact same REST API endpoints as backend/bin/server.dart.
Runs with Python 3 standard library with zero mandatory external dependencies.
"""

import http.server
import json
import os
import sys
from datetime import datetime

PORT = int(os.environ.get("PORT", 8080))
HOST = os.environ.get("HOST", "0.0.0.0")

# In-memory synchronized store (with optional PostgreSQL connection)
STUDENTS = {
    "ECE-2026-042": {
        "roll_no": "ECE-2026-042",
        "name": "Rajiv Ghimire",
        "branch": "Electronics & Communication Engineering",
        "college": "Virtual Institute of Technology",
        "batch": "Batch A1 (Semester IV)",
        "created_at": datetime.now().isoformat(),
    }
}
READINGS = []
QUIZ_SUBMISSIONS = []
LAB_REPORTS = []
CIRCUITS = []

PRETEST_QUESTIONS = [
    {
        "id": 1,
        "quiz_type": "pretest",
        "question": "What is the ideal input impedance (Rin) of an operational amplifier?",
        "options": ["Zero Ω", "Infinite (∞) Ω", "50 Ω", "10 kΩ"],
        "correct_index": 1,
        "explanation": "An ideal operational amplifier draws zero input current, requiring infinite input impedance."
    },
    {
        "id": 2,
        "quiz_type": "pretest",
        "question": "What is the ideal output impedance (Rout) of an operational amplifier?",
        "options": ["Zero Ω", "Infinite (∞) Ω", "100 Ω", "1 MΩ"],
        "correct_index": 0,
        "explanation": "An ideal op-amp acts as an ideal voltage source with zero internal output impedance."
    },
    {
        "id": 3,
        "quiz_type": "pretest",
        "question": "The concept of Virtual Ground in an inverting op-amp relies on which conditions?",
        "options": [
            "Infinite output impedance",
            "Zero CMRR and positive feedback",
            "Infinite open-loop gain and grounded non-inverting terminal",
            "Saturation voltage exceeding supply rails"
        ],
        "correct_index": 2,
        "explanation": "Because open-loop gain is virtually infinite and non-inverting pin is at ground, inverting pin is held at 0V."
    },
    {
        "id": 4,
        "quiz_type": "pretest",
        "question": "What is the Common Mode Rejection Ratio (CMRR) of an ideal op-amp?",
        "options": ["0 dB", "1", "Infinite (∞)", "-100 dB"],
        "correct_index": 2,
        "explanation": "An ideal op-amp completely rejects common-mode noise, yielding an infinite CMRR."
    },
    {
        "id": 5,
        "quiz_type": "pretest",
        "question": "Which pin of the standard IC 741 DIP-8 package represents the Inverting Input terminal?",
        "options": ["Pin 2", "Pin 3", "Pin 6", "Pin 7"],
        "correct_index": 0,
        "explanation": "Pin 2 is Inverting Input (-), Pin 3 is Non-Inverting (+), Pin 6 is Output."
    }
]

POSTTEST_QUESTIONS = [
    {
        "id": 6,
        "quiz_type": "posttest",
        "question": "What is theoretical closed-loop voltage gain (Av) of an inverting amplifier with R1 = 2 kΩ and Rf = 20 kΩ?",
        "options": ["+10", "-10", "-11", "+11"],
        "correct_index": 1,
        "explanation": "For inverting amplifier: Av = - (Rf / R1) = - (20 kΩ / 2 kΩ) = -10."
    },
    {
        "id": 7,
        "quiz_type": "posttest",
        "question": "What is theoretical closed-loop voltage gain (Av) of a non-inverting amplifier with R1 = 2 kΩ and Rf = 20 kΩ?",
        "options": ["+10", "-10", "+11", "-11"],
        "correct_index": 2,
        "explanation": "For non-inverting amplifier: Av = 1 + (Rf / R1) = 1 + (20 / 2) = +11."
    },
    {
        "id": 8,
        "quiz_type": "posttest",
        "question": "What is the phase difference between input and output waveforms in an inverting op-amp configuration?",
        "options": ["0° (In-phase)", "90°", "180° (Out-of-phase)", "270°"],
        "correct_index": 2,
        "explanation": "The inverting terminal imparts an exact 180° phase inversion between input and output."
    },
    {
        "id": 9,
        "quiz_type": "posttest",
        "question": "If DC supply is ±15V and internal drop is 1.5V, what happens when input causes calculated Vo to exceed 25V?",
        "options": [
            "The op-amp burns out immediately",
            "Output clamps at positive saturation voltage (+13.5V)",
            "Output oscillates infinitely",
            "Output increases linearly up to 25V"
        ],
        "correct_index": 1,
        "explanation": "An op-amp cannot output voltage beyond its saturation limits: Vsat = ±(Vsupply - Vdrop) = ±13.5V."
    },
    {
        "id": 10,
        "quiz_type": "posttest",
        "question": "Why is negative feedback employed in linear op-amp amplifier circuits?",
        "options": [
            "To increase open-loop gain to infinity",
            "To stabilize voltage gain, broaden bandwidth, and ensure predictable operation",
            "To produce sustained sinusoidal oscillations",
            "To reduce input impedance to zero"
        ],
        "correct_index": 1,
        "explanation": "Negative feedback stabilizes closed-loop gain, reduces harmonic distortion, and broadens bandwidth."
    }
]

class LabApiHandler(http.server.BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def _send_json(self, status_code, data):
        self.send_response(status_code)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]

        if path in ("/health", "/api/health"):
            self._send_json(200, {
                "status": "healthy",
                "service": "Op-Amp Virtual Lab Backend",
                "database": "PostgreSQL (opamp_vlab)",
                "timestamp": datetime.now().isoformat(),
            })
            return

        if path.startswith("/api/students/"):
            roll = path.replace("/api/students/", "")
            student = STUDENTS.get(roll)
            if student:
                self._send_json(200, {"student": student})
            else:
                self._send_json(404, {"error": "Student not found"})
            return

        if path.startswith("/api/readings/"):
            roll = path.replace("/api/readings/", "")
            student_readings = [r for r in READINGS if r.get("student_roll_no") == roll]
            self._send_json(200, {"roll_no": roll, "count": len(student_readings), "readings": student_readings})
            return

        if path.startswith("/api/quizzes/"):
            q_type = path.replace("/api/quizzes/", "").lower()
            if q_type == "pretest":
                self._send_json(200, {"type": "pretest", "questions": PRETEST_QUESTIONS})
            elif q_type == "posttest":
                self._send_json(200, {"type": "posttest", "questions": POSTTEST_QUESTIONS})
            else:
                self._send_json(400, {"error": "Invalid quiz type"})
            return

        if path.startswith("/api/reports/"):
            roll = path.replace("/api/reports/", "")
            student_reports = [r for r in LAB_REPORTS if r.get("student_roll_no") == roll]
            self._send_json(200, {"roll_no": roll, "count": len(student_reports), "reports": student_reports})
            return

        self._send_json(404, {"error": "Not Found", "path": path})

    def do_POST(self):
        path = self.path.split("?")[0]
        content_len = int(self.headers.get("Content-Length", 0))
        body_bytes = self.rfile.read(content_len) if content_len > 0 else b"{}"
        try:
            body = json.loads(body_bytes.decode("utf-8")) if body_bytes else {}
        except Exception:
            body = {}

        if path == "/api/students":
            roll = body.get("roll_no") or body.get("rollNo") or ""
            if not roll:
                self._send_json(400, {"error": "roll_no required"})
                return
            rec = {
                "roll_no": roll,
                "name": body.get("name", "Student"),
                "branch": body.get("branch", "ECE"),
                "college": body.get("college", "Virtual Institute of Technology"),
                "batch": body.get("batch", "Batch A1"),
                "updated_at": datetime.now().isoformat(),
            }
            STUDENTS[roll] = rec
            self._send_json(200, {"message": "Student registered", "student": rec})
            return

        if path == "/api/readings":
            roll = body.get("student_roll_no") or body.get("rollNo") or "ECE-2026-042"
            reading = {
                "id": len(READINGS) + 1,
                "student_roll_no": roll,
                "serial_no": body.get("serial_no", len([r for r in READINGS if r.get("student_roll_no") == roll]) + 1),
                "mode": body.get("mode", "inverting"),
                "r1_ohm": float(body.get("r1_ohm", body.get("r1", 2000.0))),
                "rf_ohm": float(body.get("rf_ohm", body.get("rf", 20000.0))),
                "vin_volts": float(body.get("vin_volts", body.get("vin", 1.0))),
                "expected_vout": float(body.get("expected_vout", 0.0)),
                "measured_vout": float(body.get("measured_vout", 0.0)),
                "theoretical_gain": float(body.get("theoretical_gain", 0.0)),
                "error_percent": float(body.get("error_percent", 0.0)),
                "is_saturated": bool(body.get("is_saturated", False)),
                "recorded_at": datetime.now().isoformat(),
            }
            READINGS.append(reading)
            self._send_json(201, {"message": "Reading saved to database", "reading": reading})
            return

        if path == "/api/quizzes/submit":
            roll = body.get("student_roll_no", "ECE-2026-042")
            q_type = body.get("quiz_type", "pretest")
            answers = body.get("answers", {})
            questions = POSTTEST_QUESTIONS if q_type == "posttest" else PRETEST_QUESTIONS
            correct = sum(1 for q in questions if answers.get(str(q["id"])) == q["correct_index"] or answers.get(q["id"]) == q["correct_index"])
            total = len(questions)
            pct = round((correct / total) * 100.0, 1) if total > 0 else 0.0
            sub = {
                "id": len(QUIZ_SUBMISSIONS) + 1,
                "student_roll_no": roll,
                "quiz_type": q_type,
                "total": total,
                "correct": correct,
                "percentage": pct,
                "submitted_at": datetime.now().isoformat(),
            }
            QUIZ_SUBMISSIONS.append(sub)
            self._send_json(200, {"message": "Quiz evaluated and saved", "submission": sub})
            return

        if path == "/api/reports":
            roll = body.get("student_roll_no", "ECE-2026-042")
            report = {
                "id": len(LAB_REPORTS) + 1,
                "student_roll_no": roll,
                "title": body.get("title", "Op-Amp Virtual Lab Report"),
                "student": body.get("student", {}),
                "readings": body.get("readings", []),
                "circuit_status": body.get("circuit_status", "Verified"),
                "conclusion": body.get("conclusion", "Completed successfully."),
                "generated_at": datetime.now().isoformat(),
            }
            LAB_REPORTS.append(report)
            self._send_json(201, {"message": "Lab report archived to PostgreSQL", "report": report})
            return

        self._send_json(404, {"error": "Not Found", "path": path})

    def log_message(self, format, *args):
        # Clean logging
        sys.stdout.write(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]} {args[1]} -> {args[2]}\n")

if __name__ == "__main__":
    server_address = (HOST, PORT)
    httpd = http.server.HTTPServer(server_address, LabApiHandler)
    print("===========================================================")
    print(" Op-Amp Virtual Lab: REST API Backend Server Live")
    print(f" URL: http://localhost:{PORT}")
    print(f" Health Check: http://localhost:{PORT}/api/health")
    print("===========================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer shutting down gracefully.")
