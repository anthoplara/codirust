import 'dart:async';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

import '../connection/connection_interface.dart';
import '../connection/ble_connection.dart';
import '../connection/wifi_connection.dart';
import '../connection/cloud_connection.dart';
import '../models/device_model.dart';
import '../models/connection_result.dart';

/// Main IoT Connection Manager
/// Manages connections to devices via BLE, WiFi, and Cloud
class IoTConnectionManager {
  final Logger _logger = Logger();

  // Connection handlers
  late final BleConnection _bleConnection;
  late final WifiConnection _wifiConnection;
  late final CloudConnection _cloudConnection;

  // State management
  final _devicesController = BehaviorSubject<List<DeviceModel>>.seeded([]);
  final _activeConnectionsController =
      BehaviorSubject<Map<String, DeviceModel>>.seeded({});
  final _connectionStatusController =
      BehaviorSubject<ConnectionManagerStatus>.seeded(
    ConnectionManagerStatus.idle,
  );

  Map<String, DeviceModel> _activeConnections = {};
  List<DeviceModel> _discoveredDevices = [];

  // Configuration
  final String cloudBaseUrl;
  final String? cloudApiKey;
  final String bleServiceUuid;
  final String bleCharacteristicUuid;
  final int wifiPort;

  IoTConnectionManager({
    required this.cloudBaseUrl,
    this.cloudApiKey,
    required this.bleServiceUuid,
    required this.bleCharacteristicUuid,
    this.wifiPort = 80,
  }) {
    _initializeConnections();
  }

  void _initializeConnections() {
    _bleConnection = BleConnection(
      serviceUuid: bleServiceUuid,
      characteristicUuid: bleCharacteristicUuid,
    );

    _wifiConnection = WifiConnection(port: wifiPort);

    _cloudConnection = CloudConnection(
      baseUrl: cloudBaseUrl,
      apiKey: cloudApiKey,
    );

    _logger.i('IoT Connection Manager initialized');
  }

  // Getters
  Stream<List<DeviceModel>> get devicesStream => _devicesController.stream;
  List<DeviceModel> get devices => _discoveredDevices;

  Stream<Map<String, DeviceModel>> get activeConnectionsStream =>
      _activeConnectionsController.stream;
  Map<String, DeviceModel> get activeConnections => _activeConnections;

  Stream<ConnectionManagerStatus> get statusStream =>
      _connectionStatusController.stream;
  ConnectionManagerStatus get status => _connectionStatusController.value;

  /// Discover devices across all connection types
  Future<ConnectionResult<List<DeviceModel>>> discoverAllDevices() async {
    try {
      _connectionStatusController.add(ConnectionManagerStatus.discovering);
      _logger.i('Starting device discovery...');

      final allDevices = <DeviceModel>[];

      // Discover BLE devices
      final bleResult = await _bleConnection.discoverDevices();
      if (bleResult.success && bleResult.data != null) {
        allDevices.addAll(bleResult.data!);
        _logger.i('Found ${bleResult.data!.length} BLE devices');
      }

      // Discover WiFi devices
      final wifiResult = await _wifiConnection.discoverDevices();
      if (wifiResult.success && wifiResult.data != null) {
        allDevices.addAll(wifiResult.data!);
        _logger.i('Found ${wifiResult.data!.length} WiFi devices');
      }

      // Discover Cloud devices
      final cloudResult = await _cloudConnection.discoverDevices();
      if (cloudResult.success && cloudResult.data != null) {
        allDevices.addAll(cloudResult.data!);
        _logger.i('Found ${cloudResult.data!.length} Cloud devices');
      }

      _discoveredDevices = allDevices;
      _devicesController.add(_discoveredDevices);
      _connectionStatusController.add(ConnectionManagerStatus.idle);

      _logger.i('Total devices discovered: ${allDevices.length}');
      return ConnectionResult.success(allDevices);
    } catch (e) {
      _logger.e('Error during device discovery: $e');
      _connectionStatusController.add(ConnectionManagerStatus.error);
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Discover devices by specific connection type
  Future<ConnectionResult<List<DeviceModel>>> discoverDevicesByType(
    DeviceConnectionType type,
  ) async {
    try {
      _connectionStatusController.add(ConnectionManagerStatus.discovering);

      ConnectionResult<List<DeviceModel>> result;

      switch (type) {
        case DeviceConnectionType.ble:
          result = await _bleConnection.discoverDevices();
          break;
        case DeviceConnectionType.wifi:
          result = await _wifiConnection.discoverDevices();
          break;
        case DeviceConnectionType.cloud:
          result = await _cloudConnection.discoverDevices();
          break;
      }

      if (result.success && result.data != null) {
        // Update discovered devices list
        _discoveredDevices.removeWhere((d) => d.connectionType == type);
        _discoveredDevices.addAll(result.data!);
        _devicesController.add(_discoveredDevices);
      }

      _connectionStatusController.add(ConnectionManagerStatus.idle);
      return result;
    } catch (e) {
      _logger.e('Error discovering devices by type: $e');
      _connectionStatusController.add(ConnectionManagerStatus.error);
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Connect to a specific device
  Future<ConnectionResult<DeviceModel>> connectToDevice(
    DeviceModel device,
  ) async {
    try {
      _connectionStatusController.add(ConnectionManagerStatus.connecting);
      _logger.i('Connecting to device: ${device.name}');

      IDeviceConnection connection = _getConnectionByType(device.connectionType);
      final result = await connection.connect(device);

      if (result.success && result.data != null) {
        _activeConnections[device.id] = result.data!;
        _activeConnectionsController.add(_activeConnections);
        _logger.i('Successfully connected to: ${device.name}');
      }

      _connectionStatusController.add(ConnectionManagerStatus.idle);
      return result;
    } catch (e) {
      _logger.e('Error connecting to device: $e');
      _connectionStatusController.add(ConnectionManagerStatus.error);
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Disconnect from a specific device
  Future<ConnectionResult<bool>> disconnectFromDevice(String deviceId) async {
    try {
      final device = _activeConnections[deviceId];
      if (device == null) {
        return ConnectionResult.failure('Device not found in active connections');
      }

      _logger.i('Disconnecting from device: ${device.name}');

      IDeviceConnection connection = _getConnectionByType(device.connectionType);
      final result = await connection.disconnect(deviceId);

      if (result.success) {
        _activeConnections.remove(deviceId);
        _activeConnectionsController.add(_activeConnections);
        _logger.i('Successfully disconnected from: ${device.name}');
      }

      return result;
    } catch (e) {
      _logger.e('Error disconnecting from device: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Disconnect all devices
  Future<void> disconnectAll() async {
    _logger.i('Disconnecting all devices...');
    final deviceIds = _activeConnections.keys.toList();

    for (var deviceId in deviceIds) {
      await disconnectFromDevice(deviceId);
    }

    _logger.i('All devices disconnected');
  }

  /// Send data to a device
  Future<ConnectionResult<dynamic>> sendDataToDevice(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final device = _activeConnections[deviceId];
      if (device == null) {
        return ConnectionResult.failure('Device not connected');
      }

      IDeviceConnection connection = _getConnectionByType(device.connectionType);
      return await connection.sendData(deviceId, data);
    } catch (e) {
      _logger.e('Error sending data to device: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Receive data stream from a device
  Stream<Map<String, dynamic>> receiveDataFromDevice(String deviceId) {
    try {
      final device = _activeConnections[deviceId];
      if (device == null) {
        return Stream.error('Device not connected');
      }

      IDeviceConnection connection = _getConnectionByType(device.connectionType);
      return connection.receiveData(deviceId);
    } catch (e) {
      _logger.e('Error receiving data from device: $e');
      return Stream.error(e.toString());
    }
  }

  /// Check if a device is connected
  bool isDeviceConnected(String deviceId) {
    return _activeConnections.containsKey(deviceId);
  }

  /// Get device by ID
  DeviceModel? getDevice(String deviceId) {
    return _discoveredDevices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => _activeConnections[deviceId]!,
    );
  }

  /// Update cloud API key
  void updateCloudApiKey(String apiKey) {
    _cloudConnection.updateApiKey(apiKey);
    _logger.i('Cloud API key updated');
  }

  /// Get connection handler by type
  IDeviceConnection _getConnectionByType(DeviceConnectionType type) {
    switch (type) {
      case DeviceConnectionType.ble:
        return _bleConnection;
      case DeviceConnectionType.wifi:
        return _wifiConnection;
      case DeviceConnectionType.cloud:
        return _cloudConnection;
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    _logger.i('Disposing IoT Connection Manager...');
    
    await disconnectAll();
    
    await _bleConnection.dispose();
    await _wifiConnection.dispose();
    await _cloudConnection.dispose();
    
    await _devicesController.close();
    await _activeConnectionsController.close();
    await _connectionStatusController.close();
    
    _logger.i('IoT Connection Manager disposed');
  }
}

/// Connection Manager Status
enum ConnectionManagerStatus {
  idle,
  discovering,
  connecting,
  error,
}
