// services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  final Duration _connectTimeout = const Duration(seconds: 8);
  final Duration _receiveTimeout = const Duration(seconds: 12);

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(
        'Request failed with status ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Invalid JSON response', statusCode: response.statusCode, body: response.body);
    }
  }

  // ── SOS ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> createSos(Map<String, dynamic> payload) async {
    final uri = Uri.parse(AppConstants.urlSosCreate);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(_receiveTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> getSosList() async {
    final uri = Uri.parse(AppConstants.urlSosList);
    final response = await http.get(uri).timeout(_receiveTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> getSosDetail(String sosId) async {
    final uri = Uri.parse(AppConstants.urlSosDetail(sosId));
    final response = await http.get(uri).timeout(_receiveTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> acceptSos(
      String sosId, String responderId, String responderName) async {
    final uri = Uri.parse(AppConstants.urlSosAccept(sosId));
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'responder_id': responderId,
        'responder_name': responderName,
      }),
    ).timeout(_receiveTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> updateSosStatus(
      String sosId, String status, String responderId,
      {String? note}) async {
    final uri = Uri.parse(AppConstants.urlSosStatus(sosId));
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': status,
        'responder_id': responderId,
        if (note != null) 'note': note,
      }),
    ).timeout(_receiveTimeout);
    return _decode(response);
  }

  // ── Rescue Teams ─────────────────────────────────────────
  Future<Map<String, dynamic>> getRescueTeams() async {
    final uri = Uri.parse(AppConstants.urlRescueTeams);
    final response = await http.get(uri).timeout(_receiveTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> getNearbyTeams(
      double lat, double lng, String? category, {int limit = 5}) async {
    final uri = Uri.parse(AppConstants.urlRescueNearby).replace(queryParameters: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      if (category != null) 'category': category,
      'limit': limit.toString(),
    });
    final response = await http.get(uri).timeout(_receiveTimeout);
    return _decode(response);
  }

  // ── Chat / RAG ───────────────────────────────────────────
  Future<Map<String, dynamic>> queryChatEmergency(String query,
      {String? category}) async {
    final uri = Uri.parse(AppConstants.urlChatEmergency).replace(queryParameters: {
      'query': query,
      if (category != null) 'category': category,
    });
    final response = await http.get(uri).timeout(_receiveTimeout);
    return _decode(response);
  }

  // ── Cyclones ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getActiveCyclones() async {
    final uri = Uri.parse(AppConstants.urlCyclonesActive);
    final response = await http.get(uri).timeout(_receiveTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> getCyclonesHealth() async {
    final uri = Uri.parse(AppConstants.urlCyclonesHealth);
    final response = await http.get(uri).timeout(_receiveTimeout);
    return _decode(response);
  }

  // ── Offline Sync ─────────────────────────────────────────
  Future<Map<String, dynamic>> syncOfflineSos(
      List<Map<String, dynamic>> messages) async {
    final uri = Uri.parse(AppConstants.urlOfflineSync);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'messages': messages}),
    ).timeout(_receiveTimeout);
    return _decode(response);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;
  ApiException(this.message, {this.statusCode, this.body});
  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
