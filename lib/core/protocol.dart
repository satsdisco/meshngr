import 'dart:typed_data';
import 'buffer.dart';

// ─── BLE UUIDs ───────────────────────────────────────────────
class MeshCoreUuids {
  static const service = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const rxCharacteristic = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // phone → radio
  static const txCharacteristic = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // radio → phone
}

// ─── Commands (phone → radio) ────────────────────────────────
class Cmd {
  static const appStart = 1;
  static const sendTextMsg = 2;
  static const sendChannelTextMsg = 3;
  static const getContacts = 4;
  static const getDeviceTime = 5;
  static const setDeviceTime = 6;
  static const sendSelfAdvert = 7;
  static const setAdvertName = 8;
  static const addUpdateContact = 9;
  static const syncNextMessage = 10;
  static const setRadioParams = 11;
  static const setRadioTxPower = 12;
  static const resetPath = 13;
  static const setAdvertLatLon = 14;
  static const removeContact = 15;
  static const shareContact = 16;
  static const exportContact = 17;
  static const importContact = 18;
  static const reboot = 19;
  static const getBattAndStorage = 20;
  static const deviceQuery = 22;
  static const sendLogin = 26;
  static const sendStatusReq = 27;
  static const getContactByKey = 30;
  static const getChannel = 31;
  static const setChannel = 32;
  static const sendTracePath = 36;
  static const setOtherParams = 38;
  static const getRadioSettings = 57;
}

// ─── Responses (radio → phone) ───────────────────────────────
class Resp {
  static const ok = 0;
  static const err = 1;
  static const contactsStart = 2;
  static const contact = 3;
  static const endOfContacts = 4;
  static const selfInfo = 5;
  static const sent = 6;
  static const contactMsgRecv = 7;
  static const channelMsgRecv = 8;
  static const currTime = 9;
  static const noMoreMessages = 10;
  static const exportContact = 11;
  static const battAndStorage = 12;
  static const deviceInfo = 13;
  static const contactMsgRecvV3 = 16;
  static const channelMsgRecvV3 = 17;
  static const channelInfo = 18;
  static const radioSettings = 25;
}

// ─── Push codes (async from radio) ───────────────────────────
class Push {
  static const advert = 0x80;
  static const pathUpdated = 0x81;
  static const sendConfirmed = 0x82;
  static const msgWaiting = 0x83;
  static const loginSuccess = 0x85;
  static const loginFail = 0x86;
  static const statusResponse = 0x87;
  static const newAdvert = 0x8A;
}

// ─── Advert types ────────────────────────────────────────────
class AdvType {
  static const chat = 1;
  static const repeater = 2;
  static const room = 3;
  static const sensor = 4;
}

// ─── Sizes ───────────────────────────────────────────────────
const int pubKeySize = 32;
const int maxPathSize = 64;
const int maxNameSize = 32;
const int maxFrameSize = 172;
const int maxTextPayloadBytes = 160;
const int appProtocolVersion = 3;

// ─── Frame builders ──────────────────────────────────────────

/// App start handshake — sent after BLE connect
/// Format: [cmd][app_ver][reserved x6][app_name...]\0
Uint8List buildAppStartFrame() {
  final w = BufferWriter();
  w.writeByte(Cmd.appStart);
  w.writeByte(appProtocolVersion);
  w.writeBytes(Uint8List(6)); // reserved bytes
  w.writeString('meshngr');
  w.writeByte(0); // null terminator
  return w.toBytes();
}

/// Request contact list from device
Uint8List buildGetContactsFrame() {
  return Uint8List.fromList([Cmd.getContacts]);
}

/// Request device time
Uint8List buildGetDeviceTimeFrame() {
  return Uint8List.fromList([Cmd.getDeviceTime]);
}

/// Set device time to current UTC epoch
Uint8List buildSetDeviceTimeFrame() {
  final w = BufferWriter();
  w.writeByte(Cmd.setDeviceTime);
  w.writeUInt32LE(DateTime.now().millisecondsSinceEpoch ~/ 1000);
  return w.toBytes();
}

/// Send text message to a contact (companion_radio format)
/// Format: [cmd][txt_type][attempt][timestamp x4][pub_key_prefix x6][text...]\0
Uint8List buildSendTextMsgFrame(String pubKeyHex, String text, {int attempt = 0, Uint8List? pathBytes}) {
  final w = BufferWriter();
  w.writeByte(Cmd.sendTextMsg);
  w.writeByte(0); // txtTypePlain
  w.writeByte(attempt.clamp(0, 3));
  w.writeUInt32LE(DateTime.now().millisecondsSinceEpoch ~/ 1000);
  // Only first 6 bytes of public key (prefix match)
  final fullKey = hexToBytes(pubKeyHex);
  w.writeBytes(fullKey.sublist(0, 6));
  w.writeString(text);
  w.writeByte(0); // null terminator
  return w.toBytes();
}

/// Send text message to a channel
/// [channelIdx] — channel index (0-based)
/// [text] — message text (will be prefixed with sender name by firmware)
Uint8List buildSendChannelTextMsgFrame(int channelIdx, String text) {
  final w = BufferWriter();
  w.writeByte(Cmd.sendChannelTextMsg);
  w.writeByte(0); // txtTypePlain
  w.writeByte(channelIdx);
  w.writeUInt32LE(DateTime.now().millisecondsSinceEpoch ~/ 1000);
  w.writeString(text);
  w.writeByte(0); // null terminator
  return w.toBytes();
}

/// Send self advertisement
/// [flood] — true = network-wide, false = local/zero-hop
Uint8List buildSendSelfAdvertFrame({bool flood = false}) {
  return Uint8List.fromList([Cmd.sendSelfAdvert, flood ? 1 : 0]);
}

/// Set advertisement name
Uint8List buildSetAdvertNameFrame(String name) {
  final w = BufferWriter();
  w.writeByte(Cmd.setAdvertName);
  w.writeCString(name, maxNameSize);
  return w.toBytes();
}

/// Sync next pending message from device
Uint8List buildSyncNextMessageFrame() {
  return Uint8List.fromList([Cmd.syncNextMessage]);
}

/// Request battery and storage info
Uint8List buildGetBattAndStorageFrame() {
  return Uint8List.fromList([Cmd.getBattAndStorage]);
}

/// Request channel info by index
/// Build CMD_SET_CHANNEL frame: [cmd][idx][name x32][psk x16]
Uint8List buildSetChannelFrame(int channelIdx, String name, Uint8List psk) {
  final w = BufferWriter();
  w.writeByte(Cmd.setChannel);
  w.writeByte(channelIdx);
  // Name: 32 bytes, null-padded
  final nameBytes = Uint8List(32);
  final encoded = name.codeUnits;
  for (int i = 0; i < encoded.length && i < 31; i++) {
    nameBytes[i] = encoded[i];
  }
  w.writeBytes(nameBytes);
  // PSK: 16 bytes
  final pskPadded = Uint8List(16);
  for (int i = 0; i < 16 && i < psk.length; i++) {
    pskPadded[i] = psk[i];
  }
  w.writeBytes(pskPadded);
  return w.toBytes();
}

Uint8List buildGetChannelFrame(int channelIdx) {
  return Uint8List.fromList([Cmd.getChannel, channelIdx]);
}

/// Remove a contact by public key
Uint8List buildRemoveContactFrame(String pubKeyHex) {
  final w = BufferWriter();
  w.writeByte(Cmd.removeContact);
  w.writeHex(pubKeyHex);
  return w.toBytes();
}

/// Share a contact via zero-hop advert
Uint8List buildShareContactFrame(String pubKeyHex) {
  final w = BufferWriter();
  w.writeByte(Cmd.shareContact);
  w.writeHex(pubKeyHex);
  return w.toBytes();
}

/// Reboot the radio
Uint8List buildRebootFrame() {
  return Uint8List.fromList([Cmd.reboot]);
}

/// Add or update a contact on the radio by public key
/// [pubKeyHex] — 64-char hex string (32 bytes)
/// [name] — device name as reported by the node
/// [advType] — advert type (default: chat)
Uint8List buildAddUpdateContactFrame(String pubKeyHex, {String name = '', int advType = AdvType.chat}) {
  final w = BufferWriter();
  w.writeByte(Cmd.addUpdateContact);
  w.writeHex(pubKeyHex);
  w.writeByte(advType);
  w.writeByte(0); // flags
  w.writeByte(0); // pathLen = 0 (flood route)
  w.writeByte(0); // SNR = 0
  w.writeUInt32LE(DateTime.now().millisecondsSinceEpoch ~/ 1000);
  if (name.isNotEmpty) w.writeCString(name, maxNameSize);
  return w.toBytes();
}

// ─── Response parsers ────────────────────────────────────────

/// Parsed contact from device
class DeviceContact {
  final Uint8List publicKey;
  final String publicKeyHex;
  final int advType; // chat, repeater, room, sensor
  final int flags;
  final Uint8List path;
  final double? lastSNR;
  final int? lastSeen; // epoch seconds
  final String name;
  final bool isOutgoing; // we added them (not them us)

  DeviceContact({
    required this.publicKey,
    required this.publicKeyHex,
    required this.advType,
    required this.flags,
    required this.path,
    this.lastSNR,
    this.lastSeen,
    required this.name,
    this.isOutgoing = false,
  });
}

/// Parsed incoming text message
class IncomingMessage {
  final String senderKeyHex;
  final String text;
  final int timestamp; // epoch seconds
  final int hopCount;
  final bool isFlood;
  final int? snr;

  IncomingMessage({
    required this.senderKeyHex,
    required this.text,
    required this.timestamp,
    this.hopCount = 0,
    this.isFlood = false,
    this.snr,
  });
}

/// Parsed incoming channel message
class IncomingChannelMessage {
  final int channelIdx;
  final String senderName;
  final String text;
  final int timestamp;
  final int hopCount;
  final bool isFlood;

  IncomingChannelMessage({
    required this.channelIdx,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.hopCount = 0,
    this.isFlood = false,
  });
}

/// Device self info
class DeviceSelfInfo {
  final Uint8List publicKey;
  final String publicKeyHex;
  final String name;

  DeviceSelfInfo({
    required this.publicKey,
    required this.publicKeyHex,
    required this.name,
  });
}

/// Battery and storage info
class DeviceBattStorage {
  final int batteryPercent;
  final int storageFreePercent;

  DeviceBattStorage({required this.batteryPercent, required this.storageFreePercent});
}

/// Channel info from device
class DeviceChannel {
  final int index;
  final String name;
  final Uint8List key;

  DeviceChannel({required this.index, required this.name, required this.key});
}

// ─── Frame parser ────────────────────────────────────────────

/// Result of parsing a response frame
class ParsedFrame {
  final int code; // response or push code
  final dynamic data; // parsed payload (type depends on code)

  ParsedFrame(this.code, [this.data]);
}

/// Parse a raw frame from the radio into a structured result
ParsedFrame parseFrame(Uint8List frame) {
  if (frame.isEmpty) return ParsedFrame(-1);

  final code = frame[0];
  final reader = BufferReader(frame.sublist(1));

  switch (code) {
    case Resp.selfInfo:
      return _parseSelfInfo(reader, code);

    case Resp.contact:
      return _parseContact(reader, code);

    case Resp.contactsStart:
    case Resp.endOfContacts:
    case Resp.noMoreMessages:
      return ParsedFrame(code);

    case Resp.sent:
      return ParsedFrame(code); // message was sent to radio

    case Resp.contactMsgRecv:
    case Resp.contactMsgRecvV3:
      return _parseContactMsg(reader, code);

    case Resp.channelMsgRecv:
    case Resp.channelMsgRecvV3:
      return _parseChannelMsg(reader, code);

    case Resp.battAndStorage:
      return _parseBattStorage(reader, code);

    case Resp.channelInfo:
      return _parseChannelInfo(reader, code);

    case Resp.currTime:
      return ParsedFrame(code, reader.remaining >= 4 ? reader.readUInt32LE() : null);

    case Push.sendConfirmed:
      // Delivery confirmation — payload is the pub key of recipient
      if (reader.remaining >= pubKeySize) {
        final key = reader.readBytes(pubKeySize);
        return ParsedFrame(code, _bytesToHex(key));
      }
      return ParsedFrame(code);

    case Push.msgWaiting:
      return ParsedFrame(code); // there are queued messages to sync

    case Push.advert:
    case Push.newAdvert:
      return _parseAdvert(reader, code);

    case Push.pathUpdated:
      if (reader.remaining >= pubKeySize) {
        final key = reader.readBytes(pubKeySize);
        return ParsedFrame(code, _bytesToHex(key));
      }
      return ParsedFrame(code);

    default:
      return ParsedFrame(code);
  }
}

// ─── Internal parsers ────────────────────────────────────────

ParsedFrame _parseSelfInfo(BufferReader r, int code) {
  if (r.remaining < pubKeySize) return ParsedFrame(code);
  final pubKey = r.readBytes(pubKeySize);
  final name = r.remaining > 0 ? r.readCString(maxNameSize.clamp(0, r.remaining)) : '';
  return ParsedFrame(code, DeviceSelfInfo(
    publicKey: pubKey,
    publicKeyHex: _bytesToHex(pubKey),
    name: name,
  ));
}

ParsedFrame _parseContact(BufferReader r, int code) {
  if (r.remaining < pubKeySize + 3) return ParsedFrame(code);
  final pubKey = r.readBytes(pubKeySize);
  final advType = r.readUInt8();
  final flags = r.readUInt8();
  final pathLen = r.readUInt8();
  final path = pathLen > 0 && r.remaining >= pathLen ? r.readBytes(pathLen) : Uint8List(0);

  double? snr;
  int? lastSeen;
  if (r.remaining >= 1) snr = r.readInt8() / 4.0;
  if (r.remaining >= 4) lastSeen = r.readUInt32LE();

  final name = r.remaining > 0 ? r.readCString(maxNameSize.clamp(0, r.remaining)) : '';

  return ParsedFrame(code, DeviceContact(
    publicKey: pubKey,
    publicKeyHex: _bytesToHex(pubKey),
    advType: advType,
    flags: flags,
    path: path,
    lastSNR: snr,
    lastSeen: lastSeen,
    name: name,
  ));
}

ParsedFrame _parseContactMsg(BufferReader r, int code) {
  if (r.remaining < pubKeySize + 5) return ParsedFrame(code);

  final senderKey = r.readBytes(pubKeySize);
  final isV3 = code == Resp.contactMsgRecvV3;

  int hopCount = 0;
  bool isFlood = false;
  int? snr;

  if (isV3 && r.remaining >= 2) {
    final pathLen = r.readUInt8();
    final flags = r.readUInt8();
    isFlood = (flags & 0x01) != 0;
    hopCount = pathLen;
    if (r.remaining >= 1) snr = r.readInt8();
  }

  final timestamp = r.remaining >= 4 ? r.readUInt32LE() : 0;
  final text = r.remaining > 0 ? r.readString() : '';

  return ParsedFrame(code, IncomingMessage(
    senderKeyHex: _bytesToHex(senderKey),
    text: text,
    timestamp: timestamp,
    hopCount: hopCount,
    isFlood: isFlood,
    snr: snr,
  ));
}

ParsedFrame _parseChannelMsg(BufferReader r, int code) {
  if (r.remaining < 2) return ParsedFrame(code);

  final isV3 = code == Resp.channelMsgRecvV3;
  final channelIdx = r.readUInt8();

  int hopCount = 0;
  bool isFlood = false;

  if (isV3 && r.remaining >= 2) {
    final pathLen = r.readUInt8();
    final flags = r.readUInt8();
    isFlood = (flags & 0x01) != 0;
    hopCount = pathLen;
    if (r.remaining >= 1) r.readInt8(); // snr
  }

  final timestamp = r.remaining >= 4 ? r.readUInt32LE() : 0;
  final fullText = r.remaining > 0 ? r.readString() : '';

  // Channel messages are formatted as "SenderName: message"
  String senderName = 'Unknown';
  String text = fullText;
  final colonIdx = fullText.indexOf(': ');
  if (colonIdx > 0) {
    senderName = fullText.substring(0, colonIdx);
    text = fullText.substring(colonIdx + 2);
  }

  return ParsedFrame(code, IncomingChannelMessage(
    channelIdx: channelIdx,
    senderName: senderName,
    text: text,
    timestamp: timestamp,
    hopCount: hopCount,
    isFlood: isFlood,
  ));
}

ParsedFrame _parseBattStorage(BufferReader r, int code) {
  if (r.remaining < 2) return ParsedFrame(code);
  final batt = r.readUInt8();
  final storage = r.readUInt8();
  return ParsedFrame(code, DeviceBattStorage(
    batteryPercent: batt,
    storageFreePercent: storage,
  ));
}

ParsedFrame _parseChannelInfo(BufferReader r, int code) {
  // Format: [idx][name x32][psk x16]
  if (r.remaining < 49) return ParsedFrame(code); // 1 + 32 + 16
  final idx = r.readUInt8();
  // Name: 32 bytes, null-terminated
  final nameBytes = r.readBytes(32);
  // Find null terminator
  int nameLen = 32;
  for (int i = 0; i < 32; i++) {
    if (nameBytes[i] == 0) { nameLen = i; break; }
  }
  final name = String.fromCharCodes(nameBytes, 0, nameLen);
  // PSK: 16 bytes
  final key = r.remaining >= 16 ? r.readBytes(16) : Uint8List(16);
  return ParsedFrame(code, DeviceChannel(index: idx, name: name, key: key));
}

ParsedFrame _parseAdvert(BufferReader r, int code) {
  if (r.remaining < pubKeySize) return ParsedFrame(code);
  final pubKey = r.readBytes(pubKeySize);

  int advType = AdvType.chat;
  String name = '';

  if (r.remaining >= 4) {
    r.readInt32LE(); // timestamp
  }
  if (r.remaining >= 64) r.skipBytes(64); // signature
  if (r.remaining >= 1) {
    final flags = r.readUInt8();
    final hasLocation = (flags & 0x01) != 0;
    final hasName = (flags & 0x02) != 0;
    advType = (flags >> 2) & 0x07;

    if (hasLocation && r.remaining >= 8) {
      r.skipBytes(8); // lat/lon (future use)
    }
    if (hasName && r.remaining > 0) {
      name = r.readString();
    }
  }

  return ParsedFrame(code, DeviceContact(
    publicKey: pubKey,
    publicKeyHex: _bytesToHex(pubKey),
    advType: advType,
    flags: 0,
    path: Uint8List(0),
    name: name,
  ));
}

// ─── Utilities ───────────────────────────────────────────────

String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (int i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}
