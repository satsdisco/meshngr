import 'package:flutter/material.dart';
import '../models/ble_device.dart';
import '../data/mock_data.dart';

enum ConnectionState { disconnected, scanning, connecting, connected }

class ConnectionProvider extends ChangeNotifier {
  ConnectionState _state = ConnectionState.disconnected;
  BleDevice? _connectedDevice;
  List<BleDevice> _discoveredDevices = [];

  ConnectionState get state => _state;
  BleDevice? get connectedDevice => _connectedDevice;
  List<BleDevice> get discoveredDevices => _discoveredDevices;
  bool get isConnected => _state == ConnectionState.connected;

  String get statusText {
    switch (_state) {
      case ConnectionState.disconnected:
        return 'Disconnected';
      case ConnectionState.scanning:
        return 'Scanning...';
      case ConnectionState.connecting:
        return 'Connecting...';
      case ConnectionState.connected:
        return 'Connected to ${_connectedDevice?.name ?? "device"}';
    }
  }

  Future<void> startScan() async {
    _state = ConnectionState.scanning;
    _discoveredDevices = [];
    notifyListeners();

    // Simulate finding devices
    await Future.delayed(const Duration(milliseconds: 800));
    _discoveredDevices = [MockData.bleDevices[0]];
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));
    _discoveredDevices = MockData.bleDevices;
    notifyListeners();
  }

  Future<void> connect(BleDevice device) async {
    _state = ConnectionState.connecting;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));
    _state = ConnectionState.connected;
    _connectedDevice = device;
    notifyListeners();
  }

  void disconnect() {
    _state = ConnectionState.disconnected;
    _connectedDevice = null;
    _discoveredDevices = [];
    notifyListeners();
  }
}
