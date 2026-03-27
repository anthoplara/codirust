import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iot_helper/flutter_iot_helper.dart';

void main() {
  group('DeviceModel Tests', () {
    test('Create device model', () {
      final device = DeviceModel(
        id: 'device-1',
        name: 'Test Device',
        type: 'Sensor',
        connectionType: DeviceConnectionType.ble,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        status: DeviceStatus.disconnected,
      );

      expect(device.id, 'device-1');
      expect(device.name, 'Test Device');
      expect(device.connectionType, DeviceConnectionType.ble);
      expect(device.macAddress, 'AA:BB:CC:DD:EE:FF');
    });

    test('Device to JSON', () {
      final device = DeviceModel(
        id: 'device-1',
        name: 'Test Device',
        type: 'Sensor',
        connectionType: DeviceConnectionType.wifi,
        ipAddress: '192.168.1.100',
      );

      final json = device.toJson();
      expect(json['id'], 'device-1');
      expect(json['name'], 'Test Device');
      expect(json['connectionType'], 'wifi');
      expect(json['ipAddress'], '192.168.1.100');
    });

    test('Device from JSON', () {
      final json = {
        'id': 'device-2',
        'name': 'Cloud Device',
        'type': 'Actuator',
        'connectionType': 'cloud',
        'cloudId': 'cloud-123',
        'status': 'connected',
      };

      final device = DeviceModel.fromJson(json);
      expect(device.id, 'device-2');
      expect(device.name, 'Cloud Device');
      expect(device.connectionType, DeviceConnectionType.cloud);
      expect(device.cloudId, 'cloud-123');
      expect(device.status, DeviceStatus.connected);
    });

    test('Device copyWith', () {
      final device = DeviceModel(
        id: 'device-1',
        name: 'Test Device',
        type: 'Sensor',
        connectionType: DeviceConnectionType.ble,
        status: DeviceStatus.disconnected,
      );

      final updatedDevice = device.copyWith(status: DeviceStatus.connected);
      expect(updatedDevice.status, DeviceStatus.connected);
      expect(updatedDevice.id, device.id);
      expect(updatedDevice.name, device.name);
    });
  });

  group('ConnectionHelper Tests', () {
    test('Validate MAC address', () {
      expect(ConnectionHelper.isValidMacAddress('AA:BB:CC:DD:EE:FF'), true);
      expect(ConnectionHelper.isValidMacAddress('AA-BB-CC-DD-EE-FF'), true);
      expect(ConnectionHelper.isValidMacAddress('AABBCCDDEEFF'), false);
      expect(ConnectionHelper.isValidMacAddress('XX:YY:ZZ:AA:BB:CC'), false);
    });

    test('Validate IP address', () {
      expect(ConnectionHelper.isValidIpAddress('192.168.1.1'), true);
      expect(ConnectionHelper.isValidIpAddress('10.0.0.1'), true);
      expect(ConnectionHelper.isValidIpAddress('256.1.1.1'), false);
      expect(ConnectionHelper.isValidIpAddress('192.168.1'), false);
    });

    test('Format MAC address', () {
      expect(
        ConnectionHelper.formatMacAddress('aabbccddeeff'),
        'AA:BB:CC:DD:EE:FF',
      );
      expect(
        ConnectionHelper.formatMacAddress('aa-bb-cc-dd-ee-ff'),
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('Calculate signal strength', () {
      expect(ConnectionHelper.calculateSignalStrength(-50), 100);
      expect(ConnectionHelper.calculateSignalStrength(-100), 0);
      expect(ConnectionHelper.calculateSignalStrength(-75), 50);
    });

    test('Get connection type label', () {
      expect(
        ConnectionHelper.getConnectionTypeLabel(DeviceConnectionType.ble),
        'Bluetooth',
      );
      expect(
        ConnectionHelper.getConnectionTypeLabel(DeviceConnectionType.wifi),
        'WiFi',
      );
      expect(
        ConnectionHelper.getConnectionTypeLabel(DeviceConnectionType.cloud),
        'Cloud',
      );
    });

    test('Check if device can connect', () {
      final bleDevice = DeviceModel(
        id: '1',
        name: 'BLE Device',
        type: 'Sensor',
        connectionType: DeviceConnectionType.ble,
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      expect(ConnectionHelper.canConnectViaBle(bleDevice), true);
      expect(ConnectionHelper.canConnectViaWifi(bleDevice), false);

      final wifiDevice = DeviceModel(
        id: '2',
        name: 'WiFi Device',
        type: 'Sensor',
        connectionType: DeviceConnectionType.wifi,
        ipAddress: '192.168.1.100',
      );

      expect(ConnectionHelper.canConnectViaWifi(wifiDevice), true);
      expect(ConnectionHelper.canConnectViaBle(wifiDevice), false);
    });

    test('Check if device is online', () {
      final onlineDevice = DeviceModel(
        id: '1',
        name: 'Online Device',
        type: 'Sensor',
        connectionType: DeviceConnectionType.cloud,
        lastSeen: DateTime.now(),
      );

      expect(ConnectionHelper.isDeviceOnline(onlineDevice), true);

      final offlineDevice = DeviceModel(
        id: '2',
        name: 'Offline Device',
        type: 'Sensor',
        connectionType: DeviceConnectionType.cloud,
        lastSeen: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(ConnectionHelper.isDeviceOnline(offlineDevice), false);
    });
  });

  group('ConnectionResult Tests', () {
    test('Create success result', () {
      final result = ConnectionResult<String>.success('Test data');
      expect(result.success, true);
      expect(result.data, 'Test data');
      expect(result.error, null);
      expect(result.type, ConnectionResultType.success);
    });

    test('Create failure result', () {
      final result = ConnectionResult<String>.failure('Error message');
      expect(result.success, false);
      expect(result.data, null);
      expect(result.error, 'Error message');
      expect(result.type, ConnectionResultType.error);
    });

    test('Create timeout result', () {
      final result = ConnectionResult<String>.timeout();
      expect(result.success, false);
      expect(result.error, 'Connection timeout');
      expect(result.type, ConnectionResultType.timeout);
    });

    test('Create unauthorized result', () {
      final result = ConnectionResult<String>.unauthorized();
      expect(result.success, false);
      expect(result.error, 'Unauthorized');
      expect(result.type, ConnectionResultType.unauthorized);
    });
  });
}
