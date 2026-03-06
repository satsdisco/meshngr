import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../models/channel.dart';
import '../data/mock_data.dart';
import '../data/database.dart';
import '../core/ble_service.dart';
import '../core/protocol.dart';
import '../core/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final BleService _ble;
  BleService get ble => _ble;

  // My Contacts — people the USER explicitly saved/named
  List<Contact> _myContacts = [];
  // Known Nodes — everything from the radio's contact list (not explicitly saved)
  List<Contact> _knownNodes = [];
  // Nearby Now — nodes actively broadcasting
  final List<Contact> _nearbyNodes = [];

  List<Channel> _channels = [];
  final Map<String, List<Message>> _conversations = {};
  final Map<String, List<Message>> _channelConversations = {};
  final Map<String, bool> _typingContacts = {};
  bool _isScanning = false;
  bool _demoMode = false;
  bool _contactsSynced = false;

  bool get demoMode => _demoMode;

  // Radio channel index → channel ID mapping
  final Map<int, String> _radioChannelMap = {};

  // Pending outbound messages: contactAddress → messageId (for delivery confirmation)
  final Map<String, String> _pendingByAddress = {};

  // Lazy DB reference — initialized once
  final Future<AppDatabase> _db = AppDatabase.instance;

  StreamSubscription<ParsedFrame>? _frameSub;

  static const _autoReplies = [
    'Copy that.',
    'Got it!',
    '10-4',
    'Thanks for the heads up.',
    'Roger.',
    'On my way.',
    'Stand by...',
    'Sounds good.',
    'Will do.',
    '👍',
  ];

  static const _senderColors = [
    0xFFF97316, 0xFF10B981, 0xFF06B6D4,
    0xFF8B5CF6, 0xFFEF4444, 0xFFEC4899,
    0xFFEAB308, 0xFF22D3EE,
  ];

  ChatProvider(this._ble) {
    _frameSub = _ble.frames.listen(_handleFrame);
  }

  // ── Frame handling ────────────────────────────────────────────────────────

  void _handleFrame(ParsedFrame frame) {
    switch (frame.code) {
      case Resp.selfInfo:
        // Device name is cached in BleService; nothing extra needed here
        break;

      case Resp.contact:
        if (frame.data is DeviceContact) {
          _mergeDeviceContact(frame.data as DeviceContact, fromRadioList: true);
        }
        break;

      case Resp.endOfContacts:
        _contactsSynced = true;
        // Remove any channels not confirmed by the radio
        final validIds = _radioChannelMap.values.toSet();
        _channels.removeWhere((c) => !validIds.contains(c.id));
        _ble.requestBatteryInfo();
        _ble.syncNextMessage();
        notifyListeners();
        break;

      case Resp.channelInfo:
        if (frame.data is DeviceChannel) {
          _handleChannelInfo(frame.data as DeviceChannel);
        }
        break;

      case Resp.contactMsgRecv:
      case Resp.contactMsgRecvV3:
        if (frame.data is IncomingMessage) {
          _handleIncomingDM(frame.data as IncomingMessage);
          _ble.syncNextMessage();
        }
        break;

      case Resp.channelMsgRecv:
      case Resp.channelMsgRecvV3:
        if (frame.data is IncomingChannelMessage) {
          _handleIncomingChannelMsg(frame.data as IncomingChannelMessage);
          _ble.syncNextMessage();
        }
        break;

      case Push.advert:
      case Push.newAdvert:
        if (frame.data is DeviceContact) {
          _handleAdvert(frame.data as DeviceContact);
        }
        break;

      case Resp.ok:
        // For channel messages, OK = sent confirmation
        _handleRadioSent();
        break;

      case Resp.sent:
        // DM sent confirmation (includes ack hash for repeat tracking)
        _handleRadioSent();
        break;

      case Push.sendConfirmed:
        if (frame.data is String) {
          _handleSendConfirmed(frame.data as String);
        }
        break;

      case Resp.noMoreMessages:
        // Nothing to do — all queued messages have been delivered
        break;
    }
  }

  void _mergeDeviceContact(DeviceContact dc, {bool fromRadioList = false}) {
    final keyHex = dc.publicKeyHex;
    if (keyHex.isEmpty) return;

    final snrBars = _snrToBars(dc.lastSNR);
    final isOnline = dc.lastSeen != null &&
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - dc.lastSeen! < 600;
    final lastSeen = dc.lastSeen != null
        ? DateTime.fromMillisecondsSinceEpoch(dc.lastSeen! * 1000)
        : DateTime.now();

    // Check if user already explicitly saved this contact
    final myIdx = _myContacts.indexWhere((c) => c.address == keyHex);
    if (myIdx != -1) {
      // Update signal/online info, preserve user's alias and trust level
      final existing = _myContacts[myIdx];
      _myContacts[myIdx] = existing.copyWith(
        signalStrength: snrBars,
        hopCount: dc.path.length,
        isOnline: isOnline,
        lastSeen: lastSeen,
      );
      _db.then((db) => db.updateContact(_myContacts[myIdx]));
      notifyListeners();
      return;
    }

    final contact = Contact(
      id: keyHex,
      name: dc.name.isNotEmpty ? dc.name : 'Node-${keyHex.substring(0, 6)}',
      address: keyHex,
      trustLevel: TrustLevel.unknown,
      lastSeen: lastSeen,
      signalStrength: snrBars,
      hopCount: dc.path.length,
      isOnline: isOnline,
      advType: dc.advType,
      latitude: dc.latitude,
      longitude: dc.longitude,
    );

    if (fromRadioList) {
      // From radio's contact list → Known Nodes (not My Contacts)
      final knownIdx = _knownNodes.indexWhere((c) => c.address == keyHex);
      if (knownIdx != -1) {
        _knownNodes[knownIdx] = contact;
      } else {
        _knownNodes.add(contact);
      }
    } else {
      // Advert/nearby broadcast → Nearby Now
      final nearbyIdx = _nearbyNodes.indexWhere((c) => c.address == keyHex);
      if (nearbyIdx != -1) {
        _nearbyNodes[nearbyIdx] = contact;
      } else {
        _nearbyNodes.add(contact);
      }
    }
    notifyListeners();
  }

  void _handleIncomingDM(IncomingMessage im) {
    final senderKey = im.senderKeyHex;

    // Find contact in myContacts first, then knownNodes
    Contact? contact = _myContacts.where((c) => c.address == senderKey).firstOrNull;
    contact ??= _knownNodes.where((c) => c.address == senderKey).firstOrNull;
    if (contact == null) {
      contact = Contact(
        id: senderKey,
        name: 'Node-${senderKey.substring(0, 6)}',
        address: senderKey,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(im.timestamp * 1000),
        trustLevel: TrustLevel.unknown,
        isOnline: true,
      );
      _knownNodes.add(contact);
    }

    final conversationId = contact.id;
    final msgId = '${im.timestamp}_dm_${senderKey.substring(0, 8)}';

    // Deduplicate
    final existing = _conversations[conversationId];
    if (existing != null && existing.any((m) => m.id == msgId)) return;

    final msg = Message(
      id: msgId,
      text: im.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(im.timestamp * 1000),
      senderId: conversationId,
      isMe: false,
      status: DeliveryStatus.delivered,
      route: MessageRoute(
        hopCount: im.hopCount,
        rssi: im.snr != null ? im.snr! * 4 : null,
      ),
    );

    _conversations.putIfAbsent(conversationId, () => []);
    _conversations[conversationId]!.add(msg);
    notifyListeners();
    _db.then((db) => db.upsertMessage(msg, contactId: conversationId));

    // Fire notification
    NotificationService().showDmNotification(
      senderName: contact.displayName,
      text: im.text,
      contactId: conversationId,
    );
  }

  void _handleIncomingChannelMsg(IncomingChannelMessage cm) {
    // Find or create channel for this radio index
    String channelId = _radioChannelMap[cm.channelIdx] ?? 'ch_radio_${cm.channelIdx}';

    if (!_channels.any((c) => c.id == channelId)) {
      // Auto-created channel from incoming message — NOT explicitly joined
      final newChannel = Channel(
        id: channelId,
        name: 'Channel ${cm.channelIdx}',
        isJoined: false, // Not joined by user — discovered via incoming msg
        memberCount: 0,
      );
      _channels.add(newChannel);
      _db.then((db) => db.insertChannel(newChannel));
    }
    _radioChannelMap[cm.channelIdx] = channelId;

    final color = _senderColors[cm.senderName.hashCode.abs() % _senderColors.length];
    final msgId = '${cm.timestamp}_ch${cm.channelIdx}_${cm.senderName.hashCode.abs()}';

    final existing = _channelConversations[channelId];
    if (existing != null && existing.any((m) => m.id == msgId)) return;

    final msg = Message(
      id: msgId,
      text: cm.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(cm.timestamp * 1000),
      senderId: cm.senderName,
      isMe: false,
      status: DeliveryStatus.delivered,
      senderName: cm.senderName,
      senderColor: color,
      route: MessageRoute(hopCount: cm.hopCount),
    );

    _channelConversations.putIfAbsent(channelId, () => []);
    _channelConversations[channelId]!.add(msg);

    final chIdx = _channels.indexWhere((c) => c.id == channelId);
    if (chIdx != -1) {
      _channels[chIdx] = _channels[chIdx].copyWith(
        lastMessage: '${cm.senderName}: ${cm.text}',
        lastMessageTime: msg.timestamp,
      );
      _db.then((db) => db.updateChannel(_channels[chIdx]));
    }
    notifyListeners();
    _db.then((db) => db.upsertMessage(msg, channelId: channelId));

    // Fire notification (skip muted channels)
    final ch = chIdx != -1 ? _channels[chIdx] : null;
    if (ch != null && !ch.isMuted) {
      NotificationService().showChannelNotification(
        channelName: ch.name,
        senderName: cm.senderName,
        text: cm.text,
        channelId: channelId,
      );
    }
  }

  void _handleChannelInfo(DeviceChannel dc) {
    // Skip completely empty channels (no name, all-zero key)
    if (dc.name.isEmpty || dc.name.trim().isEmpty) return;
    final isEmptyKey = dc.key.every((b) => b == 0);
    if (isEmptyKey && dc.name.startsWith('Channel ')) return;

    final channelId = 'radio_ch_${dc.index}';
    _radioChannelMap[dc.index] = channelId;

    // Channels with real names (not "Channel NNN") are considered explicitly joined
    final hasRealName = !RegExp(r'^Channel \d+$').hasMatch(dc.name);

    final existing = _channels.indexWhere((c) => c.id == channelId);
    final channel = Channel(
      id: channelId,
      name: dc.name,
      isJoined: hasRealName, // Only mark as joined if it has a real name
      memberCount: 0,
    );

    if (existing != -1) {
      _channels[existing] = channel.copyWith(
        lastMessage: _channels[existing].lastMessage,
        lastMessageTime: _channels[existing].lastMessageTime,
        unreadCount: _channels[existing].unreadCount,
      );
    } else {
      _channels.add(channel);
    }
    _db.then((db) => db.insertChannel(channel));
    notifyListeners();
  }

  void _handleAdvert(DeviceContact dc) {
    // Don't show adverts for already-saved contacts in nearby
    final alreadySaved = _myContacts.any((c) => c.address == dc.publicKeyHex);
    if (alreadySaved) {
      _mergeDeviceContact(dc, fromRadioList: false);
      return;
    }
    _mergeDeviceContact(dc, fromRadioList: false);
  }

  void _handleRadioSent() {
    // Mark the most recent pending channel message as sent
    for (final entry in _channelConversations.entries) {
      final msgs = entry.value;
      for (int i = msgs.length - 1; i >= 0; i--) {
        if (msgs[i].isMe && msgs[i].status == DeliveryStatus.pending) {
          _channelConversations[entry.key]![i] = msgs[i].copyWith(
            status: DeliveryStatus.sent,
          );
          notifyListeners();
          _db.then((db) => db.upsertMessage(_channelConversations[entry.key]![i], channelId: entry.key));
          return;
        }
      }
    }
    // Also check DM conversations
    for (final entry in _conversations.entries) {
      final msgs = entry.value;
      for (int i = msgs.length - 1; i >= 0; i--) {
        if (msgs[i].isMe && msgs[i].status == DeliveryStatus.pending) {
          _conversations[entry.key]![i] = msgs[i].copyWith(
            status: DeliveryStatus.sent,
          );
          notifyListeners();
          _db.then((db) => db.upsertMessage(_conversations[entry.key]![i], contactId: entry.key));
          return;
        }
      }
    }
  }

  void _handleSendConfirmed(String recipientKeyHex) {
    final messageId = _pendingByAddress[recipientKeyHex];
    if (messageId == null) return;

    // Find the conversation with this contact (check both lists)
    Contact? contact = _myContacts.where((c) => c.address == recipientKeyHex).firstOrNull;
    contact ??= _knownNodes.where((c) => c.address == recipientKeyHex).firstOrNull;
    final convId = contact?.id ?? recipientKeyHex;

    final msgs = _conversations[convId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    _conversations[convId]![idx] = msgs[idx].copyWith(status: DeliveryStatus.delivered);
    _pendingByAddress.remove(recipientKeyHex);
    notifyListeners();
    _db.then((db) => db.upsertMessage(_conversations[convId]![idx], contactId: convId));
  }

  int _snrToBars(double? snr) {
    if (snr == null) return 0;
    if (snr > 5) return 4;
    if (snr > 0) return 3;
    if (snr > -5) return 2;
    if (snr > -10) return 1;
    return 0;
  }

  // ── Contacts ──────────────────────────────────────────────────────────────

  /// User's explicitly saved contacts
  List<Contact> get myContacts => _myContacts;
  /// All contacts from the radio's stored list (not explicitly saved by user)
  List<Contact> get knownNodes => _knownNodes;
  /// Combined for backward compat — searches both lists
  List<Contact> get savedContacts => [..._myContacts, ..._knownNodes];
  List<Contact> get onlineContacts =>
      _myContacts.where((c) => c.isOnline).toList();
  List<Contact> get offlineContacts =>
      _myContacts.where((c) => !c.isOnline).toList();
  List<Contact> get favoriteContacts =>
      _myContacts.where((c) => c.trustLevel == TrustLevel.favorite).toList();
  bool get contactsSynced => _contactsSynced;

  // ── Nearby ────────────────────────────────────────────────────────────────

  List<Contact> get nearbyNodes => _nearbyNodes;
  bool get isScanning => _isScanning;

  // ── Channels ──────────────────────────────────────────────────────────────

  List<Channel> get channels => _channels;
  List<Channel> get joinedChannels =>
      _channels.where((c) => c.isJoined).toList();
  List<Channel> get availableChannels =>
      _channels.where((c) => !c.isJoined).toList();

  // ── DM conversations ──────────────────────────────────────────────────────

  List<Contact> get activeConversations {
    final allContacts = [..._myContacts, ..._knownNodes];
    final withMessages = allContacts
        .where((c) =>
            _conversations.containsKey(c.id) &&
            _conversations[c.id]!.isNotEmpty)
        .toList();
    withMessages.sort((a, b) {
      final aTime = getLastMessageTime(a.id) ?? DateTime(2000);
      final bTime = getLastMessageTime(b.id) ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return withMessages;
  }

  List<Message> getMessages(String contactId) =>
      _conversations[contactId] ?? [];

  String? getLastMessage(String contactId) {
    final msgs = _conversations[contactId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last.text;
  }

  DateTime? getLastMessageTime(String contactId) {
    final msgs = _conversations[contactId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last.timestamp;
  }

  int getUnreadCount(String contactId) {
    final msgs = _conversations[contactId];
    if (msgs == null) return 0;
    return msgs.where((m) => !m.isMe && m.status != DeliveryStatus.read).length;
  }

  // ── Channel conversations ─────────────────────────────────────────────────

  List<Message> getChannelMessages(String channelId) =>
      _channelConversations[channelId] ?? [];

  String? getChannelLastMessage(String channelId) {
    final msgs = _channelConversations[channelId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last.text;
  }

  DateTime? getChannelLastMessageTime(String channelId) {
    final msgs = _channelConversations[channelId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last.timestamp;
  }

  // ── Typing indicator ──────────────────────────────────────────────────────

  bool isTyping(String contactId) => _typingContacts[contactId] ?? false;

  // ── Send DM ───────────────────────────────────────────────────────────────

  void sendMessage(String contactId, String text) {
    final msg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      senderId: 'me',
      isMe: true,
      status: DeliveryStatus.pending,
    );
    _conversations.putIfAbsent(contactId, () => []);
    _conversations[contactId]!.add(msg);
    notifyListeners();
    _db.then((db) => db.upsertMessage(msg, contactId: contactId));

    Contact? contact = _myContacts.where((c) => c.id == contactId).firstOrNull;
    contact ??= _knownNodes.where((c) => c.id == contactId).firstOrNull;

    // Real BLE send
    if (_ble.isConnected && contact != null && _isValidPubKeyHex(contact.address)) {
      _pendingByAddress[contact.address] = msg.id;
      _ble.sendTextMessage(contact.address, text);
      // Mark as sent after brief delay (radio accepted it)
      Future.delayed(const Duration(milliseconds: 200), () {
        _updateMessageStatus(contactId, msg.id, DeliveryStatus.sent);
      });
      // Timeout: mark failed if no sendConfirmed after 30s
      Future.delayed(const Duration(seconds: 30), () {
        final current = _conversations[contactId];
        if (current == null) return;
        final idx = current.indexWhere((m) => m.id == msg.id);
        if (idx != -1 && current[idx].status == DeliveryStatus.sent) {
          _conversations[contactId]![idx] = current[idx].copyWith(
            status: DeliveryStatus.failed,
            failReason: 'No acknowledgement received',
          );
          if (contact != null) _pendingByAddress.remove(contact.address);
          notifyListeners();
          _db.then((db) => db.upsertMessage(_conversations[contactId]![idx], contactId: contactId));
        }
      });
      return;
    }

    // No BLE connected
    if (_demoMode) {
      // Demo simulation fallback
      Future.delayed(const Duration(milliseconds: 300), () {
        _updateMessageStatus(contactId, msg.id, DeliveryStatus.sent);
      });

      final isOnline = contact?.isOnline ?? false;

      if (isOnline) {
        final hops = contact?.hopCount ?? 1;
        final delayMs = 800 + (hops * 400) + Random().nextInt(500);
        Future.delayed(Duration(milliseconds: delayMs), () {
          _updateMessageStatus(
            contactId,
            msg.id,
            DeliveryStatus.delivered,
            route: MessageRoute(
              hopCount: hops,
              rssi: -(40 + Random().nextInt(30)),
            ),
          );
          _simulateTypingAndReply(contactId);
        });
      } else {
        Future.delayed(const Duration(seconds: 5), () {
          final msgs = _conversations[contactId];
          if (msgs == null) return;
          final idx = msgs.indexWhere((m) => m.id == msg.id);
          if (idx != -1 && msgs[idx].status == DeliveryStatus.sent) {
            _conversations[contactId]![idx] = msgs[idx].copyWith(
              status: DeliveryStatus.failed,
              failReason: 'Node unreachable',
            );
            notifyListeners();
            _db.then((db) =>
                db.upsertMessage(_conversations[contactId]![idx], contactId: contactId));
          }
        });
      }
    } else {
      // Real mode, no BLE — mark as failed immediately
      Future.delayed(const Duration(milliseconds: 500), () {
        _updateMessageStatus(contactId, msg.id, DeliveryStatus.failed);
        final msgs = _conversations[contactId];
        if (msgs == null) return;
        final idx = msgs.indexWhere((m) => m.id == msg.id);
        if (idx != -1) {
          _conversations[contactId]![idx] = msgs[idx].copyWith(
            failReason: 'Radio not connected',
          );
          notifyListeners();
        }
      });
    }
  }

  bool _isValidPubKeyHex(String address) =>
      address.length == 64 && !address.startsWith('0x');

  void _simulateTypingAndReply(String contactId) {
    _typingContacts[contactId] = true;
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      _typingContacts[contactId] = false;

      final reply =
          _autoReplies[DateTime.now().millisecond % _autoReplies.length];
      final replyMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: reply,
        timestamp: DateTime.now(),
        senderId: contactId,
        isMe: false,
        status: DeliveryStatus.delivered,
      );
      _conversations.putIfAbsent(contactId, () => []);
      _conversations[contactId]!.add(replyMsg);
      notifyListeners();
      _db.then((db) => db.upsertMessage(replyMsg, contactId: contactId));
    });
  }

  void retryMessage(String contactId, String messageId) {
    final msgs = _conversations[contactId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final old = msgs[idx];
    _conversations[contactId]![idx] = old.copyWith(
      status: DeliveryStatus.pending,
      retryCount: old.retryCount + 1,
    );
    notifyListeners();
    _db.then((db) =>
        db.upsertMessage(_conversations[contactId]![idx], contactId: contactId));

    Contact? contact = _myContacts.where((c) => c.id == contactId).firstOrNull;
    contact ??= _knownNodes.where((c) => c.id == contactId).firstOrNull;

    // Real BLE retry
    if (_ble.isConnected && contact != null && _isValidPubKeyHex(contact.address)) {
      _pendingByAddress[contact.address] = messageId;
      _ble.sendTextMessage(contact.address, old.text);
      Future.delayed(const Duration(milliseconds: 200), () {
        _updateMessageStatus(contactId, messageId, DeliveryStatus.sent);
      });
      return;
    }

    if (_demoMode) {
      Future.delayed(const Duration(milliseconds: 400), () {
        _updateMessageStatus(contactId, messageId, DeliveryStatus.sent);
      });

      if (contact?.isOnline ?? false) {
        Future.delayed(Duration(milliseconds: 1200 + Random().nextInt(800)), () {
          _updateMessageStatus(
            contactId,
            messageId,
            DeliveryStatus.delivered,
            route: MessageRoute(hopCount: contact!.hopCount),
          );
        });
      } else {
        Future.delayed(const Duration(seconds: 4), () {
          final currentMsgs = _conversations[contactId];
          if (currentMsgs == null) return;
          final currentIdx = currentMsgs.indexWhere((m) => m.id == messageId);
          if (currentIdx != -1 &&
              currentMsgs[currentIdx].status == DeliveryStatus.sent) {
            _conversations[contactId]![currentIdx] =
                currentMsgs[currentIdx].copyWith(
              status: DeliveryStatus.failed,
              failReason: 'Node still unreachable',
            );
            notifyListeners();
            _db.then((db) => db.upsertMessage(
                _conversations[contactId]![currentIdx],
                contactId: contactId));
          }
        });
      }
    } else {
      // Real mode, no BLE — fail immediately
      Future.delayed(const Duration(milliseconds: 500), () {
        _updateMessageStatus(contactId, messageId, DeliveryStatus.failed);
      });
    }
  }

  void deleteMessage(String contactId, String messageId) {
    _conversations[contactId]?.removeWhere((m) => m.id == messageId);
    notifyListeners();
    _db.then((db) => db.deleteMessage(messageId));
  }

  void _updateMessageStatus(
    String contactId,
    String messageId,
    DeliveryStatus status, {
    MessageRoute? route,
  }) {
    final msgs = _conversations[contactId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    _conversations[contactId]![idx] =
        msgs[idx].copyWith(status: status, route: route);
    notifyListeners();
    _db.then((db) => db.upsertMessage(
        _conversations[contactId]![idx],
        contactId: contactId));
  }

  // ── Send channel message ──────────────────────────────────────────────────

  Future<void> sendChannelMessage(String channelId, String text) async {
    final msg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      senderId: 'me',
      isMe: true,
      senderName: 'You',
      senderColor: 0xFF4A9EFF,
      // Start as pending — will move to sent when radio confirms (code=6)
      status: _ble.isConnected ? DeliveryStatus.pending : DeliveryStatus.failed,
      failReason: _ble.isConnected ? null : 'Radio not connected',
    );
    _channelConversations.putIfAbsent(channelId, () => []);
    _channelConversations[channelId]!.add(msg);

    final idx = _channels.indexWhere((c) => c.id == channelId);
    if (idx != -1) {
      _channels[idx] = _channels[idx].copyWith(
        lastMessage: text,
        lastMessageTime: msg.timestamp,
      );
      _db.then((db) => db.updateChannel(_channels[idx]));
    }
    notifyListeners();
    _db.then((db) => db.upsertMessage(msg, channelId: channelId));

    // Real BLE send
    if (_ble.isConnected) {
      final radioIdx = _getRadioChannelIdx(channelId);
      debugPrint('SEND: channelId="$channelId" → radioIdx=$radioIdx');
      debugPrint('  radioChannelMap=$_radioChannelMap');
      debugPrint('  all channel IDs: ${_channels.map((c) => "${c.id}(${c.name})").toList()}');
      try {
        await _ble.sendChannelMessage(radioIdx, text);
        // Message stays pending until radio confirms with Resp.sent (code=6)
        // _handleRadioSent() will update status when we get the confirmation
      } catch (e) {
        // BLE send failed
        final msgs = _channelConversations[channelId];
        if (msgs != null) {
          final msgIdx = msgs.indexWhere((m) => m.id == msg.id);
          if (msgIdx != -1) {
            _channelConversations[channelId]![msgIdx] = msgs[msgIdx].copyWith(
              status: DeliveryStatus.failed,
              failReason: 'Send failed: $e',
            );
            notifyListeners();
          }
        }
      }
    }
  }

  Future<void> retryChannelMessage(String channelId, String messageId) async {
    final msgs = _channelConversations[channelId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final old = msgs[idx];
    _channelConversations[channelId]![idx] = old.copyWith(
      status: DeliveryStatus.pending,
      retryCount: old.retryCount + 1,
    );
    notifyListeners();
    _db.then((db) => db.upsertMessage(_channelConversations[channelId]![idx], channelId: channelId));

    if (_ble.isConnected) {
      try {
        final radioIdx = _getRadioChannelIdx(channelId);
        await _ble.sendChannelMessage(radioIdx, old.text);
      } catch (e) {
        _channelConversations[channelId]![idx] = old.copyWith(
          status: DeliveryStatus.failed,
          failReason: 'Retry failed: $e',
        );
        notifyListeners();
      }
    } else {
      _channelConversations[channelId]![idx] = old.copyWith(
        status: DeliveryStatus.failed,
        failReason: 'Radio not connected',
      );
      notifyListeners();
    }
  }

  int _getRadioChannelIdx(String channelId) {
    // Check reverse map first
    for (final entry in _radioChannelMap.entries) {
      if (entry.value == channelId) {
        debugPrint('Channel "$channelId" → radio idx ${entry.key} (from map)');
        return entry.key;
      }
    }
    // For 'radio_ch_N' IDs (from _handleChannelInfo)
    final match = RegExp(r'radio_ch_(\d+)').firstMatch(channelId);
    if (match != null) {
      final idx = int.parse(match.group(1)!);
      debugPrint('Channel "$channelId" → radio idx $idx (from ID pattern)');
      return idx;
    }
    // For 'ch_radio_N' IDs (from _handleIncomingChannelMsg)
    final match2 = RegExp(r'ch_radio_(\d+)').firstMatch(channelId);
    if (match2 != null) {
      final idx = int.parse(match2.group(1)!);
      debugPrint('Channel "$channelId" → radio idx $idx (from ch_radio pattern)');
      return idx;
    }
    // Try matching channel name to radio channels
    final channel = _channels.firstWhere((c) => c.id == channelId, orElse: () => Channel(id: '', name: ''));
    if (channel.name.isNotEmpty) {
      for (final entry in _radioChannelMap.entries) {
        final mapped = _channels.where((c) => c.id == entry.value).firstOrNull;
        if (mapped != null && mapped.name == channel.name) {
          debugPrint('Channel "$channelId" → radio idx ${entry.key} (name match: ${channel.name})');
          return entry.key;
        }
      }
    }
    debugPrint('Channel "$channelId" → DEFAULT idx 0 (no match found! map=$_radioChannelMap)');
    return 0;
  }

  void deleteChannelMessage(String channelId, String messageId) {
    _channelConversations[channelId]?.removeWhere((m) => m.id == messageId);
    notifyListeners();
    _db.then((db) => db.deleteMessage(messageId));
  }

  // ── Contact actions ───────────────────────────────────────────────────────

  void addContact(Contact node, {String? alias}) {
    final contact = node.copyWith(alias: alias, trustLevel: TrustLevel.saved);
    _myContacts.add(contact);
    _nearbyNodes.removeWhere((n) => n.id == node.id);
    _knownNodes.removeWhere((n) => n.id == node.id);
    notifyListeners();
    _db.then((db) => db.insertContact(contact));

    // Tell radio to save this contact (only if we have a real public key)
    if (_ble.isConnected && _isValidPubKeyHex(node.address)) {
      _ble.sendFrame(buildAddUpdateContactFrame(node.address, name: node.name));
    }
  }

  void toggleFavorite(String contactId) {
    final idx = _myContacts.indexWhere((c) => c.id == contactId);
    if (idx == -1) return;
    final c = _myContacts[idx];
    _myContacts[idx] = c.copyWith(
      trustLevel:
          c.trustLevel == TrustLevel.favorite ? TrustLevel.saved : TrustLevel.favorite,
    );
    notifyListeners();
    _db.then((db) => db.updateContact(_myContacts[idx]));
  }

  void renameContact(String contactId, String newAlias) {
    final idx = _myContacts.indexWhere((c) => c.id == contactId);
    if (idx == -1) return;
    _myContacts[idx] = _myContacts[idx].copyWith(alias: newAlias);
    notifyListeners();
    _db.then((db) => db.updateContact(_myContacts[idx]));
  }

  void removeContact(String contactId) {
    Contact? contact;
    try {
      contact = _myContacts.firstWhere((c) => c.id == contactId);
    } catch (_) {}
    _myContacts.removeWhere((c) => c.id == contactId);
    if (contact != null) {
      _knownNodes.add(contact.copyWith(trustLevel: TrustLevel.unknown));
    }
    _conversations.remove(contactId);
    notifyListeners();
    _db.then((db) => db.deleteContact(contactId));

    // Tell radio to remove contact (only for real keys)
    if (contact != null && _ble.isConnected && _isValidPubKeyHex(contact.address)) {
      _ble.sendFrame(buildRemoveContactFrame(contact.address));
    }
  }

  // ── Channel actions ───────────────────────────────────────────────────────

  void joinChannel(String channelId) {
    final idx = _channels.indexWhere((c) => c.id == channelId);
    if (idx == -1) return;
    _channels[idx] = _channels[idx].copyWith(isJoined: true);
    notifyListeners();
    _db.then((db) => db.updateChannel(_channels[idx]));
  }

  void leaveChannel(String channelId) {
    // Actually remove from radio to free the slot
    removeChannel(channelId);
  }

  /// Remove a channel completely (clears radio slot + local data)
  void removeChannel(String channelId) {
    final idx = _channels.indexWhere((c) => c.id == channelId);
    if (idx == -1) return;

    // Extract radio slot index
    final match = RegExp(r'radio_ch_(\d+)').firstMatch(channelId);
    if (match != null && _ble.isConnected) {
      final slotIdx = int.parse(match.group(1)!);
      _ble.removeChannel(slotIdx);
    }

    _channels.removeAt(idx);
    _channelConversations.remove(channelId);
    notifyListeners();
    _db.then((db) => db.deleteChannel(channelId));
  }

  void toggleMuteChannel(String channelId) {
    final idx = _channels.indexWhere((c) => c.id == channelId);
    if (idx == -1) return;
    _channels[idx] =
        _channels[idx].copyWith(isMuted: !_channels[idx].isMuted);
    notifyListeners();
    _db.then((db) => db.updateChannel(_channels[idx]));
  }

  // ── Nearby ────────────────────────────────────────────────────────────────

  Future<void> refreshNearby() async {
    _isScanning = true;
    notifyListeners();
    if (_ble.isConnected) {
      // Request a self-advert broadcast to stimulate neighbor responses
      await _ble.sendAdvert(flood: false);
    }
    await Future.delayed(const Duration(seconds: 1));
    _isScanning = false;
    notifyListeners();
  }

  // ── Demo mode ──────────────────────────────────────────────────────────────

  void enableDemoMode() {
    _demoMode = true;
    _myContacts = List.from(MockData.savedContacts);
    _nearbyNodes.clear();
    _nearbyNodes.addAll(MockData.nearbyNodes);
    _channels = List.from(MockData.channels);
    _conversations.clear();
    _conversations.addAll(Map.from(MockData.conversations));
    _channelConversations.clear();
    _channelConversations.addAll(Map.from(MockData.channelConversations));
    notifyListeners();
  }

  /// Count unique senders in a channel's conversation
  int getChannelActiveMemberCount(String channelId) {
    final msgs = _channelConversations[channelId];
    if (msgs == null || msgs.isEmpty) return 0;
    final senders = <String>{};
    for (final m in msgs) {
      if (!m.isMe && m.senderName != null && m.senderName!.isNotEmpty) {
        senders.add(m.senderName!);
      }
    }
    return senders.length;
  }

  /// Find a known node by sender name
  Contact? findNodeBySenderName(String senderName) {
    // Exact match first
    for (final c in _knownNodes) {
      if (c.name == senderName) return c;
    }
    // Try prefix match (sender names can be truncated)
    for (final c in _knownNodes) {
      if (c.name.startsWith(senderName) || senderName.startsWith(c.name)) return c;
    }
    return null;
  }

  void clearKnownNodes() {
    _knownNodes.clear();
    notifyListeners();
    // Re-sync contacts from radio
    if (_ble.isConnected) {
      _ble.sendFrame(buildGetContactsFrame());
    }
  }

  Future<void> clearAllData() async {
    final db = await _db;
    await db.deleteAll();
    _myContacts.clear();
    _knownNodes.clear();
    _nearbyNodes.clear();
    _channels.clear();
    _conversations.clear();
    _channelConversations.clear();
    _radioChannelMap.clear();
    notifyListeners();
  }

  void disableDemoMode() {
    _demoMode = false;
    _myContacts.clear();
    _knownNodes.clear();
    _nearbyNodes.clear();
    _channels.clear();
    _conversations.clear();
    _channelConversations.clear();
    notifyListeners();
    // Reload from DB (real data only)
    initialize();
  }

  // ── DB initialization ─────────────────────────────────────────────────────

  Future<void> initialize() async {
    final db = await _db;

    // Load persisted real data
    final allContacts = await db.getAllContacts();
    _myContacts = allContacts.where((c) => c.trustLevel == TrustLevel.saved || c.trustLevel == TrustLevel.favorite).toList();
    _knownNodes = allContacts.where((c) => c.trustLevel == TrustLevel.unknown).toList();
    _channels = await db.getAllChannels();

    _conversations.clear();
    for (final contact in allContacts) {
      final msgs = await db.getMessagesForContact(contact.id);
      if (msgs.isNotEmpty) _conversations[contact.id] = msgs;
    }

    _channelConversations.clear();
    for (final channel in _channels) {
      final msgs = await db.getMessagesForChannel(channel.id);
      if (msgs.isNotEmpty) _channelConversations[channel.id] = msgs;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _frameSub?.cancel();
    super.dispose();
  }
}
