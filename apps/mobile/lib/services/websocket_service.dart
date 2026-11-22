// services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../services/notification_service.dart';

typedef SosAlertCallback = void Function(Map<String, dynamic> alert);
typedef StatusUpdateCallback = void Function(Map<String, dynamic> update);

class WebSocketService {
  static final WebSocketService instance = WebSocketService._();
  WebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;

  String? _userId;
  String? _role;
  double _lat = 0;
  double _lng = 0;

  final _sosAlertController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get sosAlerts => _sosAlertController.stream;
  Stream<Map<String, dynamic>> get statusUpdates => _statusUpdateController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;

  bool get isConnected => _channel != null;

  void connect({
    required String userId,
    required String role,
    required double lat,
    required double lng,
  }) {
    _userId = userId;
    _role = role;
    _lat = lat;
    _lng = lng;
    _intentionalClose = false;
    _doConnect();
  }

  void _doConnect() {
    final uri = Uri.parse(
      '${AppConfig.wsRescue}'
      '?user_id=${Uri.encodeComponent(_userId ?? "anon")}'
      '&role=${Uri.encodeComponent(_role ?? "USER")}'
      '&lat=$_lat&lng=$_lng',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _connectionStateController.add(true);

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          _connectionStateController.add(false);
          if (!_intentionalClose) _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      if (type == 'NEW_SOS_ALERT') {
        _sosAlertController.add(data);
        final sos = data['sos'] as Map<String, dynamic>? ?? {};
        NotificationService.instance.showSosAlert(
          title: '🚨 New SOS — ${sos['category'] ?? ''}',
          body: sos['description'] ?? 'Emergency alert nearby',
        );
      } else if (type == 'SOS_STATUS_UPDATE') {
        _statusUpdateController.add(data);
      }
    } catch (_) {}
  }

  void sendPing() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'PING'}));
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_intentionalClose && _userId != null) _doConnect();
    });
  }

  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connectionStateController.add(false);
  }

  void dispose() {
    disconnect();
    _sosAlertController.close();
    _statusUpdateController.close();
    _connectionStateController.close();
  }
}
