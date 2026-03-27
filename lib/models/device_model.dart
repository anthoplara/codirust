/// Device model representing IoT device information
class DeviceModel {
  final String id;
  final String name;
  final String type;
  final DeviceConnectionType connectionType;
  final String? macAddress;
  final String? ipAddress;
  final String? cloudId;
  final DeviceStatus status;
  final Map<String, dynamic>? metadata;
  final DateTime? lastSeen;

  DeviceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.connectionType,
    this.macAddress,
    this.ipAddress,
    this.cloudId,
    this.status = DeviceStatus.disconnected,
    this.metadata,
    this.lastSeen,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      connectionType: DeviceConnectionType.values.firstWhere(
        (e) => e.name == json['connectionType'],
        orElse: () => DeviceConnectionType.cloud,
      ),
      macAddress: json['macAddress'] as String?,
      ipAddress: json['ipAddress'] as String?,
      cloudId: json['cloudId'] as String?,
      status: DeviceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeviceStatus.disconnected,
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'connectionType': connectionType.name,
      'macAddress': macAddress,
      'ipAddress': ipAddress,
      'cloudId': cloudId,
      'status': status.name,
      'metadata': metadata,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? type,
    DeviceConnectionType? connectionType,
    String? macAddress,
    String? ipAddress,
    String? cloudId,
    DeviceStatus? status,
    Map<String, dynamic>? metadata,
    DateTime? lastSeen,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      connectionType: connectionType ?? this.connectionType,
      macAddress: macAddress ?? this.macAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      cloudId: cloudId ?? this.cloudId,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// Device connection type enumeration
enum DeviceConnectionType {
  ble,
  wifi,
  cloud,
}

/// Device status enumeration
enum DeviceStatus {
  disconnected,
  connecting,
  connected,
  error,
}
