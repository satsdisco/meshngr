import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'protocol.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected }

/// Clean BLE abstraction for MeshCore radios
class BleService extends ChangeNotifier {
  BleConnectionState _state = BleConnectionState.disconnected;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar; // phone → radio
  BluetoothCharacteristic? _txChar; // radio → phone
  StreamSubscription? _connectionSub;
  StreamSubscription? _notifySub;
  StreamSubscription? _scanSub;
  Timer? _reconnectTimer;

  String? _deviceName;
  String? _deviceId;
  List<ScanResult> _scanResults = [];
  bool _manualDisconnect = false;

  // Stream of parsed frames from the radio
  final _frameController = StreamController<ParsedFrame>.broadcast();

  // Cached device info
  DeviceSelfInfo? _selfInfo;
  DeviceBattStorage? _battInfo;

  // Public API
  BleConnectionState get state => _state;
  String? get deviceName => _selfInfo?.name ?? _deviceName;
  String? get deviceId => _deviceId;
  bool get isConnected => _state == BleConnectionState.connected;
  List<ScanResult> get scanResults => _scanResults;
  Stream<ParsedFrame> get frames => _frameController.stream;
  DeviceSelfInfo? get selfInfo => _selfInfo;
  int? get batteryPercent => _battInfo?.batteryPercent;

  /// Start scanning for MeshCore radios
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_state == BleConnectionState.scanning) return;

    _setState(BleConnectionState.scanning);
    _scanResults = [];

    // Check adapter
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.adapterState
            .firstWhere((s) => s == BluetoothAdapterState.on)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        _setState(BleConnectionState.disconnected);
        return;
      }
    }

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      notifyListeners();
    });

    await FlutterBluePlus.startScan(
      withKeywords: ['MeshCore-', 'Whisper-'],
      timeout: timeout,
      androidScanMode: AndroidScanMode.lowLatency,
    );

    await Future.delayed(timeout);
    await stopScan();
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    if (_state == BleConnectionState.scanning) {
      _setState(BleConnectionState.disconnected);
    }
  }

  /// Connect to a specific device
  Future<void> connect(BluetoothDevice device) async {
    if (_state == BleConnectionState.connecting || _state == BleConnectionState.connected) return;

    await stopScan();
    _setState(BleConnectionState.connecting);
    _device = device;
    _deviceId = device.remoteId.toString();
    _deviceName = device.platformName.isNotEmpty ? device.platformName : 'MeshCore Radio';
    _manualDisconnect = false;
    _cancelReconnect();

    try {
      // Listen for disconnection
      _connectionSub = device.connectionState.listen((connState) {
        if (connState == BluetoothConnectionState.disconnected && isConnected) {
          _handleDisconnection();
        }
      });

      // Connect with timeout
      await device.connect(timeout: const Duration(seconds: 15));

      // Request larger MTU
      try {
        await device.requestMtu(185);
      } catch (_) {}

      // Discover services
      final services = await device.discoverServices();
      BluetoothService? uartService;
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == MeshCoreUuids.service) {
          uartService = service;
          break;
        }
      }

      if (uartService == null) throw Exception('MeshCore UART service not found');

      // Find characteristics
      for (final char in uartService.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == MeshCoreUuids.rxCharacteristic) _rxChar = char;
        if (uuid == MeshCoreUuids.txCharacteristic) _txChar = char;
      }

      if (_rxChar == null || _txChar == null) {
        throw Exception('MeshCore characteristics not found');
      }

      // Subscribe to notifications (radio → phone)
      await _txChar!.setNotifyValue(true);
      _notifySub = _txChar!.onValueReceived.listen(_onDataReceived);

      _setState(BleConnectionState.connected);

      // Send app start handshake
      await sendFrame(buildAppStartFrame());

      // Sync time
      await sendFrame(buildSetDeviceTimeFrame());

      // Request contacts
      await sendFrame(buildGetContactsFrame());

    } catch (e) {
      debugPrint('BLE connect error: $e');
      await _cleanup();
      _setState(BleConnectionState.disconnected);
    }
  }

  /// Connect to last known device (auto-reconnect)
  Future<void> reconnect() async {
    if (_device == null || _manualDisconnect) return;
    await connect(_device!);
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _cancelReconnect();
    await _cleanup();
    _setState(BleConnectionState.disconnected);
  }

  /// Send a raw frame to the radio
  Future<void> sendFrame(Uint8List frame) async {
    if (_rxChar == null || !isConnected) {
      debugPrint('BLE: Cannot send frame — not connected');
      return;
    }
    try {
      await _rxChar!.write(frame.toList(), withoutResponse: false);
    } catch (e) {
      debugPrint('BLE send error: $e');
    }
  }

  // ─── Convenience methods ─────────────────────────────────

  /// Send a text message to a contact
  Future<void> sendTextMessage(String pubKeyHex, String text, {Uint8List? path}) async {
    await sendFrame(buildSendTextMsgFrame(pubKeyHex, text, pathBytes: path));
  }

  /// Send a channel message
  Future<void> sendChannelMessage(int channelIdx, String text) async {
    await sendFrame(buildSendChannelTextMsgFrame(channelIdx, text));
  }

  /// Send self advertisement
  Future<void> sendAdvert({bool flood = false}) async {
    await sendFrame(buildSendSelfAdvertFrame(flood: flood));
  }

  /// Set display name on the radio
  Future<void> setName(String name) async {
    await sendFrame(buildSetAdvertNameFrame(name));
  }

  /// Sync next pending message
  Future<void> syncNextMessage() async {
    await sendFrame(buildSyncNextMessageFrame());
  }

  /// Request battery/storage info
  Future<void> requestBatteryInfo() async {
    await sendFrame(buildGetBattAndStorageFrame());
  }

  // ─── Internal ────────────────────────────────────────────

  void _onDataReceived(List<int> data) {
    if (data.isEmpty) return;

    // Parse the frame
    final frame = Uint8List.fromList(data);
    try {
      final parsed = parseFrame(frame);

      // Cache device-level info
      if (parsed.code == Resp.selfInfo && parsed.data is DeviceSelfInfo) {
        _selfInfo = parsed.data as DeviceSelfInfo;
        notifyListeners();
      }
      if (parsed.code == Resp.battAndStorage && parsed.data is DeviceBattStorage) {
        _battInfo = parsed.data as DeviceBattStorage;
        notifyListeners();
      }

      _frameController.add(parsed);

      // If there are messages waiting, sync them
      if (parsed.code == Push.msgWaiting) {
        syncNextMessage();
      }
    } catch (e) {
      debugPrint('Frame parse error: $e');
    }
  }

  void _handleDisconnection() {
    debugPrint('BLE: Device disconnected');
    _selfInfo = null;
    _battInfo = null;
    _cleanup();
    _setState(BleConnectionState.disconnected);

    // Auto-reconnect after 3 seconds (unless manual disconnect)
    if (!_manualDisconnect) {
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        debugPrint('BLE: Attempting auto-reconnect...');
        reconnect();
      });
    }
  }

  Future<void> _cleanup() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;

    try {
      await _device?.disconnect();
    } catch (_) {}

    _rxChar = null;
    _txChar = null;
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _setState(BleConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelReconnect();
    _cleanup();
    _frameController.close();
    super.dispose();
  }
}
