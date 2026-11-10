#!/usr/bin/env python3
"""
Op-Amp Virtual Lab: PostgreSQL Database Inspector
Connects to PostgreSQL (opamp_vlab) and prints all stored data.
"""

import sys
import psycopg2
import psycopg2.extras

DB_CONFIG = {
    "dbname": "opamp_vlab",
    "user": "postgres",
    "password": "postgres",
    "host": "127.0.0.1",
    "port": 5432,
}

def print_separator(title=""):
    print("\n" + "=" * 70)
    if title:
        print(f"  {title}")
        print("=" * 70)

def main():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
    except Exception as e:
        print(f"\n[ERROR] Unable to connect to PostgreSQL: {e}")
        print("Please make sure PostgreSQL is running on port 5432.")
        sys.exit(1)

    print_separator("OP-AMP VIRTUAL LAB - POSTGRESQL DATABASE INSPECTOR")
    print(f"Connected to: {DB_CONFIG['dbname']} (Port {DB_CONFIG['port']}) as '{DB_CONFIG['user']}'")

    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        # 1. Students
        print_separator("1. REGISTERED STUDENTS (Table: students)")
        cur.execute("SELECT roll_no, name, branch, batch, college, created_at FROM students ORDER BY created_at DESC;")
        students = cur.fetchall()
        if not students:
            print("  (No student records found yet)")
        else:
            for s in students:
                print(f"  - Roll No: {s['roll_no']} | Name: {s['name']}")
                print(f"    Branch : {s['branch']} | Batch: {s['batch']}")
                print(f"    College: {s['college']}")
                print(f"    Joined : {s['created_at']}")
                print("    " + "-" * 50)

        # 2. Experiment Readings
        print_separator("2. OBSERVATION TABLE READINGS (Table: experiment_readings)")
        cur.execute("""
            SELECT id, student_roll_no, serial_no, mode, r1_ohm, rf_ohm, vin_volts,
                   expected_vout, measured_vout, theoretical_gain, error_percent, is_saturated, recorded_at
            FROM experiment_readings
            ORDER BY student_roll_no, serial_no ASC;
        """)
        readings = cur.fetchall()
        if not readings:
            print("  (No observation readings saved yet)")
        else:
            print(f"  {'#':<3} | {'Student Roll':<14} | {'Mode':<12} | {'Vin (V)':<8} | {'Vout (V)':<9} | {'Gain':<6} | {'Sat?':<5} | {'Recorded At'}")
            print("  " + "-" * 75)
            for r in readings:
                sat_flag = "YES" if r['is_saturated'] else "NO"
                print(f"  {r['serial_no']:<3} | {r['student_roll_no']:<14} | {r['mode']:<12} | {float(r['vin_volts']):<8.2f} | {float(r['measured_vout']):<9.2f} | {float(r['theoretical_gain']):<6.1f} | {sat_flag:<5} | {r['recorded_at'].strftime('%Y-%m-%d %H:%M')}")

        # 3. Circuit Verifications
        print_separator("3. CIRCUIT VERIFICATIONS (Table: circuit_verifications)")
        cur.execute("""
            SELECT id, student_roll_no, experiment_id, mode, is_complete, verified_at
            FROM circuit_verifications
            ORDER BY verified_at DESC;
        """)
        circuits = cur.fetchall()
        if not circuits:
            print("  (No circuit verifications saved yet)")
        else:
            for c in circuits:
                status = "COMPLETE (Verified)" if c['is_complete'] else "INCOMPLETE"
                print(f"  - ID: {c['id']} | Student: {c['student_roll_no']} | Mode: {c['mode']} | Status: {status} | Date: {c['verified_at']}")

        # 4. Lab Reports
        print_separator("4. GENERATED LAB REPORTS (Table: lab_reports)")
        cur.execute("""
            SELECT id, student_roll_no, report_title, experiment_date, circuit_status, generated_at
            FROM lab_reports
            ORDER BY generated_at DESC;
        """)
        reports = cur.fetchall()
        if not reports:
            print("  (No lab reports generated yet)")
        else:
            for rep in reports:
                print(f"  - Report #{rep['id']} | Roll: {rep['student_roll_no']}")
                print(f"    Title  : {rep['report_title']}")
                print(f"    Status : {rep['circuit_status']} | Date: {rep['experiment_date']}")
                print("    " + "-" * 50)

        # 5. Quiz Questions Summary
        print_separator("5. QUIZ QUESTIONS IN DATABASE (Table: quiz_questions)")
        cur.execute("SELECT quiz_type, count(*) as count FROM quiz_questions GROUP BY quiz_type;")
        quizzes = cur.fetchall()
        for q in quizzes:
            print(f"  - {q['quiz_type'].capitalize()} Quiz: {q['count']} questions available")

    conn.close()
    print_separator("END OF DATABASE INSPECTION")

if __name__ == "__main__":
    main()
