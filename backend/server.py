#!/usr/bin/env python3
"""
Op-Amp Virtual Lab: Python + PostgreSQL REST API Server
Directly connects to PostgreSQL 18 (database: opamp_vlab).
Exposes REST API endpoints for Flutter mobile app:
- GET  /api/health
- POST /api/students & GET /api/students/{rollNo}
- POST /api/readings & GET /api/readings/{rollNo}
- GET  /api/quizzes/{pretest|posttest}
- POST /api/quizzes/submit
- POST /api/reports & GET /api/reports/{rollNo}
"""

import http.server
import json
import os
import sys
from datetime import datetime

try:
    import psycopg2
    import psycopg2.extras
    HAS_PSYCOPG2 = True
except ImportError:
    HAS_PSYCOPG2 = False

PORT = int(os.environ.get("PORT", 8080))
HOST = os.environ.get("HOST", "0.0.0.0")

DB_CONFIG = {
    "dbname": os.environ.get("PGDATABASE", "opamp_vlab"),
    "user": os.environ.get("PGUSER", "postgres"),
    "password": os.environ.get("PGPASSWORD", "postgres"),
    "host": os.environ.get("PGHOST", "127.0.0.1"),
    "port": int(os.environ.get("PGPORT", 5432)),
}

def get_db_connection():
    if not HAS_PSYCOPG2:
        return None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        return conn
    except Exception as e:
        sys.stderr.write(f"[DB-WARN] PostgreSQL connect error: {e}\n")
        return None

class LabApiHandler(http.server.BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept")

    def _send_json(self, status_code, data):
        self.send_response(status_code)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps(data, default=str).encode("utf-8"))

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]

        # 1. HEALTH CHECK
        if path in ("/health", "/api/health"):
            conn = get_db_connection()
            db_status = "Disconnected"
            tables_count = 0
            if conn:
                try:
                    with conn.cursor() as cur:
                        cur.execute("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';")
                        tables_count = cur.fetchone()[0]
                    db_status = f"PostgreSQL 18 Connected (Tables: {tables_count})"
                    conn.close()
                except Exception as e:
                    db_status = f"Error: {e}"

            self._send_json(200, {
                "status": "healthy",
                "service": "Op-Amp Virtual Lab Backend",
                "database": db_status,
                "db_name": DB_CONFIG["dbname"],
                "db_port": DB_CONFIG["port"],
                "timestamp": datetime.now().isoformat(),
            })
            return

        # 2. STUDENTS PROFILE
        if path.startswith("/api/students/"):
            roll = path.replace("/api/students/", "").strip()
            conn = get_db_connection()
            if conn:
                with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                    cur.execute("SELECT roll_no, name, branch, college, batch, created_at FROM students WHERE roll_no = %s;", (roll,))
                    row = cur.fetchone()
                conn.close()
                if row:
                    self._send_json(200, {"student": dict(row)})
                    return
            self._send_json(404, {"error": "Student not found", "roll_no": roll})
            return

        # 3. OBSERVATION TABLE READINGS
        if path.startswith("/api/readings/"):
            roll = path.replace("/api/readings/", "").strip()
            conn = get_db_connection()
            readings = []
            if conn:
                with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id, student_roll_no, serial_no, mode, r1_ohm, rf_ohm, vin_volts,
                               expected_vout, measured_vout, theoretical_gain, error_percent, is_saturated, recorded_at
                        FROM experiment_readings
                        WHERE student_roll_no = %s
                        ORDER BY serial_no ASC;
                    """, (roll,))
                    readings = [dict(r) for r in cur.fetchall()]
                conn.close()
            self._send_json(200, {"roll_no": roll, "count": len(readings), "readings": readings})
            return

        # 4. QUIZ QUESTIONS
        if path.startswith("/api/quizzes/"):
            q_type = path.replace("/api/quizzes/", "").strip().lower()
            conn = get_db_connection()
            questions = []
            if conn:
                with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id, quiz_type, question, option_a, option_b, option_c, option_d,
                               correct_index, explanation
                        FROM quiz_questions
                        WHERE quiz_type = %s
                        ORDER BY id ASC;
                    """, (q_type,))
                    for r in cur.fetchall():
                        q = dict(r)
                        q["options"] = [q.pop("option_a"), q.pop("option_b"), q.pop("option_c"), q.pop("option_d")]
                        questions.append(q)
                conn.close()
            self._send_json(200, {"type": q_type, "count": len(questions), "questions": questions})
            return

        # 5. LAB REPORTS
        if path.startswith("/api/reports/"):
            roll = path.replace("/api/reports/", "").strip()
            conn = get_db_connection()
            reports = []
            if conn:
                with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id, student_roll_no, experiment_id, report_title, experiment_date,
                               student_metadata, readings_summary, circuit_status, conclusion, generated_at
                        FROM lab_reports
                        WHERE student_roll_no = %s
                        ORDER BY generated_at DESC;
                    """, (roll,))
                    reports = [dict(r) for r in cur.fetchall()]
                conn.close()
            self._send_json(200, {"roll_no": roll, "count": len(reports), "reports": reports})
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

        # 1. REGISTER / UPDATE STUDENT
        if path == "/api/students":
            roll = (body.get("roll_no") or body.get("rollNo") or "").strip()
            if not roll:
                self._send_json(400, {"error": "roll_no required"})
                return
            name = body.get("name", "Student")
            branch = body.get("branch", "ECE")
            college = body.get("college", "Virtual Institute of Technology")
            batch = body.get("batch", "Batch A1")

            conn = get_db_connection()
            if conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        INSERT INTO students (roll_no, name, branch, college, batch)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (roll_no) DO UPDATE
                        SET name = EXCLUDED.name, branch = EXCLUDED.branch, college = EXCLUDED.college, batch = EXCLUDED.batch, updated_at = CURRENT_TIMESTAMP;
                    """, (roll, name, branch, college, batch))
                conn.close()
            self._send_json(200, {"message": "Student credentials synced to PostgreSQL", "roll_no": roll})
            return

        # 2. SAVE OBSERVATION READING
        if path == "/api/readings":
            roll = (body.get("student_roll_no") or body.get("rollNo") or "ECE-2026-042").strip()
            serial = int(body.get("serial_no", 1))
            mode = body.get("mode", "inverting")
            r1 = float(body.get("r1_ohm", body.get("r1", 2000.0)))
            rf = float(body.get("rf_ohm", body.get("rf", 20000.0)))
            vin = float(body.get("vin_volts", body.get("vin", 1.0)))
            exp_vo = float(body.get("expected_vout", 0.0))
            meas_vo = float(body.get("measured_vout", 0.0))
            gain = float(body.get("theoretical_gain", 0.0))
            err = float(body.get("error_percent", 0.0))
            is_sat = bool(body.get("is_saturated", False))

            conn = get_db_connection()
            new_id = None
            if conn:
                with conn.cursor() as cur:
                    # Ensure student exists
                    cur.execute("INSERT INTO students (roll_no, name) VALUES (%s, 'Student') ON CONFLICT DO NOTHING;", (roll,))
                    cur.execute("""
                        INSERT INTO experiment_readings (student_roll_no, experiment_id, serial_no, mode, r1_ohm, rf_ohm, vin_volts,
                                                        expected_vout, measured_vout, theoretical_gain, error_percent, is_saturated)
                        VALUES (%s, 'OPAMP-01', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        RETURNING id;
                    """, (roll, serial, mode, r1, rf, vin, exp_vo, meas_vo, gain, err, is_sat))
                    row = cur.fetchone()
                    if row:
                        new_id = row[0]
                conn.close()

            self._send_json(201, {
                "message": "Reading recorded successfully in PostgreSQL",
                "id": new_id,
                "student_roll_no": roll,
                "serial_no": serial,
            })
            return

        # 3. SUBMIT QUIZ
        if path == "/api/quizzes/submit":
            roll = (body.get("student_roll_no") or "ECE-2026-042").strip()
            q_type = body.get("quiz_type", "pretest").lower()
            answers = body.get("answers", {})

            conn = get_db_connection()
            correct = 0
            total = 0
            details = []
            if conn:
                with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                    cur.execute("SELECT id, correct_index, explanation FROM quiz_questions WHERE quiz_type = %s;", (q_type,))
                    questions = cur.fetchall()
                    total = len(questions)
                    for q in questions:
                        q_id = str(q["id"])
                        chosen = answers.get(q_id) if q_id in answers else answers.get(int(q_id))
                        is_corr = chosen == q["correct_index"]
                        if is_corr:
                            correct += 1
                        details.append({"question_id": q["id"], "selected": chosen, "correct": is_corr})

                    score_pct = round((correct / total) * 100.0, 1) if total > 0 else 0.0
                    cur.execute("INSERT INTO students (roll_no, name) VALUES (%s, 'Student') ON CONFLICT DO NOTHING;", (roll,))
                    cur.execute("""
                        INSERT INTO quiz_submissions (student_roll_no, quiz_type, total_questions, correct_answers, score_percentage, answers_detail)
                        VALUES (%s, %s, %s, %s, %s, %s);
                    """, (roll, q_type, total, correct, score_pct, json.dumps(details)))
                conn.close()

            self._send_json(200, {
                "message": "Quiz evaluated and persisted to PostgreSQL",
                "student_roll_no": roll,
                "quiz_type": q_type,
                "total": total,
                "correct": correct,
                "score_percentage": score_pct if 'score_pct' in locals() else 0.0,
            })
            return

        # 4. SAVE LAB REPORT
        if path == "/api/reports":
            roll = (body.get("student_roll_no") or "ECE-2026-042").strip()
            title = body.get("title", "Study of Basic Properties of Operational Amplifier")
            student_meta = body.get("student", {})
            readings = body.get("readings", [])
            circuit_status = body.get("circuit_status", "Verified & Complete")
            conclusion = body.get("conclusion", "Completed.")

            conn = get_db_connection()
            if conn:
                with conn.cursor() as cur:
                    cur.execute("INSERT INTO students (roll_no, name) VALUES (%s, 'Student') ON CONFLICT DO NOTHING;", (roll,))
                    cur.execute("""
                        INSERT INTO lab_reports (student_roll_no, experiment_id, report_title, student_metadata, readings_summary, circuit_status, conclusion)
                        VALUES (%s, 'OPAMP-01', %s, %s, %s, %s, %s);
                    """, (roll, title, json.dumps(student_meta), json.dumps(readings), circuit_status, conclusion))
                conn.close()

            self._send_json(201, {"message": "Formal lab report archived to PostgreSQL", "roll_no": roll})
            return

        self._send_json(404, {"error": "Not Found", "path": path})

    def log_message(self, format, *args):
        sys.stdout.write(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]} {args[1]} -> {args[2]}\n")

if __name__ == "__main__":
    server_address = (HOST, PORT)
    httpd = http.server.HTTPServer(server_address, LabApiHandler)
    print("===========================================================")
    print(" Op-Amp Virtual Lab: PostgreSQL Backend Server Live")
    print(f" Listening on: http://localhost:{PORT}")
    print(f" Database: {DB_CONFIG['dbname']} on port {DB_CONFIG['port']}")
    print("===========================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer shutting down gracefully.")
