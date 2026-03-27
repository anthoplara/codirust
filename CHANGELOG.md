# Changelog

## [1.0.0] - 2026-03-27

### Added
- Initial release of Flutter IoT Helper
- Multi-protocol support (BLE, WiFi, Cloud)
- Connection management with auto-reconnect capability
- Device discovery across all connection types
- Real-time data streaming from devices
- Cloud API integration for device management
- State management with RxDart streams
- Service locator pattern with GetIt
- Comprehensive helper utilities
- Complete example application
- Unit tests for core functionality
- Full documentation in README.md

### Features
- **BLE Connection**: Connect to Bluetooth Low Energy devices
- **WiFi Connection**: Connect to devices on local network
- **Cloud Connection**: Connect to devices via cloud API
- **Device Discovery**: Automatic discovery of devices
- **Data Streaming**: Real-time data reception from devices
- **API Service**: Fetch and manage device data from cloud
- **Connection Manager**: Centralized connection management
- **Type Safety**: Strong typing with Dart models
- **Error Handling**: Comprehensive error handling with ConnectionResult
- **Logging**: Built-in logging for debugging

### Documentation
- README.md with complete usage examples
- Example application demonstrating all features
- Unit tests for models and helpers
- Architecture documentation

## [Unreleased]

### Planned Features
- Auto-reconnect on connection loss
- Connection pooling for multiple devices
- WebSocket support for real-time cloud communication
- MQTT support for IoT protocols
- Device grouping and management
- Connection statistics and monitoring
- Offline data caching
- Connection retry strategies
- Custom authentication handlers
