import 'dart:convert';
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

/// Device query — triggers selfInfo response
/// Format: [cmd][app_version]
Uint8List buildDeviceQueryFrame() {
  return Uint8List.fromList([Cmd.deviceQuery, appProtocolVersion]);
}

/// App start handshake — sent after BLE connect
/// Format: [cmd][app_ver][reserved x6][app_name...]\0
Uint8List buildAppStartFrame() {
  final w = BufferWriter();
  w.writeByte(Cmd.appStart);
  w.writeByte(1); // app version (1 = standard companion app)
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
/// Import a contact from hex-encoded contact frame
/// Format: [cmd][contact_frame_bytes...]
Uint8List buildImportContactFrame(String contactFrameHex) {
  final w = BufferWriter();
  w.writeByte(Cmd.importContact);
  w.writeHex(contactFrameHex);
  return w.toBytes();
}

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
  // SELF_INFO format (after response code byte, which is already consumed):
  // [0] adv_type, [1] tx_power, [2] max_tx_power
  // [3-34] pub_key (32 bytes)
  // [35-38] lat (int32 LE), [39-42] lon (int32 LE)
  // [43] multi_acks, [44] advert_loc_policy, [45] telemetry, [46] manual_add
  // [47-50] freq (uint32 LE), [51-54] bw (uint32 LE), [55] sf, [56] cr
  // [57+] node_name (null-terminated string)
  if (r.remaining < 3 + pubKeySize) return ParsedFrame(code);

  final advType = r.readUInt8();
  final txPower = r.readUInt8();
  final maxTxPower = r.readUInt8();
  final pubKey = r.readBytes(pubKeySize);

  // Skip lat(4) + lon(4) + multi_acks(1) + advert_loc(1) + telemetry(1) + manual_add(1)
  if (r.remaining >= 12) {
    r.readBytes(12); // lat + lon + 4 flag bytes
  }
  // Skip freq(4) + bw(4) + sf(1) + cr(1)
  if (r.remaining >= 10) {
    r.readBytes(10);
  }

  final name = r.remaining > 0 ? r.readCString(r.remaining.clamp(0, maxNameSize)) : '';
  return ParsedFrame(code, DeviceSelfInfo(
    publicKey: pubKey,
    publicKeyHex: _bytesToHex(pubKey),
    name: name,
  ));
}

ParsedFrame _parseContact(BufferReader r, int code) {
  // Contact frame uses FIXED offsets (after response code byte, already consumed):
  // [0-31] pub_key (32 bytes)
  // [32] adv_type, [33] flags, [34] pathLen
  // [35-98] path (64 bytes fixed)
  // [99-130] name (32 bytes, null-terminated)
  // [131-134] timestamp (uint32 LE)
  // [135-138] lat (int32 LE)
  // [139-142] lon (int32 LE)
  // [143-146] lastmod (uint32 LE)
  // SNR is encoded in pathLen sign bit or separate field
  final data = r.readBytes(r.remaining);
  if (data.length < pubKeySize + 3) return ParsedFrame(code);

  final pubKey = Uint8List.fromList(data.sublist(0, pubKeySize));
  final advType = data[32];
  final flags = data[33];
  final pathLenRaw = data[34];
  // pathLen can be signed (negative = SNR indicator in some firmware)
  final pathLen = pathLenRaw > 127 ? pathLenRaw - 256 : pathLenRaw;
  final safePathLen = pathLen > 0 ? (pathLen > 64 ? 64 : pathLen) : 0;
  final path = safePathLen > 0 ? Uint8List.fromList(data.sublist(35, 35 + safePathLen)) : Uint8List(0);

  // Name at fixed offset 99
  String name = '';
  if (data.length > 99) {
    final nameEnd = (99 + maxNameSize).clamp(0, data.length);
    final nameBytes = data.sublist(99, nameEnd);
    final nullIdx = nameBytes.indexOf(0);
    final trimmed = nullIdx >= 0 ? nameBytes.sublist(0, nullIdx) : nameBytes;
    try {
      name = utf8.decode(Uint8List.fromList(trimmed), allowMalformed: true);
    } catch (_) {
      name = String.fromCharCodes(trimmed);
    }
  }

  // Timestamp at offset 131
  int? lastSeen;
  if (data.length >= 135) {
    lastSeen = data[131] | (data[132] << 8) | (data[133] << 16) | (data[134] << 24);
    if (lastSeen == 0) lastSeen = null;
  }

  // SNR: derive from path data or use a default
  double? snr;
  // Some firmware encodes last SNR in the path bytes after the actual path
  if (safePathLen > 0 && safePathLen < 64 && data.length > 35 + safePathLen) {
    // SNR sometimes at end of path area
  }

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
  // Use fixed offsets matching reference app
  // After response code (already consumed):
  // Non-V3: [0-31]=pubkey [32-35]=timestamp [36]=flags/txtType [37+]=text
  // V3: [0-31]=pubkey [32]=pathLen [33]=flags [path...] [snr] [timestamp x4] [txtType] [text...]
  final data = r.readBytes(r.remaining);
  if (data.length < pubKeySize + 5) return ParsedFrame(code);

  final senderKey = Uint8List.fromList(data.sublist(0, pubKeySize));
  final isV3 = code == Resp.contactMsgRecvV3;

  int hopCount = 0;
  int? snr;
  int timestamp;
  String text;

  if (isV3) {
    final pathLen = data[32] > 127 ? data[32] - 256 : data[32];
    hopCount = pathLen > 0 ? pathLen : 0;
    var cursor = 33;
    final flags = data[cursor++];
    if (hopCount > 0 && data.length >= cursor + hopCount) {
      cursor += hopCount; // skip path bytes
    }
    if (cursor < data.length) {
      snr = data[cursor] > 127 ? data[cursor] - 256 : data[cursor];
      cursor++;
    }
    timestamp = cursor + 3 < data.length
        ? data[cursor] | (data[cursor + 1] << 8) | (data[cursor + 2] << 16) | (data[cursor + 3] << 24)
        : 0;
    cursor += 4;
    if (cursor < data.length) cursor++; // txtType
    final textBytes = cursor < data.length ? data.sublist(cursor) : <int>[];
    final nullIdx = textBytes.indexOf(0);
    final trimmed = nullIdx >= 0 ? textBytes.sublist(0, nullIdx) : textBytes;
    try {
      text = utf8.decode(Uint8List.fromList(trimmed), allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(trimmed);
    }
  } else {
    timestamp = data[32] | (data[33] << 8) | (data[34] << 16) | (data[35] << 24);
    // data[36] = flags/txtType
    final textBytes = data.length > 37 ? data.sublist(37) : <int>[];
    final nullIdx = textBytes.indexOf(0);
    final trimmed = nullIdx >= 0 ? textBytes.sublist(0, nullIdx) : textBytes;
    try {
      text = utf8.decode(Uint8List.fromList(trimmed), allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(trimmed);
    }
  }

  return ParsedFrame(code, IncomingMessage(
    senderKeyHex: _bytesToHex(senderKey),
    text: text,
    timestamp: timestamp,
    hopCount: hopCount,
    isFlood: false,
    snr: snr,
  ));
}

ParsedFrame _parseChannelMsg(BufferReader r, int code) {
  // Use raw bytes with fixed offsets (like reference app)
  // Response code already consumed, so data starts at byte 1 of original frame
  final data = r.readBytes(r.remaining);
  if (data.length < 7) return ParsedFrame(code);

  final isV3 = code == Resp.channelMsgRecvV3;
  int channelIdx;
  int hopCount = 0;
  int timestampOffset, textOffset;

  if (isV3) {
    // V3: [0]=SNR [1]=rsv1 [2]=rsv2 [3]=channel_idx [4]=path_len [path...] [txt_type] [timestamp x4] [text...]
    channelIdx = data[3];
    final pathLen = data[4] > 127 ? data[4] - 256 : data[4];
    var cursor = 5;
    final hasPathFlag = (data[1] & 0x01) != 0;
    final safePathLen = pathLen > 0 ? pathLen : 0;
    final canFitPath = safePathLen > 0 && data.length >= cursor + safePathLen + 5;
    final hasValidTxtType = cursor < data.length && (data[cursor] == 0 || data[cursor] == 5);
    if ((hasPathFlag || (canFitPath && !hasValidTxtType)) && canFitPath) {
      cursor += safePathLen;
    }
    hopCount = safePathLen;
    cursor += 1; // txt_type
    timestampOffset = cursor;
    textOffset = cursor + 4;
  } else {
    // Non-V3: [0]=channel_idx [1]=path_len [2]=txt_type [3-6]=timestamp [7+]=text
    channelIdx = data[0];
    hopCount = data[1] > 127 ? data[1] - 256 : data[1];
    // data[2] = txt_type (should be 0 for plain)
    timestampOffset = 3;
    textOffset = 7;
  }

  if (data.length < textOffset + 1) return ParsedFrame(code);

  final timestamp = data[timestampOffset] | (data[timestampOffset + 1] << 8) | 
                    (data[timestampOffset + 2] << 16) | (data[timestampOffset + 3] << 24);
  
  // Read null-terminated text
  final textBytes = data.sublist(textOffset);
  final nullIdx = textBytes.indexOf(0);
  final trimmed = nullIdx >= 0 ? textBytes.sublist(0, nullIdx) : textBytes;
  String fullText;
  try {
    fullText = utf8.decode(Uint8List.fromList(trimmed), allowMalformed: true);
  } catch (_) {
    fullText = String.fromCharCodes(trimmed);
  }

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
    isFlood: false,
  ));
}

ParsedFrame _parseBattStorage(BufferReader r, int code) {
  // Format: [battery_mv uint16 LE][storage_used_kb uint32 LE][storage_total_kb uint32 LE]
  if (r.remaining < 2) return ParsedFrame(code);
  final battMv = r.readUInt16LE();
  // Convert millivolts to percentage (Li-ion curve: 3.0V=0%, 4.2V=100%)
  final pct = ((battMv - 3000) / 12.0).clamp(0, 100).round();
  int storageFree = 0;
  if (r.remaining >= 8) {
    final usedKb = r.readUInt32LE();
    final totalKb = r.readUInt32LE();
    storageFree = totalKb > 0 ? ((totalKb - usedKb) * 100 ~/ totalKb) : 0;
  }
  return ParsedFrame(code, DeviceBattStorage(
    batteryPercent: pct,
    storageFreePercent: storageFree,
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
