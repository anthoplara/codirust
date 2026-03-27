import 'dart:async';
import '../models/device_model.dart';
import '../models/connection_result.dart';

/// Base interface for all connection types
abstract class IDeviceConnection {
  /// Stream of connection status changes
  Stream<DeviceStatus> get statusStream;

  /// Current connection status
  DeviceStatus get currentStatus;

  /// Connect to a device
  Future<ConnectionResult<DeviceModel>> connect(DeviceModel device);

  /// Disconnect from a device
  Future<ConnectionResult<bool>> disconnect(String deviceId);

  /// Send data to device
  Future<ConnectionResult<dynamic>> sendData(
    String deviceId,
    Map<String, dynamic> data,
  );

  /// Receive data from device
  Stream<Map<String, dynamic>> receiveData(String deviceId);

  /// Check if device is connected
  bool isConnected(String deviceId);

  /// Get list of available devices
  Future<ConnectionResult<List<DeviceModel>>> discoverDevices();

  /// Dispose resources
  Future<void> dispose();
}
