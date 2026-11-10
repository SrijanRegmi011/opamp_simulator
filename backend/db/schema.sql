-- =============================================================================
-- OP-AMP VIRTUAL LAB: POSTGRESQL PRODUCTION DATABASE SCHEMA
-- EC Laboratory Project: Inverting & Non-Inverting Op-Amp Virtual Simulation
-- =============================================================================

-- Ensure UUID generation extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1. STUDENTS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS students (
    roll_no VARCHAR(50) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    branch VARCHAR(120) NOT NULL DEFAULT 'Electronics & Communication Engineering',
    college VARCHAR(180) NOT NULL DEFAULT 'Virtual Institute of Technology',
    batch VARCHAR(60) NOT NULL DEFAULT 'Batch A1 (Semester IV)',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 2. EXPERIMENTS METADATA TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS experiments (
    experiment_id VARCHAR(50) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    code VARCHAR(30) NOT NULL UNIQUE,
    aim TEXT NOT NULL,
    mode VARCHAR(30) NOT NULL DEFAULT 'inverting', -- 'inverting', 'nonInverting'
    r1_default NUMERIC(10, 2) NOT NULL DEFAULT 2000.0,
    rf_default NUMERIC(10, 2) NOT NULL DEFAULT 20000.0,
    vcc NUMERIC(6, 2) NOT NULL DEFAULT 15.0,
    vee NUMERIC(6, 2) NOT NULL DEFAULT -15.0,
    v_sat NUMERIC(6, 2) NOT NULL DEFAULT 13.5,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 3. CIRCUIT VERIFICATIONS / WIRING SUBMISSIONS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS circuit_verifications (
    id SERIAL PRIMARY KEY,
    student_roll_no VARCHAR(50) NOT NULL REFERENCES students(roll_no) ON DELETE CASCADE,
    experiment_id VARCHAR(50) NOT NULL REFERENCES experiments(experiment_id) ON DELETE CASCADE,
    mode VARCHAR(30) NOT NULL,
    wires_data JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_complete BOOLEAN NOT NULL DEFAULT FALSE,
    missing_connections TEXT[] DEFAULT '{}',
    verified_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 4. EXPERIMENT OBSERVATION READINGS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS experiment_readings (
    id SERIAL PRIMARY KEY,
    student_roll_no VARCHAR(50) NOT NULL REFERENCES students(roll_no) ON DELETE CASCADE,
    experiment_id VARCHAR(50) NOT NULL REFERENCES experiments(experiment_id) ON DELETE CASCADE,
    serial_no INT NOT NULL,
    mode VARCHAR(30) NOT NULL,
    r1_ohm NUMERIC(12, 2) NOT NULL,
    rf_ohm NUMERIC(12, 2) NOT NULL,
    vin_volts NUMERIC(8, 3) NOT NULL,
    expected_vout NUMERIC(8, 3) NOT NULL,
    measured_vout NUMERIC(8, 3) NOT NULL,
    theoretical_gain NUMERIC(8, 3) NOT NULL,
    error_percent NUMERIC(6, 2) NOT NULL DEFAULT 0.0,
    is_saturated BOOLEAN NOT NULL DEFAULT FALSE,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 5. QUIZ QUESTIONS BANK TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS quiz_questions (
    id SERIAL PRIMARY KEY,
    quiz_type VARCHAR(20) NOT NULL CHECK (quiz_type IN ('pretest', 'posttest')),
    question TEXT NOT NULL,
    option_a TEXT NOT NULL,
    option_b TEXT NOT NULL,
    option_c TEXT NOT NULL,
    option_d TEXT NOT NULL,
    correct_index INT NOT NULL CHECK (correct_index BETWEEN 0 AND 3),
    explanation TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 6. QUIZ SUBMISSIONS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS quiz_submissions (
    id SERIAL PRIMARY KEY,
    student_roll_no VARCHAR(50) NOT NULL REFERENCES students(roll_no) ON DELETE CASCADE,
    quiz_type VARCHAR(20) NOT NULL CHECK (quiz_type IN ('pretest', 'posttest')),
    total_questions INT NOT NULL,
    correct_answers INT NOT NULL,
    score_percentage NUMERIC(6, 2) NOT NULL,
    answers_detail JSONB NOT NULL DEFAULT '[]'::jsonb,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 7. FORMAL LAB REPORTS ARCHIVE TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lab_reports (
    id SERIAL PRIMARY KEY,
    student_roll_no VARCHAR(50) NOT NULL REFERENCES students(roll_no) ON DELETE CASCADE,
    experiment_id VARCHAR(50) NOT NULL REFERENCES experiments(experiment_id) ON DELETE CASCADE,
    report_title VARCHAR(255) NOT NULL,
    experiment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    student_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    readings_summary JSONB NOT NULL DEFAULT '[]'::jsonb,
    quiz_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
    circuit_status VARCHAR(50) NOT NULL DEFAULT 'Verified',
    conclusion TEXT,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- INDEXES FOR HIGH-PERFORMANCE RETRIEVAL
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_readings_student ON experiment_readings(student_roll_no);
CREATE INDEX IF NOT EXISTS idx_readings_exp ON experiment_readings(experiment_id);
CREATE INDEX IF NOT EXISTS idx_quiz_student ON quiz_submissions(student_roll_no);
CREATE INDEX IF NOT EXISTS idx_reports_student ON lab_reports(student_roll_no);
CREATE INDEX IF NOT EXISTS idx_circuit_verifications ON circuit_verifications(student_roll_no, experiment_id);

-- -----------------------------------------------------------------------------
-- AUTOMATED TRIGGER FOR UPDATED_AT TIMESTAMP
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_student_timestamp ON students;
CREATE TRIGGER trg_update_student_timestamp
BEFORE UPDATE ON students
FOR EACH ROW
EXECUTE FUNCTION update_timestamp_column();

-- -----------------------------------------------------------------------------
-- ANALYTICAL VIEW: STUDENT EXPERIMENT OVERVIEW
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_student_lab_summary AS
SELECT 
    s.roll_no,
    s.name,
    s.branch,
    s.college,
    COUNT(DISTINCT r.id) AS total_readings_recorded,
    MAX(r.recorded_at) AS last_reading_time,
    COALESCE((
        SELECT score_percentage 
        FROM quiz_submissions 
        WHERE student_roll_no = s.roll_no AND quiz_type = 'pretest' 
        ORDER BY submitted_at DESC LIMIT 1
    ), 0.0) AS latest_pretest_score,
    COALESCE((
        SELECT score_percentage 
        FROM quiz_submissions 
        WHERE student_roll_no = s.roll_no AND quiz_type = 'posttest' 
        ORDER BY submitted_at DESC LIMIT 1
    ), 0.0) AS latest_posttest_score,
    COUNT(DISTINCT rep.id) AS reports_generated
FROM students s
LEFT JOIN experiment_readings r ON s.roll_no = r.student_roll_no
LEFT JOIN lab_reports rep ON s.roll_no = rep.student_roll_no
GROUP BY s.roll_no, s.name, s.branch, s.college;

-- -----------------------------------------------------------------------------
-- SEED DATA: EXPERIMENT METADATA & COMPREHENSIVE QUIZ QUESTIONS
-- -----------------------------------------------------------------------------
INSERT INTO experiments (experiment_id, title, code, aim, mode, r1_default, rf_default, vcc, vee, v_sat)
VALUES (
    'OPAMP-01',
    'Study of Basic Properties of Operational Amplifier: Inverting and Non-Inverting Amplifiers',
    'EC201-OPAMP',
    'To construct and study the inverting and non-inverting operational amplifier circuits using IC 741, measure closed-loop voltage gain, observe phase relationship, and verify output saturation limits.',
    'inverting',
    2000.0,
    20000.0,
    15.0,
    -15.0,
    13.5
) ON CONFLICT (experiment_id) DO NOTHING;

-- Initial Demo Student Profile
INSERT INTO students (roll_no, name, branch, college, batch)
VALUES (
    'ECE-2026-042',
    'Rajiv Ghimire',
    'Electronics & Communication Engineering',
    'Virtual Institute of Technology',
    'Batch A1 (Semester IV)'
) ON CONFLICT (roll_no) DO UPDATE 
SET name = EXCLUDED.name, branch = EXCLUDED.branch, college = EXCLUDED.college;

-- Pretest Questions Bank
INSERT INTO quiz_questions (quiz_type, question, option_a, option_b, option_c, option_d, correct_index, explanation)
VALUES 
(
    'pretest',
    'What is the ideal input impedance (Rin) of an operational amplifier?',
    'Zero Ω',
    'Infinite (∞) Ω',
    '50 Ω',
    '10 kΩ',
    1,
    'An ideal operational amplifier draws zero input current, which requires an infinite input impedance (Rin = ∞).'
),
(
    'pretest',
    'What is the ideal output impedance (Rout) of an operational amplifier?',
    'Zero Ω',
    'Infinite (∞) Ω',
    '100 Ω',
    '1 MΩ',
    0,
    'An ideal op-amp acts as an ideal voltage source with zero internal output impedance (Rout = 0).'
),
(
    'pretest',
    'The concept of Virtual Ground in an inverting op-amp relies on which two ideal conditions?',
    'Infinite output impedance and finite open-loop gain',
    'Zero CMRR and positive feedback',
    'Infinite open-loop gain and zero input bias current with non-inverting terminal grounded',
    'Saturation voltage exceeding supply rails',
    2,
    'Because open-loop gain Aol is virtually infinite and the non-inverting terminal is at 0V (ground), the inverting pin is held at 0V without being physically shorted to ground.'
),
(
    'pretest',
    'What is the Common Mode Rejection Ratio (CMRR) of an ideal op-amp?',
    '0 dB',
    '1',
    'Infinite (∞)',
    '-100 dB',
    2,
    'An ideal op-amp completely rejects common-mode noise, yielding an infinite CMRR (CMRR = Ad / Acm = ∞).'
),
(
    'pretest',
    'Which pin of the standard IC 741 DIP-8 package represents the Inverting Input terminal?',
    'Pin 2',
    'Pin 3',
    'Pin 6',
    'Pin 7',
    0,
    'Pin 2 is Inverting Input (-), Pin 3 is Non-Inverting (+), Pin 6 is Output, Pin 7 is +Vcc, and Pin 4 is -Vee.'
);

-- Posttest Questions Bank
INSERT INTO quiz_questions (quiz_type, question, option_a, option_b, option_c, option_d, correct_index, explanation)
VALUES 
(
    'posttest',
    'What is the theoretical closed-loop voltage gain (Av) of an inverting amplifier with R1 = 2 kΩ and Rf = 20 kΩ?',
    '+10',
    '-10',
    '-11',
    '+11',
    1,
    'For an inverting amplifier: Av = - (Rf / R1) = - (20 kΩ / 2 kΩ) = -10.'
),
(
    'posttest',
    'What is the theoretical closed-loop voltage gain (Av) of a non-inverting amplifier with R1 = 2 kΩ and Rf = 20 kΩ?',
    '+10',
    '-10',
    '+11',
    '-11',
    2,
    'For a non-inverting amplifier: Av = 1 + (Rf / R1) = 1 + (20 / 2) = +11.'
),
(
    'posttest',
    'What is the phase difference between input and output waveforms in an inverting op-amp configuration?',
    '0° (In-phase)',
    '90°',
    '180° (Out-of-phase)',
    '270°',
    2,
    'The inverting terminal imparts an exact 180° phase inversion between the input signal and the output signal.'
),
(
    'posttest',
    'If the DC supply is ±15V and internal drop is 1.5V, what happens when an input causes calculated Vo to exceed 25V?',
    'The op-amp burns out immediately',
    'The output clamps at the positive saturation voltage (+13.5V)',
    'The output oscillates infinitely',
    'The output increases linearly up to 25V',
    1,
    'An operational amplifier cannot output a voltage beyond its saturation limits: Vsat = ±(Vsupply - Vdrop) = ±13.5V.'
),
(
    'posttest',
    'Why is negative feedback employed in linear op-amp amplifier circuits?',
    'To increase the open-loop gain to infinity',
    'To stabilize voltage gain, broaden bandwidth, and ensure predictable closed-loop operation',
    'To produce sustained sinusoidal oscillations',
    'To reduce input impedance to zero',
    1,
    'Negative feedback desensitizes the circuit from open-loop variations, stabilizes gain to (Rf/R1), reduces distortion, and broadens bandwidth.'
);
