import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// =============================================================================
/// POSTGRESQL & BACKEND API CLIENT SERVICE FOR OP-AMP VIRTUAL LAB
/// Connects Flutter mobile client to Dart + PostgreSQL backend server.
/// =============================================================================

class PostgresApiService {
  static final PostgresApiService _instance = PostgresApiService._internal();
  factory PostgresApiService() => _instance;
  PostgresApiService._internal();

  /// Default API base URL:
  /// - Android Emulator: http://10.0.2.2:8080
  /// - Web / Desktop / Localhost: http://localhost:8080
  String _baseUrl = !kIsWeb && Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';

  String get baseUrl => _baseUrl;
  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  /// Check connectivity to PostgreSQL backend
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/health');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(uri);
      final res = await req.close();
      _isOnline = res.statusCode == HttpStatus.ok;
      client.close();
      return _isOnline;
    } catch (_) {
      _isOnline = false;
      return false;
    }
  }

  /// Register or synchronize student credentials with PostgreSQL
  Future<bool> syncStudent({
    required String rollNo,
    required String name,
    required String branch,
    required String college,
    required String batch,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/students');
      final res = await _postJson(uri, {
        'roll_no': rollNo,
        'name': name,
        'branch': branch,
        'college': college,
        'batch': batch,
      });
      return res['statusCode'] == HttpStatus.ok;
    } catch (e) {
      debugPrint('[PostgresApiService] syncStudent error: $e');
      return false;
    }
  }

  /// Save an observation reading to PostgreSQL database
  Future<bool> saveReading({
    required String studentRollNo,
    required int serialNo,
    required String mode,
    required double r1,
    required double rf,
    required double vin,
    required double expectedVout,
    required double measuredVout,
    required double theoreticalGain,
    required double errorPercent,
    required bool isSaturated,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/readings');
      final res = await _postJson(uri, {
        'student_roll_no': studentRollNo,
        'serial_no': serialNo,
        'mode': mode,
        'r1_ohm': r1,
        'rf_ohm': rf,
        'vin_volts': vin,
        'expected_vout': expectedVout,
        'measured_vout': measuredVout,
        'theoretical_gain': theoreticalGain,
        'error_percent': errorPercent,
        'is_saturated': isSaturated,
      });
      return res['statusCode'] == HttpStatus.created || res['statusCode'] == HttpStatus.ok;
    } catch (e) {
      debugPrint('[PostgresApiService] saveReading error: $e');
      return false;
    }
  }

  /// Fetch all historical readings for student from PostgreSQL
  Future<List<Map<String, dynamic>>> fetchReadings(String rollNo) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/readings/${Uri.encodeComponent(rollNo)}');
      final res = await _getJson(uri);
      if (res['statusCode'] == HttpStatus.ok && res['data']['readings'] != null) {
        return List<Map<String, dynamic>>.from(res['data']['readings']);
      }
      return [];
    } catch (e) {
      debugPrint('[PostgresApiService] fetchReadings error: $e');
      return [];
    }
  }

  /// Submit full lab report snapshot to PostgreSQL
  Future<bool> submitLabReport({
    required String studentRollNo,
    required String reportTitle,
    required Map<String, dynamic> studentMeta,
    required List<Map<String, dynamic>> readings,
    double? pretestScore,
    double? posttestScore,
    required String circuitStatus,
    String? conclusion,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/reports');
      final res = await _postJson(uri, {
        'student_roll_no': studentRollNo,
        'title': reportTitle,
        'student': studentMeta,
        'readings': readings,
        'pretest_score': pretestScore,
        'posttest_score': posttestScore,
        'circuit_status': circuitStatus,
        'conclusion': conclusion,
      });
      return res['statusCode'] == HttpStatus.created || res['statusCode'] == HttpStatus.ok;
    } catch (e) {
      debugPrint('[PostgresApiService] submitLabReport error: $e');
      return false;
    }
  }

  /// Submit quiz answers to PostgreSQL backend
  Future<Map<String, dynamic>?> submitQuiz({
    required String studentRollNo,
    required String quizType,
    required Map<dynamic, dynamic> answers,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/quizzes/submit');
      final res = await _postJson(uri, {
        'student_roll_no': studentRollNo,
        'quiz_type': quizType,
        'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
      });
      if (res['statusCode'] == HttpStatus.ok) {
        return res['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[PostgresApiService] submitQuiz error: $e');
      return null;
    }
  }

  // Helper HTTP POST
  Future<Map<String, dynamic>> _postJson(Uri uri, Map<String, dynamic> payload) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    final req = await client.postUrl(uri);
    req.headers.set('Content-Type', 'application/json; charset=utf-8');
    req.write(jsonEncode(payload));
    final res = await req.close();
    final bodyStr = await utf8.decoder.bind(res).join();
    client.close();

    Map<String, dynamic> parsed = {};
    if (bodyStr.isNotEmpty) {
      try {
        parsed = jsonDecode(bodyStr) as Map<String, dynamic>;
      } catch (_) {}
    }

    return {'statusCode': res.statusCode, 'data': parsed};
  }

  // Helper HTTP GET
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    final req = await client.getUrl(uri);
    final res = await req.close();
    final bodyStr = await utf8.decoder.bind(res).join();
    client.close();

    Map<String, dynamic> parsed = {};
    if (bodyStr.isNotEmpty) {
      try {
        parsed = jsonDecode(bodyStr) as Map<String, dynamic>;
      } catch (_) {}
    }

    return {'statusCode': res.statusCode, 'data': parsed};
  }
}
