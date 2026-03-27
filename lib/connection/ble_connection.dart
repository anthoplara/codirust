import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

import '../models/device_model.dart';
import '../models/connection_result.dart';
import 'connection_interface.dart';

/// BLE Connection implementation
class BleConnection implements IDeviceConnection {
  final Logger _logger = Logger();
  final _statusController = BehaviorSubject<DeviceStatus>.seeded(
    DeviceStatus.disconnected,
  );
  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Map<String, StreamController<Map<String, dynamic>>> _dataControllers =
      {};

  // Configuration
  final String serviceUuid;
  final String characteristicUuid;

  BleConnection({
    required this.serviceUuid,
    required this.characteristicUuid,
  });

  @override
  Stream<DeviceStatus> get statusStream => _statusController.stream;

  @override
  DeviceStatus get currentStatus => _statusController.value;

  @override
  Future<ConnectionResult<DeviceModel>> connect(DeviceModel device) async {
    try {
      if (device.macAddress == null) {
        return ConnectionResult.failure('MAC address is required for BLE');
      }

      _statusController.add(DeviceStatus.connecting);

      // Check if Bluetooth is available
      if (!await FlutterBluePlus.isSupported) {
        _statusController.add(DeviceStatus.error);
        return ConnectionResult.failure('Bluetooth not supported');
      }

      // Turn on Bluetooth if off
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }

      // Find device
      final scanResults = await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      ).then((_) => FlutterBluePlus.lastScanResults);

      final scanResult = scanResults.firstWhere(
        (result) =>
            result.device.remoteId.str.toLowerCase() ==
            device.macAddress!.toLowerCase(),
        orElse: () => throw Exception('Device not found'),
      );

      final bleDevice = scanResult.device;

      // Connect to device
      await bleDevice.connect(timeout: const Duration(seconds: 15));
      _connectedDevices[device.id] = bleDevice;

      // Discover services
      await bleDevice.discoverServices();

      _statusController.add(DeviceStatus.connected);
      _logger.i('Connected to BLE device: ${device.name}');

      return ConnectionResult.success(
        device.copyWith(
          status: DeviceStatus.connected,
          lastSeen: DateTime.now(),
        ),
      );
    } on TimeoutException {
      _statusController.add(DeviceStatus.error);
      return ConnectionResult.timeout();
    } catch (e) {
      _statusController.add(DeviceStatus.error);
      _logger.e('BLE connection error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Future<ConnectionResult<bool>> disconnect(String deviceId) async {
    try {
      final device = _connectedDevices[deviceId];
      if (device == null) {
        return ConnectionResult.failure('Device not found');
      }

      await device.disconnect();
      _connectedDevices.remove(deviceId);
      _dataControllers[deviceId]?.close();
      _dataControllers.remove(deviceId);

      if (_connectedDevices.isEmpty) {
        _statusController.add(DeviceStatus.disconnected);
      }

      _logger.i('Disconnected from BLE device: $deviceId');
      return ConnectionResult.success(true);
    } catch (e) {
      _logger.e('BLE disconnection error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Future<ConnectionResult<dynamic>> sendData(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final device = _connectedDevices[deviceId];
      if (device == null) {
        return ConnectionResult.failure('Device not connected');
      }

      // Find the characteristic
      final services = await device.discoverServices();
      BluetoothCharacteristic? targetCharacteristic;

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() ==
                characteristicUuid.toLowerCase()) {
              targetCharacteristic = char;
              break;
            }
          }
        }
      }

      if (targetCharacteristic == null) {
        return ConnectionResult.failure('Characteristic not found');
      }

      // Convert data to bytes (you may need to customize this)
      final bytes = data.toString().codeUnits;
      await targetCharacteristic.write(bytes);

      _logger.d('Sent data to BLE device: $deviceId');
      return ConnectionResult.success(true);
    } catch (e) {
      _logger.e('BLE send data error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Stream<Map<String, dynamic>> receiveData(String deviceId) {
    if (!_dataControllers.containsKey(deviceId)) {
      _dataControllers[deviceId] =
          StreamController<Map<String, dynamic>>.broadcast();
      _setupDataListener(deviceId);
    }
    return _dataControllers[deviceId]!.stream;
  }

  Future<void> _setupDataListener(String deviceId) async {
    try {
      final device = _connectedDevices[deviceId];
      if (device == null) return;

      final services = await device.discoverServices();
      BluetoothCharacteristic? targetCharacteristic;

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() ==
                characteristicUuid.toLowerCase()) {
              targetCharacteristic = char;
              break;
            }
          }
        }
      }

      if (targetCharacteristic != null) {
        await targetCharacteristic.setNotifyValue(true);
        targetCharacteristic.lastValueStream.listen((value) {
          if (_dataControllers.containsKey(deviceId)) {
            // Parse received data (customize as needed)
            final data = {'raw': value, 'timestamp': DateTime.now()};
            _dataControllers[deviceId]!.add(data);
          }
        });
      }
    } catch (e) {
      _logger.e('Error setting up BLE data listener: $e');
    }
  }

  @override
  bool isConnected(String deviceId) {
    final device = _connectedDevices[deviceId];
    return device != null && device.isConnected;
  }

  @override
  Future<ConnectionResult<List<DeviceModel>>> discoverDevices() async {
    try {
      // Check Bluetooth availability
      if (!await FlutterBluePlus.isSupported) {
        return ConnectionResult.failure('Bluetooth not supported');
      }

      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      final results = FlutterBluePlus.lastScanResults;

      final devices = results.map((result) {
        return DeviceModel(
          id: result.device.remoteId.str,
          name: result.device.platformName.isNotEmpty
              ? result.device.platformName
              : 'Unknown Device',
          type: 'BLE',
          connectionType: DeviceConnectionType.ble,
          macAddress: result.device.remoteId.str,
          status: DeviceStatus.disconnected,
          metadata: {
            'rssi': result.rssi,
            'advertisementData': result.advertisementData.serviceUuids,
          },
        );
      }).toList();

      await FlutterBluePlus.stopScan();
      _logger.i('Discovered ${devices.length} BLE devices');

      return ConnectionResult.success(devices);
    } catch (e) {
      _logger.e('BLE discovery error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Future<void> dispose() async {
    for (var device in _connectedDevices.values) {
      await device.disconnect();
    }
    _connectedDevices.clear();

    for (var controller in _dataControllers.values) {
      await controller.close();
    }
    _dataControllers.clear();

    await _statusController.close();
  }
}
