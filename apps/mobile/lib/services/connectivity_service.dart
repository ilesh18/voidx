// services/connectivity_service.dart
import 'package:internet_connection_checker/internet_connection_checker.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    _isOnline = await InternetConnectionChecker().hasConnection;
  }

  Future<bool> check() async {
    _isOnline = await InternetConnectionChecker().hasConnection;
    return _isOnline;
  }
}
