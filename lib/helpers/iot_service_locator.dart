import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import '../services/iot_connection_manager.dart';
import '../services/device_api_service.dart';

/// Service locator for IoT services
class IoTServiceLocator {
  static final GetIt _getIt = GetIt.instance;
  static final Logger _logger = Logger();

  /// Initialize all services
  static Future<void> initialize({
    required String cloudBaseUrl,
    String? cloudApiKey,
    required String bleServiceUuid,
    required String bleCharacteristicUuid,
    int wifiPort = 80,
  }) async {
    _logger.i('Initializing IoT Service Locator...');

    // Register IoT Connection Manager
    _getIt.registerLazySingleton<IoTConnectionManager>(
      () => IoTConnectionManager(
        cloudBaseUrl: cloudBaseUrl,
        cloudApiKey: cloudApiKey,
        bleServiceUuid: bleServiceUuid,
        bleCharacteristicUuid: bleCharacteristicUuid,
        wifiPort: wifiPort,
      ),
    );

    // Register Device API Service
    _getIt.registerLazySingleton<DeviceApiService>(
      () => DeviceApiService(
        baseUrl: cloudBaseUrl,
        apiKey: cloudApiKey,
      ),
    );

    _logger.i('IoT Service Locator initialized');
  }

  /// Get IoT Connection Manager instance
  static IoTConnectionManager get connectionManager =>
      _getIt.get<IoTConnectionManager>();

  /// Get Device API Service instance
  static DeviceApiService get apiService => _getIt.get<DeviceApiService>();

  /// Check if services are registered
  static bool get isInitialized =>
      _getIt.isRegistered<IoTConnectionManager>() &&
      _getIt.isRegistered<DeviceApiService>();

  /// Reset all services
  static Future<void> reset() async {
    _logger.i('Resetting IoT Service Locator...');

    if (_getIt.isRegistered<IoTConnectionManager>()) {
      await _getIt.get<IoTConnectionManager>().dispose();
      _getIt.unregister<IoTConnectionManager>();
    }

    if (_getIt.isRegistered<DeviceApiService>()) {
      _getIt.get<DeviceApiService>().dispose();
      _getIt.unregister<DeviceApiService>();
    }

    _logger.i('IoT Service Locator reset');
  }
}
