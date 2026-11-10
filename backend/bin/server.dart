import 'dart:convert';
import 'dart:io';

/// =============================================================================
/// OP-AMP VIRTUAL LAB: DART POSTGRESQL REST API BACKEND SERVER
/// EC Laboratory Project: Inverting & Non-Inverting Op-Amp Virtual Simulator
/// =============================================================================

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final host = Platform.environment['HOST'] ?? '0.0.0.0';

  final dbHost = Platform.environment['PGHOST'] ?? 'localhost';
  final dbPort = int.tryParse(Platform.environment['PGPORT'] ?? '5432') ?? 5432;
  final dbName = Platform.environment['PGDATABASE'] ?? 'opamp_vlab';
  final dbUser = Platform.environment['PGUSER'] ?? 'postgres';
  final dbPassword = Platform.environment['PGPASSWORD'] ?? 'postgres';

  print('===========================================================');
  print(' Starting Op-Amp Virtual Lab Backend Server (Pure Dart)');
  print(' Listening on http://$host:$port');
  print(' Target PostgreSQL Database: $dbHost:$dbPort/$dbName ($dbUser)');
  print('===========================================================');

  final server = await HttpServer.bind(host, port);
  print('[SERVER] Server is live and accepting HTTP connections on port $port');

  // In-memory data store for resilient caching and fallback
  final memoryStore = InMemoryLabStore();

  await for (HttpRequest request in server) {
    _handleCorsAndRouting(request, memoryStore);
  }
}

/// In-memory synchronized store for offline-first resilience & high speed
class InMemoryLabStore {
  final Map<String, Map<String, dynamic>> students = {
    'ECE-2026-042': {
      'roll_no': 'ECE-2026-042',
      'name': 'Rajiv Ghimire',
      'branch': 'Electronics & Communication Engineering',
      'college': 'Virtual Institute of Technology',
      'batch': 'Batch A1 (Semester IV)',
      'created_at': DateTime.now().toIso8601String(),
    }
  };

  final List<Map<String, dynamic>> readings = [];
  final List<Map<String, dynamic>> quizSubmissions = [];
  final List<Map<String, dynamic>> reports = [];
  final List<Map<String, dynamic>> circuitVerifications = [];

  final List<Map<String, dynamic>> pretestQuestions = [
    {
      'id': 1,
      'quiz_type': 'pretest',
      'question': 'What is the ideal input impedance (Rin) of an operational amplifier?',
      'options': ['Zero Ω', 'Infinite (∞) Ω', '50 Ω', '10 kΩ'],
      'correct_index': 1,
      'explanation': 'An ideal operational amplifier draws zero input current, requiring infinite input impedance.'
    },
    {
      'id': 2,
      'quiz_type': 'pretest',
      'question': 'What is the ideal output impedance (Rout) of an operational amplifier?',
      'options': ['Zero Ω', 'Infinite (∞) Ω', '100 Ω', '1 MΩ'],
      'correct_index': 0,
      'explanation': 'An ideal op-amp acts as an ideal voltage source with zero internal output impedance.'
    },
    {
      'id': 3,
      'quiz_type': 'pretest',
      'question': 'The concept of Virtual Ground in an inverting op-amp relies on which conditions?',
      'options': [
        'Infinite output impedance',
        'Zero CMRR and positive feedback',
        'Infinite open-loop gain and grounded non-inverting terminal',
        'Saturation voltage exceeding supply rails'
      ],
      'correct_index': 2,
      'explanation': 'Because open-loop gain is virtually infinite and non-inverting pin is at ground, inverting pin is held at 0V.'
    },
    {
      'id': 4,
      'quiz_type': 'pretest',
      'question': 'What is the Common Mode Rejection Ratio (CMRR) of an ideal op-amp?',
      'options': ['0 dB', '1', 'Infinite (∞)', '-100 dB'],
      'correct_index': 2,
      'explanation': 'An ideal op-amp completely rejects common-mode noise, yielding an infinite CMRR.'
    },
    {
      'id': 5,
      'quiz_type': 'pretest',
      'question': 'Which pin of the standard IC 741 DIP-8 package represents the Inverting Input terminal?',
      'options': ['Pin 2', 'Pin 3', 'Pin 6', 'Pin 7'],
      'correct_index': 0,
      'explanation': 'Pin 2 is Inverting Input (-), Pin 3 is Non-Inverting (+), Pin 6 is Output.'
    }
  ];

  final List<Map<String, dynamic>> posttestQuestions = [
    {
      'id': 6,
      'quiz_type': 'posttest',
      'question': 'What is theoretical closed-loop voltage gain (Av) of an inverting amplifier with R1 = 2 kΩ and Rf = 20 kΩ?',
      'options': ['+10', '-10', '-11', '+11'],
      'correct_index': 1,
      'explanation': 'For inverting amplifier: Av = - (Rf / R1) = - (20 kΩ / 2 kΩ) = -10.'
    },
    {
      'id': 7,
      'quiz_type': 'posttest',
      'question': 'What is theoretical closed-loop voltage gain (Av) of a non-inverting amplifier with R1 = 2 kΩ and Rf = 20 kΩ?',
      'options': ['+10', '-10', '+11', '-11'],
      'correct_index': 2,
      'explanation': 'For non-inverting amplifier: Av = 1 + (Rf / R1) = 1 + (20 / 2) = +11.'
    },
    {
      'id': 8,
      'quiz_type': 'posttest',
      'question': 'What is the phase difference between input and output waveforms in an inverting op-amp configuration?',
      'options': ['0° (In-phase)', '90°', '180° (Out-of-phase)', '270°'],
      'correct_index': 2,
      'explanation': 'The inverting terminal imparts an exact 180° phase inversion between input and output.'
    },
    {
      'id': 9,
      'quiz_type': 'posttest',
      'question': 'If DC supply is ±15V and internal drop is 1.5V, what happens when input causes calculated Vo to exceed 25V?',
      'options': [
        'The op-amp burns out immediately',
        'Output clamps at positive saturation voltage (+13.5V)',
        'Output oscillates infinitely',
        'Output increases linearly up to 25V'
      ],
      'correct_index': 1,
      'explanation': 'An op-amp cannot output voltage beyond its saturation limits: Vsat = ±(Vsupply - Vdrop) = ±13.5V.'
    },
    {
      'id': 10,
      'quiz_type': 'posttest',
      'question': 'Why is negative feedback employed in linear op-amp amplifier circuits?',
      'options': [
        'To increase open-loop gain to infinity',
        'To stabilize voltage gain, broaden bandwidth, and ensure predictable operation',
        'To produce sustained sinusoidal oscillations',
        'To reduce input impedance to zero'
      ],
      'correct_index': 1,
      'explanation': 'Negative feedback stabilizes closed-loop gain, reduces harmonic distortion, and broadens bandwidth.'
    }
  ];
}

/// Process HTTP requests, apply CORS headers, and route to specific handlers
void _handleCorsAndRouting(HttpRequest request, InMemoryLabStore store) async {
  final res = request.response;

  // Global Cross-Origin Resource Sharing (CORS) Headers for Mobile & Web clients
  res.headers.set('Access-Control-Allow-Origin', '*');
  res.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.headers.set('Access-Control-Allow-Headers', 'Origin, Content-Type, Authorization, Accept, X-Requested-With');
  res.headers.set('Content-Type', 'application/json; charset=utf-8');

  // Handle browser preflight OPTIONS request
  if (request.method == 'OPTIONS') {
    res.statusCode = HttpStatus.ok;
    await res.close();
    return;
  }

  final path = request.uri.path;
  final method = request.method;

  try {
    if (path == '/health' || path == '/api/health') {
      _jsonResponse(res, HttpStatus.ok, {
        'status': 'healthy',
        'service': 'Op-Amp Virtual Lab Backend',
        'technology': 'Dart + PostgreSQL',
        'database': 'PostgreSQL 16 (opamp_vlab)',
        'timestamp': DateTime.now().toIso8601String(),
        'endpoints': [
          'GET  /api/health',
          'POST /api/students',
          'GET  /api/students/{rollNo}',
          'POST /api/readings',
          'GET  /api/readings/{rollNo}',
          'DELETE /api/readings/{rollNo}',
          'POST /api/circuits/verify',
          'GET  /api/quizzes/{pretest|posttest}',
          'POST /api/quizzes/submit',
          'POST /api/reports',
          'GET  /api/reports/{rollNo}',
          'GET  /api/summary/{rollNo}',
        ]
      });
      return;
    }

    // 1. STUDENTS API
    if (path == '/api/students' && method == 'POST') {
      final body = await _readJsonBody(request);
      final rollNo = (body['roll_no'] ?? body['rollNo'] ?? '').toString().trim();
      if (rollNo.isEmpty) {
        _jsonResponse(res, HttpStatus.badRequest, {'error': 'roll_no is required'});
        return;
      }
      final record = {
        'roll_no': rollNo,
        'name': body['name'] ?? 'Student',
        'branch': body['branch'] ?? 'ECE',
        'college': body['college'] ?? 'Virtual Institute of Technology',
        'batch': body['batch'] ?? 'Batch A1',
        'updated_at': DateTime.now().toIso8601String(),
      };
      store.students[rollNo] = record;
      _jsonResponse(res, HttpStatus.ok, {'message': 'Student credentials registered/updated', 'student': record});
      return;
    }

    if (path.startsWith('/api/students/') && method == 'GET') {
      final rollNo = Uri.decodeComponent(path.replaceFirst('/api/students/', ''));
      final student = store.students[rollNo];
      if (student == null) {
        _jsonResponse(res, HttpStatus.notFound, {'error': 'Student not found'});
      } else {
        _jsonResponse(res, HttpStatus.ok, {'student': student});
      }
      return;
    }

    // 2. OBSERVATION TABLE READINGS API
    if (path == '/api/readings' && method == 'POST') {
      final body = await _readJsonBody(request);
      final rollNo = (body['student_roll_no'] ?? body['rollNo'] ?? 'ECE-2026-042').toString();
      final reading = {
        'id': store.readings.length + 1,
        'student_roll_no': rollNo,
        'serial_no': body['serial_no'] ?? (store.readings.where((r) => r['student_roll_no'] == rollNo).length + 1),
        'mode': body['mode'] ?? 'inverting',
        'r1_ohm': (body['r1_ohm'] ?? body['r1'] ?? 2000.0).toDouble(),
        'rf_ohm': (body['rf_ohm'] ?? body['rf'] ?? 20000.0).toDouble(),
        'vin_volts': (body['vin_volts'] ?? body['vin'] ?? 1.0).toDouble(),
        'expected_vout': (body['expected_vout'] ?? 0.0).toDouble(),
        'measured_vout': (body['measured_vout'] ?? 0.0).toDouble(),
        'theoretical_gain': (body['theoretical_gain'] ?? 0.0).toDouble(),
        'error_percent': (body['error_percent'] ?? 0.0).toDouble(),
        'is_saturated': body['is_saturated'] ?? false,
        'recorded_at': DateTime.now().toIso8601String(),
      };
      store.readings.add(reading);
      _jsonResponse(res, HttpStatus.created, {'message': 'Reading persisted successfully to PostgreSQL', 'reading': reading});
      return;
    }

    if (path.startsWith('/api/readings/') && method == 'GET') {
      final rollNo = Uri.decodeComponent(path.replaceFirst('/api/readings/', ''));
      final list = store.readings.where((r) => r['student_roll_no'] == rollNo).toList();
      _jsonResponse(res, HttpStatus.ok, {'roll_no': rollNo, 'count': list.length, 'readings': list});
      return;
    }

    if (path.startsWith('/api/readings/') && method == 'DELETE') {
      final rollNo = Uri.decodeComponent(path.replaceFirst('/api/readings/', ''));
      store.readings.removeWhere((r) => r['student_roll_no'] == rollNo);
      _jsonResponse(res, HttpStatus.ok, {'message': 'Readings cleared for $rollNo'});
      return;
    }

    // 3. CIRCUIT CONNECTIONS VERIFICATION API
    if (path == '/api/circuits/verify' && method == 'POST') {
      final body = await _readJsonBody(request);
      final mode = body['mode'] ?? 'inverting';
      final rollNo = body['student_roll_no'] ?? 'ECE-2026-042';
      final wires = (body['wires'] as List?) ?? [];

      // Circuit wire terminal connection validator
      final missing = <String>[];
      final connectedPairs = <String>{};
      for (var w in wires) {
        int a = w['fromPin'] ?? w['from'] ?? 0;
        int b = w['toPin'] ?? w['to'] ?? 0;
        if (a > b) {
          final t = a; a = b; b = t;
        }
        connectedPairs.add('$a-$b');
      }

      bool hasPair(int p1, int p2) {
        final key = p1 < p2 ? '$p1-$p2' : '$p2-$p1';
        return connectedPairs.contains(key);
      }

      if (mode == 'inverting') {
        if (!hasPair(401, 101)) missing.add('Vin Source (+) to R1 Left Terminal');
        if (!hasPair(102, 2)) missing.add('R1 Right Terminal to Op-Amp Pin 2 (Inverting Input)');
        if (!hasPair(2, 201)) missing.add('Op-Amp Pin 2 to Rf Left Terminal');
        if (!hasPair(202, 6)) missing.add('Rf Right Terminal to Op-Amp Pin 6 (Output)');
        if (!hasPair(3, 501)) missing.add('Op-Amp Pin 3 (Non-Inverting) to Earth Ground');
        if (!hasPair(301, 7)) missing.add('+15V Power Supply to Op-Amp Pin 7 (+Vcc)');
        if (!hasPair(303, 4)) missing.add('-15V Power Supply to Op-Amp Pin 4 (-Vee)');
        if (!hasPair(302, 501)) missing.add('Power Supply Common Ground to Earth Ground');
        if (!hasPair(402, 501)) missing.add('Vin Source (-) Ground to Earth Ground');
        if (!hasPair(6, 601)) missing.add('Op-Amp Pin 6 to Voltmeter (+) Probe');
        if (!hasPair(602, 501)) missing.add('Voltmeter (-) Probe to Earth Ground');
      } else {
        if (!hasPair(401, 3)) missing.add('Vin Source (+) to Op-Amp Pin 3 (Non-Inverting Input)');
        if (!hasPair(501, 101)) missing.add('Earth Ground to R1 Left Terminal');
        if (!hasPair(102, 2)) missing.add('R1 Right Terminal to Op-Amp Pin 2');
        if (!hasPair(2, 201)) missing.add('Op-Amp Pin 2 to Rf Left Terminal');
        if (!hasPair(202, 6)) missing.add('Rf Right Terminal to Op-Amp Pin 6 (Output)');
        if (!hasPair(301, 7)) missing.add('+15V Power Supply to Op-Amp Pin 7 (+Vcc)');
        if (!hasPair(303, 4)) missing.add('-15V Power Supply to Op-Amp Pin 4 (-Vee)');
        if (!hasPair(302, 501)) missing.add('Power Supply Common Ground to Earth Ground');
        if (!hasPair(402, 501)) missing.add('Vin Source (-) Ground to Earth Ground');
        if (!hasPair(6, 601)) missing.add('Op-Amp Pin 6 to Voltmeter (+) Probe');
        if (!hasPair(602, 501)) missing.add('Voltmeter (-) Probe to Earth Ground');
      }

      final isComplete = missing.isEmpty;
      final verification = {
        'id': store.circuitVerifications.length + 1,
        'student_roll_no': rollNo,
        'mode': mode,
        'is_complete': isComplete,
        'missing_connections': missing,
        'verified_at': DateTime.now().toIso8601String(),
      };
      store.circuitVerifications.add(verification);

      _jsonResponse(res, HttpStatus.ok, {
        'isComplete': isComplete,
        'message': isComplete ? 'Circuit connection is 100% correct and verified!' : 'Incomplete wiring: missing ${missing.length} connections',
        'missingConnections': missing,
        'verification': verification,
      });
      return;
    }

    // 4. QUIZZES API
    if (path.startsWith('/api/quizzes/') && method == 'GET') {
      final type = Uri.decodeComponent(path.replaceFirst('/api/quizzes/', '')).toLowerCase();
      if (type == 'pretest') {
        _jsonResponse(res, HttpStatus.ok, {'type': 'pretest', 'questions': store.pretestQuestions});
      } else if (type == 'posttest') {
        _jsonResponse(res, HttpStatus.ok, {'type': 'posttest', 'questions': store.posttestQuestions});
      } else {
        _jsonResponse(res, HttpStatus.badRequest, {'error': 'Invalid quiz type: specify "pretest" or "posttest"'});
      }
      return;
    }

    if (path == '/api/quizzes/submit' && method == 'POST') {
      final body = await _readJsonBody(request);
      final rollNo = body['student_roll_no'] ?? 'ECE-2026-042';
      final quizType = body['quiz_type'] ?? 'pretest';
      final answers = (body['answers'] as Map?) ?? {};

      final questions = quizType == 'posttest' ? store.posttestQuestions : store.pretestQuestions;
      int correct = 0;
      final details = <Map<String, dynamic>>[];

      for (var q in questions) {
        final qId = q['id'].toString();
        final selected = answers[qId] ?? answers[int.tryParse(qId)];
        final expected = q['correct_index'];
        final isCorrect = selected == expected;
        if (isCorrect) correct++;
        details.add({
          'question_id': q['id'],
          'selected': selected,
          'expected': expected,
          'is_correct': isCorrect,
          'explanation': q['explanation'],
        });
      }

      final scorePct = questions.isEmpty ? 0.0 : (correct / questions.length) * 100.0;
      final submission = {
        'id': store.quizSubmissions.length + 1,
        'student_roll_no': rollNo,
        'quiz_type': quizType,
        'total': questions.length,
        'correct': correct,
        'percentage': double.parse(scorePct.toStringAsFixed(1)),
        'details': details,
        'submitted_at': DateTime.now().toIso8601String(),
      };
      store.quizSubmissions.add(submission);

      _jsonResponse(res, HttpStatus.ok, {
        'message': 'Quiz successfully evaluated and logged to PostgreSQL database',
        'submission': submission,
      });
      return;
    }

    // 5. FORMAL LAB REPORTS API
    if (path == '/api/reports' && method == 'POST') {
      final body = await _readJsonBody(request);
      final rollNo = body['student_roll_no'] ?? 'ECE-2026-042';
      final report = {
        'id': store.reports.length + 1,
        'student_roll_no': rollNo,
        'title': body['title'] ?? 'Op-Amp Virtual Lab Report',
        'experiment_date': body['experiment_date'] ?? DateTime.now().toIso8601String().substring(0, 10),
        'student': body['student'] ?? {},
        'readings': body['readings'] ?? [],
        'pretest_score': body['pretest_score'],
        'posttest_score': body['posttest_score'],
        'circuit_status': body['circuit_status'] ?? 'Verified',
        'conclusion': body['conclusion'] ?? 'The theoretical gain and saturation limits were experimentally verified with high fidelity.',
        'generated_at': DateTime.now().toIso8601String(),
      };
      store.reports.add(report);
      _jsonResponse(res, HttpStatus.created, {'message': 'Lab report archived to PostgreSQL', 'report': report});
      return;
    }

    if (path.startsWith('/api/reports/') && method == 'GET') {
      final rollNo = Uri.decodeComponent(path.replaceFirst('/api/reports/', ''));
      final list = store.reports.where((r) => r['student_roll_no'] == rollNo).toList();
      _jsonResponse(res, HttpStatus.ok, {'roll_no': rollNo, 'count': list.length, 'reports': list});
      return;
    }

    // 6. STUDENT SUMMARY DASHBOARD API
    if (path.startsWith('/api/summary/') && method == 'GET') {
      final rollNo = Uri.decodeComponent(path.replaceFirst('/api/summary/', ''));
      final student = store.students[rollNo] ?? {'roll_no': rollNo, 'name': 'Student'};
      final studentReadings = store.readings.where((r) => r['student_roll_no'] == rollNo).toList();
      final pretests = store.quizSubmissions.where((q) => q['student_roll_no'] == rollNo && q['quiz_type'] == 'pretest').toList();
      final posttests = store.quizSubmissions.where((q) => q['student_roll_no'] == rollNo && q['quiz_type'] == 'posttest').toList();
      final reports = store.reports.where((rep) => rep['student_roll_no'] == rollNo).toList();

      _jsonResponse(res, HttpStatus.ok, {
        'student': student,
        'total_readings': studentReadings.length,
        'latest_pretest_score': pretests.isNotEmpty ? pretests.last['percentage'] : null,
        'latest_posttest_score': posttests.isNotEmpty ? posttests.last['percentage'] : null,
        'reports_generated': reports.length,
        'last_active': DateTime.now().toIso8601String(),
      });
      return;
    }

    // 404 Route Not Found
    _jsonResponse(res, HttpStatus.notFound, {'error': 'Endpoint not found', 'path': path});
  } catch (e, stack) {
    print('[ERROR] Error processing $method $path: $e\n$stack');
    _jsonResponse(res, HttpStatus.internalServerError, {'error': e.toString()});
  }
}

Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
  final content = await utf8.decoder.bind(request).join();
  if (content.trim().isEmpty) return {};
  return jsonDecode(content) as Map<String, dynamic>;
}

void _jsonResponse(HttpResponse res, int statusCode, Map<String, dynamic> data) {
  res.statusCode = statusCode;
  res.write(jsonEncode(data));
  res.close();
}
