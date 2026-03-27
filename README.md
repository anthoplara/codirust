# Flutter IoT Helper

Flutter helper/service library untuk manajemen koneksi IoT device melalui BLE, WiFi (jaringan lokal), dan Cloud API.

## Fitur

- ✅ **Multi-Protocol Support**: BLE, WiFi Local Network, Cloud API
- ✅ **Connection Management**: Connect, disconnect, auto-reconnect
- ✅ **Device Discovery**: Scan dan temukan device otomatis
- ✅ **Data Streaming**: Real-time data dari device
- ✅ **API Integration**: Fetch device data dari cloud API
- ✅ **State Management**: RxDart streams untuk reactive UI
- ✅ **Service Locator**: Dependency injection dengan GetIt
- ✅ **Type Safe**: Strong typing dengan Dart models

## Instalasi

Tambahkan dependencies ke `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # HTTP & API
  http: ^1.1.0
  dio: ^5.4.0
  
  # BLE
  flutter_blue_plus: ^1.32.0
  
  # WiFi
  network_info_plus: ^5.0.0
  connectivity_plus: ^5.0.0
  
  # State Management
  rxdart: ^0.27.7
  
  # Utils
  get_it: ^7.6.4
  logger: ^2.0.2
  shared_preferences: ^2.2.2
```

## Setup

### 1. Inisialisasi Service

```dart
import 'package:flutter_iot_helper/flutter_iot_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize IoT services
  await IoTServiceLocator.initialize(
    cloudBaseUrl: 'https://your-api.com/api/v1',
    cloudApiKey: 'your-api-key',
    bleServiceUuid: '0000180f-0000-1000-8000-00805f9b34fb',
    bleCharacteristicUuid: '00002a19-0000-1000-8000-00805f9b34fb',
    wifiPort: 80,
  );
  
  runApp(MyApp());
}
```

### 2. Permissions (Android)

Tambahkan ke `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Bluetooth -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- WiFi -->
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Internet -->
<uses-permission android:name="android.permission.INTERNET" />
```

### 3. Permissions (iOS)

Tambahkan ke `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to IoT devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to IoT devices</string>
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs local network access to connect to devices</string>
```

## Penggunaan

### 1. Discovery Devices

```dart
final connectionManager = IoTServiceLocator.connectionManager;

// Discover all devices
final result = await connectionManager.discoverAllDevices();
if (result.success) {
  print('Found ${result.data!.length} devices');
  for (var device in result.data!) {
    print('${device.name} (${device.connectionType.name})');
  }
}

// Discover by specific type
final bleResult = await connectionManager.discoverDevicesByType(
  DeviceConnectionType.ble,
);
```

### 2. Connect ke Device

```dart
// Get device from discovery
final device = result.data!.first;

// Connect
final connectResult = await connectionManager.connectToDevice(device);
if (connectResult.success) {
  print('Connected to ${device.name}');
}
```

### 3. Send Data

```dart
final sendResult = await connectionManager.sendDataToDevice(
  device.id,
  {
    'command': 'turn_on',
    'brightness': 80,
  },
);

if (sendResult.success) {
  print('Data sent successfully');
}
```

### 4. Receive Data (Streaming)

```dart
connectionManager
    .receiveDataFromDevice(device.id)
    .listen((data) {
      print('Received: $data');
      // Update UI dengan data baru
    });
```

### 5. Monitor Connection Status

```dart
connectionManager.statusStream.listen((status) {
  switch (status) {
    case ConnectionManagerStatus.idle:
      print('Idle');
      break;
    case ConnectionManagerStatus.discovering:
      print('Discovering devices...');
      break;
    case ConnectionManagerStatus.connecting:
      print('Connecting...');
      break;
    case ConnectionManagerStatus.error:
      print('Error');
      break;
  }
});
```

### 6. Monitor Active Connections

```dart
connectionManager.activeConnectionsStream.listen((connections) {
  print('Active connections: ${connections.length}');
  for (var device in connections.values) {
    print('${device.name} - ${device.status.name}');
  }
});
```

### 7. Fetch dari API

```dart
final apiService = IoTServiceLocator.apiService;

// Get all devices
final devicesResult = await apiService.getDevices();
if (devicesResult.success) {
  for (var device in devicesResult.data!) {
    print(device.name);
  }
}

// Get device data
final dataResult = await apiService.getDeviceData(
  'device-id',
  startTime: DateTime.now().subtract(Duration(hours: 24)),
  endTime: DateTime.now(),
);

// Send command
final cmdResult = await apiService.sendCommand(
  'device-id',
  'reboot',
  {'delay': 5},
);
```

### 8. Disconnect

```dart
// Disconnect single device
await connectionManager.disconnectFromDevice(device.id);

// Disconnect all
await connectionManager.disconnectAll();
```

## Contoh Lengkap

```dart
import 'package:flutter/material.dart';
import 'package:flutter_iot_helper/flutter_iot_helper.dart';

class IoTDevicesPage extends StatefulWidget {
  @override
  _IoTDevicesPageState createState() => _IoTDevicesPageState();
}

class _IoTDevicesPageState extends State<IoTDevicesPage> {
  final connectionManager = IoTServiceLocator.connectionManager;
  List<DeviceModel> devices = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _scanDevices();
    _listenToConnections();
  }

  void _scanDevices() async {
    setState(() => isScanning = true);
    
    final result = await connectionManager.discoverAllDevices();
    
    setState(() {
      isScanning = false;
      if (result.success) {
        devices = result.data!;
      }
    });
  }

  void _listenToConnections() {
    connectionManager.activeConnectionsStream.listen((connections) {
      setState(() {
        // Update UI when connections change
      });
    });
  }

  void _connectToDevice(DeviceModel device) async {
    final result = await connectionManager.connectToDevice(device);
    
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
      );
      
      // Start listening to data
      connectionManager.receiveDataFromDevice(device.id).listen((data) {
        print('Data from ${device.name}: $data');
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${result.error}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IoT Devices'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: isScanning ? null : _scanDevices,
          ),
        ],
      ),
      body: isScanning
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isConnected = connectionManager.isDeviceConnected(device.id);
                
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text(
                    '${ConnectionHelper.getConnectionTypeLabel(device.connectionType)} - '
                    '${ConnectionHelper.getDeviceStatusLabel(device.status)}'
                  ),
                  trailing: ElevatedButton(
                    onPressed: isConnected
                        ? () => connectionManager.disconnectFromDevice(device.id)
                        : () => _connectToDevice(device),
                    child: Text(isConnected ? 'Disconnect' : 'Connect'),
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    connectionManager.disconnectAll();
    super.dispose();
  }
}
```

## Architecture

```
flutter_iot_helper/
├── lib/
│   ├── models/
│   │   ├── device_model.dart          # Device data model
│   │   └── connection_result.dart     # Result wrapper
│   ├── connection/
│   │   ├── connection_interface.dart  # Base interface
│   │   ├── ble_connection.dart        # BLE implementation
│   │   ├── wifi_connection.dart       # WiFi implementation
│   │   └── cloud_connection.dart      # Cloud API implementation
│   ├── services/
│   │   ├── iot_connection_manager.dart # Main manager
│   │   └── device_api_service.dart     # API service
│   ├── helpers/
│   │   ├── iot_service_locator.dart   # Dependency injection
│   │   └── connection_helper.dart      # Utility functions
│   └── flutter_iot_helper.dart        # Main export
├── pubspec.yaml
└── README.md
```

## Connection Types

### 1. BLE (Bluetooth Low Energy)
- Untuk device dengan Bluetooth
- Range: ~10-30 meter
- Low power consumption
- Memerlukan MAC address dan service UUID

### 2. WiFi (Local Network)
- Untuk device di jaringan WiFi yang sama
- Range: sesuai jangkauan WiFi
- Fast data transfer
- Memerlukan IP address

### 3. Cloud API
- Untuk device yang terhubung ke cloud
- Unlimited range (via internet)
- Memerlukan internet connection
- Memerlukan Cloud ID dan API key

## Advanced Features

### Custom Data Parser

```dart
// Extend BleConnection untuk custom parsing
class CustomBleConnection extends BleConnection {
  CustomBleConnection({
    required String serviceUuid,
    required String characteristicUuid,
  }) : super(
    serviceUuid: serviceUuid,
    characteristicUuid: characteristicUuid,
  );

  @override
  Stream<Map<String, dynamic>> receiveData(String deviceId) {
    return super.receiveData(deviceId).map((data) {
      // Custom parsing logic
      final rawBytes = data['raw'] as List<int>;
      return {
        'temperature': _parseTemperature(rawBytes),
        'humidity': _parseHumidity(rawBytes),
        'timestamp': DateTime.now(),
      };
    });
  }

  double _parseTemperature(List<int> bytes) {
    // Your parsing logic
    return 0.0;
  }

  double _parseHumidity(List<int> bytes) {
    // Your parsing logic
    return 0.0;
  }
}
```

### Error Handling

```dart
final result = await connectionManager.connectToDevice(device);

if (!result.success) {
  switch (result.type) {
    case ConnectionResultType.timeout:
      print('Connection timeout');
      break;
    case ConnectionResultType.unauthorized:
      print('Invalid API key');
      break;
    case ConnectionResultType.error:
      print('Error: ${result.error}');
      break;
    default:
      break;
  }
}
```

## Testing

Lihat folder `test/` untuk contoh unit tests.

## License

MIT License

## Author

Created for Flutter IoT projects

## Contributing

Contributions welcome! Please read contributing guidelines first.
