import 'dart:math';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../models/channel.dart';
import '../data/mock_data.dart';

class ChatProvider extends ChangeNotifier {
  List<Contact> _savedContacts = List.from(MockData.savedContacts);
  List<Contact> _nearbyNodes = List.from(MockData.nearbyNodes);
  List<Channel> _channels = List.from(MockData.channels);
  final Map<String, List<Message>> _conversations = Map.from(MockData.conversations);
  bool _isScanning = false;

  // Contacts
  List<Contact> get savedContacts => _savedContacts;
  List<Contact> get onlineContacts => _savedContacts.where((c) => c.isOnline).toList();
  List<Contact> get offlineContacts => _savedContacts.where((c) => !c.isOnline).toList();
  List<Contact> get favoriteContacts => _savedContacts.where((c) => c.trustLevel == TrustLevel.favorite).toList();

  // Nearby
  List<Contact> get nearbyNodes => _nearbyNodes;
  bool get isScanning => _isScanning;

  // Channels
  List<Channel> get channels => _channels;
  List<Channel> get joinedChannels => _channels.where((c) => c.isJoined).toList();
  List<Channel> get availableChannels => _channels.where((c) => !c.isJoined).toList();

  // DMs — only contacts with actual conversations, sorted by recency
  List<Contact> get activeConversations {
    final withMessages = _savedContacts.where((c) =>
      _conversations.containsKey(c.id) && _conversations[c.id]!.isNotEmpty
    ).toList();
    withMessages.sort((a, b) {
      final aTime = getLastMessageTime(a.id) ?? DateTime(2000);
      final bTime = getLastMessageTime(b.id) ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return withMessages;
  }

  List<Message> getMessages(String contactId) => _conversations[contactId] ?? [];

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

  // Send with realistic delivery simulation
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

    // Simulate: pending → sent (radio accepted)
    Future.delayed(const Duration(milliseconds: 300), () {
      _updateMessageStatus(contactId, msg.id, DeliveryStatus.sent);
    });

    // Simulate: sent → delivered (ack received) or failed
    final contact = _savedContacts.where((c) => c.id == contactId).firstOrNull;
    final isOnline = contact?.isOnline ?? false;

    if (isOnline) {
      final hops = contact?.hopCount ?? 1;
      final delayMs = 800 + (hops * 400) + Random().nextInt(500);
      Future.delayed(Duration(milliseconds: delayMs), () {
        _updateMessageStatus(
          contactId, msg.id, DeliveryStatus.delivered,
          route: MessageRoute(
            hopCount: hops,
            rssi: -(40 + Random().nextInt(30)),
          ),
        );
      });
    } else {
      // Offline contact — message stays as "sent" (not failed, just pending ack)
      // After a timeout, mark as failed
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
        }
      });
    }
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

    // Re-attempt delivery
    Future.delayed(const Duration(milliseconds: 400), () {
      _updateMessageStatus(contactId, messageId, DeliveryStatus.sent);
    });

    final contact = _savedContacts.where((c) => c.id == contactId).firstOrNull;
    if (contact?.isOnline ?? false) {
      Future.delayed(Duration(milliseconds: 1200 + Random().nextInt(800)), () {
        _updateMessageStatus(
          contactId, messageId, DeliveryStatus.delivered,
          route: MessageRoute(hopCount: contact!.hopCount),
        );
      });
    } else {
      Future.delayed(const Duration(seconds: 4), () {
        final currentMsgs = _conversations[contactId];
        if (currentMsgs == null) return;
        final currentIdx = currentMsgs.indexWhere((m) => m.id == messageId);
        if (currentIdx != -1 && currentMsgs[currentIdx].status == DeliveryStatus.sent) {
          _conversations[contactId]![currentIdx] = currentMsgs[currentIdx].copyWith(
            status: DeliveryStatus.failed,
            failReason: 'Node still unreachable',
          );
          notifyListeners();
        }
      });
    }
  }

  void _updateMessageStatus(String contactId, String messageId, DeliveryStatus status, {MessageRoute? route}) {
    final msgs = _conversations[contactId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    _conversations[contactId]![idx] = msgs[idx].copyWith(status: status, route: route);
    notifyListeners();
  }

  // Contact actions
  void addContact(Contact node, {String? alias}) {
    final contact = node.copyWith(alias: alias, trustLevel: TrustLevel.saved);
    _savedContacts.add(contact);
    _nearbyNodes.removeWhere((n) => n.id == node.id);
    notifyListeners();
  }

  void toggleFavorite(String contactId) {
    final idx = _savedContacts.indexWhere((c) => c.id == contactId);
    if (idx == -1) return;
    final c = _savedContacts[idx];
    _savedContacts[idx] = c.copyWith(
      trustLevel: c.trustLevel == TrustLevel.favorite ? TrustLevel.saved : TrustLevel.favorite,
    );
    notifyListeners();
  }

  void renameContact(String contactId, String newAlias) {
    final idx = _savedContacts.indexWhere((c) => c.id == contactId);
    if (idx == -1) return;
    _savedContacts[idx] = _savedContacts[idx].copyWith(alias: newAlias);
    notifyListeners();
  }

  void removeContact(String contactId) {
    final contact = _savedContacts.firstWhere((c) => c.id == contactId);
    _savedContacts.removeWhere((c) => c.id == contactId);
    _nearbyNodes.add(contact.copyWith(trustLevel: TrustLevel.unknown));
    _conversations.remove(contactId);
    notifyListeners();
  }

  // Channel actions
  void joinChannel(String channelId) {
    final idx = _channels.indexWhere((c) => c.id == channelId);
    if (idx == -1) return;
    _channels[idx] = _channels[idx].copyWith(isJoined: true);
    notifyListeners();
  }

  void leaveChannel(String channelId) {
    final idx = _channels.indexWhere((c) => c.id == channelId);
    if (idx == -1) return;
    _channels[idx] = _channels[idx].copyWith(isJoined: false);
    notifyListeners();
  }

  void toggleMuteChannel(String channelId) {
    final idx = _channels.indexWhere((c) => c.id == channelId);
    if (idx == -1) return;
    _channels[idx] = _channels[idx].copyWith(isMuted: !_channels[idx].isMuted);
    notifyListeners();
  }

  Future<void> refreshNearby() async {
    _isScanning = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));
    _isScanning = false;
    notifyListeners();
  }
}
