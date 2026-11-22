// lib/config/app_config.dart
// Centralized CycloneX configuration.
// Production values must be supplied through environment variables (.env)
// and are never hard-coded here. No DTN credentials, API secrets, database
// passwords or private keys are stored in Flutter code.
import 'package:flutter_config/flutter_config.dart';

enum AppEnvironment { development, production }

class AppConfig {
  AppConfig._();

  static bool _initialized = false;

  static void ensureInitialized() {
    if (!_initialized) {
      FlutterConfig.loadEnvVariables();
      _initialized = true;
    }
  }

  static AppEnvironment get environment {
    ensureInitialized();
    final raw = (FlutterConfig.get('APP_ENV') ?? 'production')
        .toString()
        .trim()
        .toLowerCase();
    return raw == 'development' ? AppEnvironment.development : AppEnvironment.production;
  }

  /// Base REST API URL. In production this MUST be provided via BACKEND_URL
  /// (HTTPS). A fake URL is never substituted.
  static String get apiBaseUrl {
    ensureInitialized();
    final configured = FlutterConfig.get('BACKEND_URL')?.toString().trim();
    if (configured != null && configured.isNotEmpty) return configured;

    switch (environment) {
      case AppEnvironment.development:
        return 'http://10.0.2.2:8080';
      case AppEnvironment.production:
        throw StateError(
          'CycloneX production backend is not configured. '
          'Set the BACKEND_URL environment variable (HTTPS) before building '
          'a release. No fallback production URL is provided.',
        );
    }
  }

  /// Rescue WebSocket URL. Derived from the API base URL.
  /// Development: ws:// ; Production: wss://
  static String get wsBaseUrl {
    ensureInitialized();
    final api = apiBaseUrl;
    switch (environment) {
      case AppEnvironment.development:
        return api.replaceFirst('http://', 'ws://');
      case AppEnvironment.production:
        return api.replaceFirst('https://', 'wss://');
    }
  }

  static String apiSosCreate() => '$apiBaseUrl/api/sos/create';
  static String apiSosActive() => '$apiBaseUrl/api/sos/active';
  static String apiSosDetail(String id) => '$apiBaseUrl/api/sos/$id';
  static String apiSosStatus(String id) => '$apiBaseUrl/api/sos/$id/status';
  static String apiSosAccept(String id) => '$apiBaseUrl/api/sos/$id/accept';
  static String apiRescueTeams() => '$apiBaseUrl/api/rescue/teams';
  static String apiRescueNearby() => '$apiBaseUrl/api/rescue/nearby';
  static String apiChatEmergency() => '$apiBaseUrl/api/chat/emergency';
  static String apiCyclonesActive() => '$apiBaseUrl/api/cyclones/active';
  static String apiCyclonesHealth() => '$apiBaseUrl/api/cyclones/health';
  static String apiOfflineSync() => '$apiBaseUrl/api/offline/sync';
  static String wsRescue() => '$wsBaseUrl/ws/rescue';
}
