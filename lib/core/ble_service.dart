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

  // Debug log for BLE activity (visible in settings)
  final List<String> debugLog = [];
  void _log(String msg) {
    final ts = DateTime.now().toString().substring(11, 19);
    debugLog.add('[$ts] $msg');
    if (debugLog.length > 100) debugLog.removeAt(0);
    debugPrint('BLE: $msg');
    notifyListeners();
  }

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
      _log('Connected! RX props: write=${_rxChar!.properties.write} writeNoResp=${_rxChar!.properties.writeWithoutResponse}');
      _log('TX props: notify=${_txChar!.properties.notify} indicate=${_txChar!.properties.indicate}');

      // Match reference app init sequence:
      // 1. deviceQuery (triggers selfInfo response)
      // 2. appStart (handshake with app name + version)
      _log('Sending deviceQuery + appStart');
      await sendFrame(buildDeviceQueryFrame());
      await sendFrame(buildAppStartFrame());

      // 3. Request battery info
      await sendFrame(buildGetBattAndStorageFrame());

      // 4. Wait for selfInfo to arrive before proceeding
      await Future.delayed(const Duration(seconds: 2));

      // 5. Sync time
      await sendFrame(buildSetDeviceTimeFrame());

      // 6. Request channels (slots 0-7)
      for (int i = 0; i < 8; i++) {
        await sendFrame(buildGetChannelFrame(i));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 7. Request contacts (after selfInfo + channels are loaded)
      await sendFrame(buildGetContactsFrame());

    } catch (e) {
      _log('CONNECT ERROR: $e');
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
      _log('TX BLOCKED: frame — not connected');
      return;
    }
    try {
      _log('TX: code=${frame[0]} len=${frame.length}');
      // Prefer writeWithoutResponse when supported (matches reference app)
      final canWriteWithout = _rxChar!.properties.writeWithoutResponse;
      await _rxChar!.write(frame.toList(), withoutResponse: canWriteWithout);
    } catch (e) {
      _log('TX ERROR: $e');
    }
  }

  // ─── Convenience methods ─────────────────────────────────

  /// Send a text message to a contact
  Future<void> sendTextMessage(String pubKeyHex, String text, {int attempt = 0}) async {
    await sendFrame(buildSendTextMsgFrame(pubKeyHex, text, attempt: attempt));
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

  /// Set a channel on the radio (slot 0-7)
  Future<void> setChannel(int index, String name, Uint8List psk) async {
    await sendFrame(buildSetChannelFrame(index, name, psk));
    // Re-query to confirm
    await Future.delayed(const Duration(milliseconds: 200));
    await sendFrame(buildGetChannelFrame(index));
  }

  /// Remove a channel (clear the slot)
  Future<void> removeChannel(int index) async {
    await sendFrame(buildSetChannelFrame(index, '', Uint8List(16)));
    await Future.delayed(const Duration(milliseconds: 200));
    await sendFrame(buildGetChannelFrame(index));
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
    _log('RX: code=${frame[0]} len=${frame.length}');
    try {
      final parsed = parseFrame(frame);

      // Cache device-level info
      if (parsed.code == Resp.selfInfo && parsed.data is DeviceSelfInfo) {
        _selfInfo = parsed.data as DeviceSelfInfo;
        _log('Got selfInfo: name="${_selfInfo!.name}" key=${_selfInfo!.publicKeyHex.substring(0, 12)}...');
        notifyListeners();
      }
      if (parsed.code == Resp.battAndStorage && parsed.data is DeviceBattStorage) {
        _battInfo = parsed.data as DeviceBattStorage;
        _log('Battery: ${_battInfo!.batteryPercent}%');
        notifyListeners();
      }
      if (parsed.code == Resp.sent) {
        _log('Radio ACK: message accepted for TX');
      }
      if (parsed.code == Resp.ok) {
        _log('Radio OK (generic ACK)');
      }
      if (parsed.code == Resp.contact && parsed.data is DeviceContact) {
        final dc = parsed.data as DeviceContact;
        _log('Contact: "${dc.name}" type=${dc.advType}');
      }
      if (parsed.code == Resp.channelInfo && parsed.data is DeviceChannel) {
        final ch = parsed.data as DeviceChannel;
        _log('Channel[${ch.index}]: "${ch.name}"');
      }

      _frameController.add(parsed);

      // If there are messages waiting, sync them
      if (parsed.code == Push.msgWaiting) {
        _log('Messages waiting — syncing');
        syncNextMessage();
      }
    } catch (e) {
      _log('PARSE ERROR: $e');
    }
  }

  void _handleDisconnection() {
    _log('DISCONNECTED');
    _selfInfo = null;
    _battInfo = null;
    _cleanup();
    _setState(BleConnectionState.disconnected);

    // Auto-reconnect after 3 seconds (unless manual disconnect)
    if (!_manualDisconnect) {
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        _log('RECONNECTING...');
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
