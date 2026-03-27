import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../models/device_model.dart';
import '../models/connection_result.dart';

/// Service for fetching device data from API
class DeviceApiService {
  final Logger _logger = Logger();
  final Dio _dio;
  final String baseUrl;
  final String? apiKey;

  DeviceApiService({
    required this.baseUrl,
    this.apiKey,
    Duration timeout = const Duration(seconds: 30),
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
          _logger.d('API Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('API Response: ${response.statusCode}');
          return handler.next(response);
        },
        onError: (error, handler) {
          _logger.e('API Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  /// Get all devices from API
  Future<ConnectionResult<List<DeviceModel>>> getDevices() async {
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

        final devices = deviceList
            .map((item) => DeviceModel.fromJson(item as Map<String, dynamic>))
            .toList();

        _logger.i('Fetched ${devices.length} devices from API');
        return ConnectionResult.success(devices);
      } else {
        return ConnectionResult.failure(
          'Failed to fetch devices: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error fetching devices: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Get device by ID
  Future<ConnectionResult<DeviceModel>> getDeviceById(String deviceId) async {
    try {
      final response = await _dio.get('/devices/$deviceId');

      if (response.statusCode == 200) {
        final device =
            DeviceModel.fromJson(response.data as Map<String, dynamic>);
        _logger.i('Fetched device: ${device.name}');
        return ConnectionResult.success(device);
      } else {
        return ConnectionResult.failure(
          'Failed to fetch device: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error fetching device: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Get device telemetry/sensor data
  Future<ConnectionResult<Map<String, dynamic>>> getDeviceData(
    String deviceId, {
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startTime != null) {
        queryParams['startTime'] = startTime.toIso8601String();
      }
      if (endTime != null) {
        queryParams['endTime'] = endTime.toIso8601String();
      }

      final response = await _dio.get(
        '/devices/$deviceId/data',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _logger.i('Fetched data for device: $deviceId');
        return ConnectionResult.success(data);
      } else {
        return ConnectionResult.failure(
          'Failed to fetch device data: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error fetching device data: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Get device status
  Future<ConnectionResult<DeviceStatus>> getDeviceStatus(
    String deviceId,
  ) async {
    try {
      final response = await _dio.get('/devices/$deviceId/status');

      if (response.statusCode == 200) {
        final statusStr = response.data['status'] as String? ?? 'disconnected';
        final status = _parseDeviceStatus(statusStr);
        _logger.i('Device $deviceId status: ${status.name}');
        return ConnectionResult.success(status);
      } else {
        return ConnectionResult.failure(
          'Failed to fetch device status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error fetching device status: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Register a new device
  Future<ConnectionResult<DeviceModel>> registerDevice(
    Map<String, dynamic> deviceData,
  ) async {
    try {
      final response = await _dio.post(
        '/devices',
        data: deviceData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final device =
            DeviceModel.fromJson(response.data as Map<String, dynamic>);
        _logger.i('Registered device: ${device.name}');
        return ConnectionResult.success(device);
      } else {
        return ConnectionResult.failure(
          'Failed to register device: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error registering device: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Update device information
  Future<ConnectionResult<DeviceModel>> updateDevice(
    String deviceId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dio.put(
        '/devices/$deviceId',
        data: updates,
      );

      if (response.statusCode == 200) {
        final device =
            DeviceModel.fromJson(response.data as Map<String, dynamic>);
        _logger.i('Updated device: ${device.name}');
        return ConnectionResult.success(device);
      } else {
        return ConnectionResult.failure(
          'Failed to update device: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error updating device: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Delete a device
  Future<ConnectionResult<bool>> deleteDevice(String deviceId) async {
    try {
      final response = await _dio.delete('/devices/$deviceId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i('Deleted device: $deviceId');
        return ConnectionResult.success(true);
      } else {
        return ConnectionResult.failure(
          'Failed to delete device: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error deleting device: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Send command to device
  Future<ConnectionResult<Map<String, dynamic>>> sendCommand(
    String deviceId,
    String command,
    Map<String, dynamic>? parameters,
  ) async {
    try {
      final response = await _dio.post(
        '/devices/$deviceId/commands',
        data: {
          'command': command,
          if (parameters != null) 'parameters': parameters,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = response.data as Map<String, dynamic>;
        _logger.i('Command sent to device $deviceId: $command');
        return ConnectionResult.success(result);
      } else {
        return ConnectionResult.failure(
          'Failed to send command: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error sending command: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Get device configuration
  Future<ConnectionResult<Map<String, dynamic>>> getDeviceConfig(
    String deviceId,
  ) async {
    try {
      final response = await _dio.get('/devices/$deviceId/config');

      if (response.statusCode == 200) {
        final config = response.data as Map<String, dynamic>;
        _logger.i('Fetched config for device: $deviceId');
        return ConnectionResult.success(config);
      } else {
        return ConnectionResult.failure(
          'Failed to fetch device config: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error fetching device config: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Update device configuration
  Future<ConnectionResult<Map<String, dynamic>>> updateDeviceConfig(
    String deviceId,
    Map<String, dynamic> config,
  ) async {
    try {
      final response = await _dio.put(
        '/devices/$deviceId/config',
        data: config,
      );

      if (response.statusCode == 200) {
        final updatedConfig = response.data as Map<String, dynamic>;
        _logger.i('Updated config for device: $deviceId');
        return ConnectionResult.success(updatedConfig);
      } else {
        return ConnectionResult.failure(
          'Failed to update device config: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      _logger.e('Error updating device config: $e');
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Update API key
  void updateApiKey(String newApiKey) {
    _dio.options.headers['Authorization'] = 'Bearer $newApiKey';
    _logger.i('API key updated');
  }

  /// Parse device status from string
  DeviceStatus _parseDeviceStatus(String status) {
    switch (status.toLowerCase()) {
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

  /// Handle Dio exceptions
  ConnectionResult<T> _handleDioException<T>(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ConnectionResult.timeout();
    }
    if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
      return ConnectionResult.unauthorized();
    }
    _logger.e('DioException: ${e.message}');
    return ConnectionResult.failure(e.message ?? 'Unknown error');
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
