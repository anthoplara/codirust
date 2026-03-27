/// Flutter IoT Helper Library
/// 
/// A comprehensive library for managing IoT device connections via BLE, WiFi, and Cloud.
library flutter_iot_helper;

// Models
export 'models/device_model.dart';
export 'models/connection_result.dart';

// Services
export 'services/iot_connection_manager.dart';
export 'services/device_api_service.dart';

// Connection implementations
export 'connection/connection_interface.dart';
export 'connection/ble_connection.dart';
export 'connection/wifi_connection.dart';
export 'connection/cloud_connection.dart';

// Helpers
export 'helpers/iot_service_locator.dart';
export 'helpers/connection_helper.dart';
