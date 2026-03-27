import 'package:flutter/material.dart';
import 'package:flutter_iot_helper/flutter_iot_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize IoT services
  await IoTServiceLocator.initialize(
    cloudBaseUrl: 'https://api.example.com/v1',
    cloudApiKey: 'your-api-key-here',
    bleServiceUuid: '0000180f-0000-1000-8000-00805f9b34fb',
    bleCharacteristicUuid: '00002a19-0000-1000-8000-00805f9b34fb',
    wifiPort: 80,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter IoT Helper Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const IoTDevicesPage(),
    );
  }
}

class IoTDevicesPage extends StatefulWidget {
  const IoTDevicesPage({Key? key}) : super(key: key);

  @override
  State<IoTDevicesPage> createState() => _IoTDevicesPageState();
}

class _IoTDevicesPageState extends State<IoTDevicesPage> {
  final connectionManager = IoTServiceLocator.connectionManager;
  final apiService = IoTServiceLocator.apiService;

  List<DeviceModel> devices = [];
  Map<String, DeviceModel> activeConnections = {};
  bool isScanning = false;
  ConnectionManagerStatus status = ConnectionManagerStatus.idle;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _scanDevices();
  }

  void _setupListeners() {
    // Listen to discovered devices
    connectionManager.devicesStream.listen((deviceList) {
      setState(() {
        devices = deviceList;
      });
    });

    // Listen to active connections
    connectionManager.activeConnectionsStream.listen((connections) {
      setState(() {
        activeConnections = connections;
      });
    });

    // Listen to connection status
    connectionManager.statusStream.listen((newStatus) {
      setState(() {
        status = newStatus;
      });
    });
  }

  Future<void> _scanDevices() async {
    setState(() => isScanning = true);

    final result = await connectionManager.discoverAllDevices();

    setState(() => isScanning = false);

    if (!result.success) {
      _showSnackBar('Scan failed: ${result.error}', isError: true);
    }
  }

  Future<void> _connectToDevice(DeviceModel device) async {
    final result = await connectionManager.connectToDevice(device);

    if (result.success && result.data != null) {
      _showSnackBar('Connected to ${device.name}');

      // Start listening to device data
      connectionManager.receiveDataFromDevice(device.id).listen(
        (data) {
          print('Data from ${device.name}: $data');
          // Update UI with received data
        },
        onError: (error) {
          print('Error receiving data: $error');
        },
      );
    } else {
      _showSnackBar('Failed to connect: ${result.error}', isError: true);
    }
  }

  Future<void> _disconnectFromDevice(String deviceId) async {
    final result = await connectionManager.disconnectFromDevice(deviceId);

    if (result.success) {
      _showSnackBar('Disconnected');
    } else {
      _showSnackBar('Failed to disconnect: ${result.error}', isError: true);
    }
  }

  Future<void> _sendDataToDevice(DeviceModel device) async {
    final result = await connectionManager.sendDataToDevice(
      device.id,
      {
        'command': 'status',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (result.success) {
      _showSnackBar('Data sent successfully');
    } else {
      _showSnackBar('Failed to send data: ${result.error}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _getStatusText() {
    switch (status) {
      case ConnectionManagerStatus.idle:
        return 'Ready';
      case ConnectionManagerStatus.discovering:
        return 'Discovering...';
      case ConnectionManagerStatus.connecting:
        return 'Connecting...';
      case ConnectionManagerStatus.error:
        return 'Error';
    }
  }

  Widget _buildDeviceCard(DeviceModel device) {
    final isConnected = activeConnections.containsKey(device.id);
    final connectionType =
        ConnectionHelper.getConnectionTypeLabel(device.connectionType);
    final statusLabel = ConnectionHelper.getDeviceStatusLabel(device.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          _getDeviceIcon(device.connectionType),
          size: 40,
          color: isConnected ? Colors.green : Colors.grey,
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$connectionType - $statusLabel'),
            if (device.macAddress != null)
              Text(
                'MAC: ${device.macAddress}',
                style: const TextStyle(fontSize: 12),
              ),
            if (device.ipAddress != null)
              Text(
                'IP: ${device.ipAddress}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnected)
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendDataToDevice(device),
                tooltip: 'Send Data',
              ),
            ElevatedButton(
              onPressed: isConnected
                  ? () => _disconnectFromDevice(device.id)
                  : () => _connectToDevice(device),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red : Colors.blue,
              ),
              child: Text(isConnected ? 'Disconnect' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(DeviceConnectionType type) {
    switch (type) {
      case DeviceConnectionType.ble:
        return Icons.bluetooth;
      case DeviceConnectionType.wifi:
        return Icons.wifi;
      case DeviceConnectionType.cloud:
        return Icons.cloud;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Devices'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_getStatusText()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isScanning ? null : _scanDevices,
            tooltip: 'Scan Devices',
          ),
        ],
      ),
      body: Column(
        children: [
          if (activeConnections.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Active Connections: ${activeConnections.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isScanning
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Scanning for devices...'),
                      ],
                    ),
                  )
                : devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.devices, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No devices found'),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _scanDevices,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Scan Again'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          return _buildDeviceCard(devices[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanDevices,
        icon: const Icon(Icons.search),
        label: const Text('Scan'),
      ),
    );
  }

  @override
  void dispose() {
    connectionManager.disconnectAll();
    super.dispose();
  }
}
