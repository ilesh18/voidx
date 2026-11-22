// core/constants.dart
// Route paths match fastapi_server.py exactly.
// Backend base URL and WebSocket base URL are provided by lib/config/app_config.dart
// (read from the BACKEND_URL environment variable). No production URL is hard-coded here.
import '../config/app_config.dart';

class AppConstants {
  // API routes (match fastapi_server.py exactly)
  static const String apiSosCreate = '/api/sos/create';
  static const String apiSosList = '/api/sos/active';
  static const String apiSosDetail = '/api/sos/{id}';
  static const String apiSosAccept = '/api/sos/{id}/accept';
  static const String apiSosStatus = '/api/sos/{id}/status';
  static const String apiRescueTeams = '/api/rescue/teams';
  static const String apiRescueNearby = '/api/rescue/nearby';
  static const String apiChatEmergency = '/api/chat/emergency';
  static const String apiCyclonesActive = '/api/cyclones/active';
  static const String apiCyclonesHealth = '/api/cyclones/health';
  static const String apiOfflineSync = '/api/offline/sync';
  static const String wsRescuePath = '/ws/rescue';

  // Derived full URLs (production uses HTTPS / WSS via AppConfig)
  static String get urlSosCreate => AppConfig.apiSosCreate();
  static String get urlSosList => AppConfig.apiSosActive();
  static String get urlRescueTeams => AppConfig.apiRescueTeams();
  static String get urlRescueNearby => AppConfig.apiRescueNearby();
  static String get urlChatEmergency => AppConfig.apiChatEmergency();
  static String get urlCyclonesActive => AppConfig.apiCyclonesActive();
  static String get urlCyclonesHealth => AppConfig.apiCyclonesHealth();
  static String get urlOfflineSync => AppConfig.apiOfflineSync();
  static String get urlWsRescue => AppConfig.wsRescue();
  static String urlSosDetail(String id) => AppConfig.apiSosDetail(id);
  static String urlSosAccept(String id) => AppConfig.apiSosAccept(id);
  static String urlSosStatus(String id) => AppConfig.apiSosStatus(id);

  // SharedPrefs keys
  static const String prefUserId = 'userId';
  static const String prefUserName = 'userName';
  static const String prefUserRole = 'userRole';
  static const String prefUserLat = 'userLat';
  static const String prefUserLng = 'userLng';
  static const String prefPendingSOS = 'pendingSosQueue';
  static const String prefPermissionsGranted = 'permissionsGranted';
  static const String prefPhoneNumber = 'phoneNumber';

  // Roles
  static const String roleUser = 'USER';
  static const String roleVolunteer = 'VOLUNTEER';
  static const String roleRescueTeam = 'RESCUE_TEAM';
  static const String roleCoordinator = 'COORDINATOR';
}
