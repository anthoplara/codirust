import '../models/device_model.dart';

/// Helper utilities for connection management
class ConnectionHelper {
  /// Check if device can connect via BLE
  static bool canConnectViaBle(DeviceModel device) {
    return device.connectionType == DeviceConnectionType.ble &&
        device.macAddress != null &&
        device.macAddress!.isNotEmpty;
  }

  /// Check if device can connect via WiFi
  static bool canConnectViaWifi(DeviceModel device) {
    return device.connectionType == DeviceConnectionType.wifi &&
        device.ipAddress != null &&
        device.ipAddress!.isNotEmpty;
  }

  /// Check if device can connect via Cloud
  static bool canConnectViaCloud(DeviceModel device) {
    return device.connectionType == DeviceConnectionType.cloud &&
        device.cloudId != null &&
        device.cloudId!.isNotEmpty;
  }

  /// Validate MAC address format
  static bool isValidMacAddress(String macAddress) {
    // Format: XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX
    final regex = RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
    );
    return regex.hasMatch(macAddress);
  }

  /// Validate IP address format
  static bool isValidIpAddress(String ipAddress) {
    // Format: XXX.XXX.XXX.XXX
    final regex = RegExp(
      r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return regex.hasMatch(ipAddress);
  }

  /// Get connection type label
  static String getConnectionTypeLabel(DeviceConnectionType type) {
    switch (type) {
      case DeviceConnectionType.ble:
        return 'Bluetooth';
      case DeviceConnectionType.wifi:
        return 'WiFi';
      case DeviceConnectionType.cloud:
        return 'Cloud';
    }
  }

  /// Get device status label
  static String getDeviceStatusLabel(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.connected:
        return 'Connected';
      case DeviceStatus.connecting:
        return 'Connecting...';
      case DeviceStatus.disconnected:
        return 'Disconnected';
      case DeviceStatus.error:
        return 'Error';
    }
  }

  /// Get recommended connection type based on device info
  static DeviceConnectionType? getRecommendedConnectionType(
    DeviceModel device,
  ) {
    // Priority: WiFi > BLE > Cloud
    if (canConnectViaWifi(device)) {
      return DeviceConnectionType.wifi;
    } else if (canConnectViaBle(device)) {
      return DeviceConnectionType.ble;
    } else if (canConnectViaCloud(device)) {
      return DeviceConnectionType.cloud;
    }
    return null;
  }

  /// Calculate signal strength from RSSI (for BLE)
  static int calculateSignalStrength(int rssi) {
    // Convert RSSI to percentage (0-100)
    // Typical RSSI range: -100 (weak) to -50 (strong)
    if (rssi >= -50) return 100;
    if (rssi <= -100) return 0;
    return ((rssi + 100) * 2).round();
  }

  /// Format MAC address to standard format
  static String formatMacAddress(String macAddress) {
    // Remove any separators
    final clean = macAddress.replaceAll(RegExp(r'[:-]'), '');
    
    // Add colons every 2 characters
    final formatted = StringBuffer();
    for (int i = 0; i < clean.length; i += 2) {
      if (i > 0) formatted.write(':');
      formatted.write(clean.substring(i, i + 2).toUpperCase());
    }
    
    return formatted.toString();
  }

  /// Check if device is online (based on lastSeen)
  static bool isDeviceOnline(DeviceModel device, {Duration threshold = const Duration(minutes: 5)}) {
    if (device.lastSeen == null) return false;
    final now = DateTime.now();
    final difference = now.difference(device.lastSeen!);
    return difference <= threshold;
  }
}
