import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

import '../models/device_model.dart';
import '../models/connection_result.dart';
import 'connection_interface.dart';

/// WiFi (Local Network) Connection implementation
class WifiConnection implements IDeviceConnection {
  final Logger _logger = Logger();
  final _statusController = BehaviorSubject<DeviceStatus>.seeded(
    DeviceStatus.disconnected,
  );
  final Map<String, String> _connectedDevices = {}; // deviceId -> IP
  final Map<String, StreamController<Map<String, dynamic>>> _dataControllers =
      {};
  final Map<String, Timer?> _pollingTimers = {};

  final NetworkInfo _networkInfo = NetworkInfo();
  final Connectivity _connectivity = Connectivity();

  // Configuration
  final int port;
  final Duration timeout;
  final Duration pollingInterval;

  WifiConnection({
    this.port = 80,
    this.timeout = const Duration(seconds: 10),
    this.pollingInterval = const Duration(seconds: 5),
  });

  @override
  Stream<DeviceStatus> get statusStream => _statusController.stream;

  @override
  DeviceStatus get currentStatus => _statusController.value;

  /// Check if device is on same WiFi network
  Future<bool> _isOnSameNetwork() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.wifi);
  }

  @override
  Future<ConnectionResult<DeviceModel>> connect(DeviceModel device) async {
    try {
      if (device.ipAddress == null) {
        return ConnectionResult.failure('IP address is required for WiFi');
      }

      _statusController.add(DeviceStatus.connecting);

      // Check WiFi connectivity
      if (!await _isOnSameNetwork()) {
        _statusController.add(DeviceStatus.error);
        return ConnectionResult.failure('Not connected to WiFi network');
      }

      // Test connection with a ping/health check
      final url = Uri.parse('http://${device.ipAddress}:$port/health');
      final response = await http.get(url).timeout(timeout);

      if (response.statusCode == 200) {
        _connectedDevices[device.id] = device.ipAddress!;
        _statusController.add(DeviceStatus.connected);
        _logger.i('Connected to WiFi device: ${device.name}');

        return ConnectionResult.success(
          device.copyWith(
            status: DeviceStatus.connected,
            lastSeen: DateTime.now(),
          ),
        );
      } else {
        _statusController.add(DeviceStatus.error);
        return ConnectionResult.failure(
          'Connection failed with status: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      _statusController.add(DeviceStatus.error);
      return ConnectionResult.timeout();
    } catch (e) {
      _statusController.add(DeviceStatus.error);
      _logger.e('WiFi connection error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Future<ConnectionResult<bool>> disconnect(String deviceId) async {
    try {
      _connectedDevices.remove(deviceId);
      _dataControllers[deviceId]?.close();
      _dataControllers.remove(deviceId);
      _pollingTimers[deviceId]?.cancel();
      _pollingTimers.remove(deviceId);

      if (_connectedDevices.isEmpty) {
        _statusController.add(DeviceStatus.disconnected);
      }

      _logger.i('Disconnected from WiFi device: $deviceId');
      return ConnectionResult.success(true);
    } catch (e) {
      _logger.e('WiFi disconnection error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Future<ConnectionResult<dynamic>> sendData(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final ipAddress = _connectedDevices[deviceId];
      if (ipAddress == null) {
        return ConnectionResult.failure('Device not connected');
      }

      final url = Uri.parse('http://$ipAddress:$port/api/data');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.d('Sent data to WiFi device: $deviceId');
        final responseData = json.decode(response.body);
        return ConnectionResult.success(responseData);
      } else {
        return ConnectionResult.failure(
          'Failed to send data: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      return ConnectionResult.timeout();
    } catch (e) {
      _logger.e('WiFi send data error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Stream<Map<String, dynamic>> receiveData(String deviceId) {
    if (!_dataControllers.containsKey(deviceId)) {
      _dataControllers[deviceId] =
          StreamController<Map<String, dynamic>>.broadcast();
      _startPolling(deviceId);
    }
    return _dataControllers[deviceId]!.stream;
  }

  void _startPolling(String deviceId) {
    _pollingTimers[deviceId] = Timer.periodic(pollingInterval, (timer) async {
      try {
        final ipAddress = _connectedDevices[deviceId];
        if (ipAddress == null) {
          timer.cancel();
          return;
        }

        final url = Uri.parse('http://$ipAddress:$port/api/data');
        final response = await http.get(url).timeout(timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          data['timestamp'] = DateTime.now().toIso8601String();
          
          if (_dataControllers.containsKey(deviceId)) {
            _dataControllers[deviceId]!.add(data);
          }
        }
      } catch (e) {
        _logger.e('WiFi polling error: $e');
      }
    });
  }

  @override
  bool isConnected(String deviceId) {
    return _connectedDevices.containsKey(deviceId);
  }

  @override
  Future<ConnectionResult<List<DeviceModel>>> discoverDevices() async {
    try {
      // Check WiFi connectivity
      if (!await _isOnSameNetwork()) {
        return ConnectionResult.failure('Not connected to WiFi network');
      }

      // Get local IP to determine subnet
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) {
        return ConnectionResult.failure('Could not get WiFi IP');
      }

      _logger.i('Scanning network: $wifiIP');

      // Extract subnet (e.g., "192.168.1.x" -> "192.168.1")
      final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
      final devices = <DeviceModel>[];

      // Scan common device ports (simplified scan)
      // In production, you might want to use mDNS/Bonjour for discovery
      final futures = <Future>[];
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        futures.add(_checkDevice(ip).then((device) {
          if (device != null) {
            devices.add(device);
          }
        }));

        // Batch requests to avoid overwhelming the network
        if (i % 50 == 0) {
          await Future.wait(futures);
          futures.clear();
        }
      }

      await Future.wait(futures);
      _logger.i('Discovered ${devices.length} WiFi devices');

      return ConnectionResult.success(devices);
    } catch (e) {
      _logger.e('WiFi discovery error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  Future<DeviceModel?> _checkDevice(String ip) async {
    try {
      final url = Uri.parse('http://$ip:$port/info');
      final response = await http.get(url).timeout(
            const Duration(seconds: 2),
          );

      if (response.statusCode == 200) {
        final info = json.decode(response.body);
        return DeviceModel(
          id: info['id'] ?? ip,
          name: info['name'] ?? 'Device at $ip',
          type: info['type'] ?? 'WiFi Device',
          connectionType: DeviceConnectionType.wifi,
          ipAddress: ip,
          status: DeviceStatus.disconnected,
          metadata: info,
        );
      }
    } catch (e) {
      // Device not found or not responding
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    _connectedDevices.clear();

    for (var timer in _pollingTimers.values) {
      timer?.cancel();
    }
    _pollingTimers.clear();

    for (var controller in _dataControllers.values) {
      await controller.close();
    }
    _dataControllers.clear();

    await _statusController.close();
  }
}
