import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

import '../models/device_model.dart';
import '../models/connection_result.dart';
import 'connection_interface.dart';

/// Cloud API Connection implementation
class CloudConnection implements IDeviceConnection {
  final Logger _logger = Logger();
  final Dio _dio;
  final _statusController = BehaviorSubject<DeviceStatus>.seeded(
    DeviceStatus.disconnected,
  );
  final Map<String, bool> _connectedDevices = {};
  final Map<String, StreamController<Map<String, dynamic>>> _dataControllers =
      {};
  final Map<String, Timer?> _pollingTimers = {};

  // Configuration
  final String baseUrl;
  final String? apiKey;
  final Duration timeout;
  final Duration pollingInterval;

  CloudConnection({
    required this.baseUrl,
    this.apiKey,
    this.timeout = const Duration(seconds: 30),
    this.pollingInterval = const Duration(seconds: 10),
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: timeout,
          receiveTimeout: timeout,
          headers: {
            'Content-Type': 'application/json',
            if (apiKey != null) 'Authorization': 'Bearer $apiKey',
          },
        )) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.d('Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('Response: ${response.statusCode} ${response.data}');
          return handler.next(response);
        },
        onError: (error, handler) {
          _logger.e('Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  @override
  Stream<DeviceStatus> get statusStream => _statusController.stream;

  @override
  DeviceStatus get currentStatus => _statusController.value;

  @override
  Future<ConnectionResult<DeviceModel>> connect(DeviceModel device) async {
    try {
      if (device.cloudId == null) {
        return ConnectionResult.failure('Cloud ID is required');
      }

      _statusController.add(DeviceStatus.connecting);

      // Connect to cloud device
      final response = await _dio.post(
        '/devices/${device.cloudId}/connect',
        data: {'timestamp': DateTime.now().toIso8601String()},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _connectedDevices[device.id] = true;
        _statusController.add(DeviceStatus.connected);
        _logger.i('Connected to cloud device: ${device.name}');

        // Parse response data
        final deviceData = response.data is Map
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};

        return ConnectionResult.success(
          device.copyWith(
            status: DeviceStatus.connected,
            lastSeen: DateTime.now(),
            metadata: deviceData,
          ),
        );
      } else {
        _statusController.add(DeviceStatus.error);
        return ConnectionResult.failure(
          'Connection failed with status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      _statusController.add(DeviceStatus.error);
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return ConnectionResult.timeout();
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return ConnectionResult.unauthorized();
      }
      _logger.e('Cloud connection error: ${e.message}');
      return ConnectionResult.failure(e.message ?? 'Unknown error');
    } catch (e) {
      _statusController.add(DeviceStatus.error);
      _logger.e('Cloud connection error: $e');
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

      await _dio.post('/devices/$deviceId/disconnect');

      _connectedDevices.remove(deviceId);
      _dataControllers[deviceId]?.close();
      _dataControllers.remove(deviceId);
      _pollingTimers[deviceId]?.cancel();
      _pollingTimers.remove(deviceId);

      if (_connectedDevices.isEmpty) {
        _statusController.add(DeviceStatus.disconnected);
      }

      _logger.i('Disconnected from cloud device: $deviceId');
      return ConnectionResult.success(true);
    } catch (e) {
      _logger.e('Cloud disconnection error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Future<ConnectionResult<dynamic>> sendData(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (!_connectedDevices.containsKey(deviceId)) {
        return ConnectionResult.failure('Device not connected');
      }

      final response = await _dio.post(
        '/devices/$deviceId/data',
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.d('Sent data to cloud device: $deviceId');
        return ConnectionResult.success(response.data);
      } else {
        return ConnectionResult.failure(
          'Failed to send data: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return ConnectionResult.timeout();
      }
      _logger.e('Cloud send data error: ${e.message}');
      return ConnectionResult.failure(e.message ?? 'Unknown error');
    } catch (e) {
      _logger.e('Cloud send data error: $e');
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
        if (!_connectedDevices.containsKey(deviceId)) {
          timer.cancel();
          return;
        }

        final response = await _dio.get('/devices/$deviceId/data');

        if (response.statusCode == 200) {
          final data = response.data is Map
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{'raw': response.data};
          
          data['timestamp'] = DateTime.now().toIso8601String();

          if (_dataControllers.containsKey(deviceId)) {
            _dataControllers[deviceId]!.add(data);
          }
        }
      } catch (e) {
        _logger.e('Cloud polling error: $e');
      }
    });
  }

  @override
  bool isConnected(String deviceId) {
    return _connectedDevices.containsKey(deviceId) &&
        _connectedDevices[deviceId] == true;
  }

  @override
  Future<ConnectionResult<List<DeviceModel>>> discoverDevices() async {
    try {
      final response = await _dio.get('/devices');

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> deviceList;

        if (data is List) {
          deviceList = data;
        } else if (data is Map && data.containsKey('devices')) {
          deviceList = data['devices'] as List;
        } else {
          return ConnectionResult.failure('Invalid response format');
        }

        final devices = deviceList.map((item) {
          final deviceData = item as Map<String, dynamic>;
          return DeviceModel(
            id: deviceData['id'] ?? deviceData['cloudId'] ?? '',
            name: deviceData['name'] ?? 'Unknown Device',
            type: deviceData['type'] ?? 'Cloud Device',
            connectionType: DeviceConnectionType.cloud,
            cloudId: deviceData['cloudId'] ?? deviceData['id'],
            status: _parseStatus(deviceData['status']),
            metadata: deviceData,
            lastSeen: deviceData['lastSeen'] != null
                ? DateTime.tryParse(deviceData['lastSeen'])
                : null,
          );
        }).toList();

        _logger.i('Discovered ${devices.length} cloud devices');
        return ConnectionResult.success(devices);
      } else {
        return ConnectionResult.failure(
          'Discovery failed with status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return ConnectionResult.timeout();
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return ConnectionResult.unauthorized();
      }
      _logger.e('Cloud discovery error: ${e.message}');
      return ConnectionResult.failure(e.message ?? 'Unknown error');
    } catch (e) {
      _logger.e('Cloud discovery error: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  DeviceStatus _parseStatus(dynamic status) {
    if (status == null) return DeviceStatus.disconnected;
    
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'connected':
      case 'online':
        return DeviceStatus.connected;
      case 'connecting':
        return DeviceStatus.connecting;
      case 'error':
      case 'offline':
        return DeviceStatus.error;
      default:
        return DeviceStatus.disconnected;
    }
  }

  /// Update API key for authentication
  void updateApiKey(String newApiKey) {
    _dio.options.headers['Authorization'] = 'Bearer $newApiKey';
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
    _dio.close();
  }
}
