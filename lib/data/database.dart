import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/contact.dart';
import '../models/channel.dart';
import '../models/message.dart';

class AppDatabase {
  static AppDatabase? _instance;
  static Database? _db;

  AppDatabase._();

  static Future<AppDatabase> get instance async {
    _instance ??= AppDatabase._();
    _db ??= await _instance!._initDb();
    return _instance!;
  }

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'meshngr.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        alias TEXT,
        address TEXT NOT NULL,
        trustLevel INTEGER NOT NULL DEFAULT 0,
        signalStrength INTEGER NOT NULL DEFAULT 0,
        hopCount INTEGER NOT NULL DEFAULT 0,
        isOnline INTEGER NOT NULL DEFAULT 0,
        lastSeen INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE channels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        memberCount INTEGER NOT NULL DEFAULT 0,
        lastMessage TEXT,
        lastMessageTime INTEGER,
        unreadCount INTEGER NOT NULL DEFAULT 0,
        isJoined INTEGER NOT NULL DEFAULT 0,
        isMuted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        senderId TEXT NOT NULL,
        isMe INTEGER NOT NULL DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 0,
        routeHopCount INTEGER,
        routeRssi INTEGER,
        routePath TEXT,
        failReason TEXT,
        retryCount INTEGER NOT NULL DEFAULT 0,
        senderName TEXT,
        senderColor INTEGER,
        contactId TEXT,
        channelId TEXT
      )
    ''');
  }

  // ── Contacts ──────────────────────────────────────────────────────────────

  Future<bool> hasContacts() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM contacts');
    return (result.first['count'] as int) > 0;
  }

  Future<List<Contact>> getAllContacts() async {
    final db = await _database;
    final rows = await db.query('contacts');
    return rows.map(_contactFromMap).toList();
  }

  Future<void> insertContact(Contact c) async {
    final db = await _database;
    await db.insert(
      'contacts',
      _contactToMap(c),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateContact(Contact c) async {
    final db = await _database;
    await db.update(
      'contacts',
      _contactToMap(c),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<void> deleteContact(String id) async {
    final db = await _database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'contactId = ?', whereArgs: [id]);
  }

  // ── Channels ──────────────────────────────────────────────────────────────

  Future<List<Channel>> getAllChannels() async {
    final db = await _database;
    final rows = await db.query('channels');
    return rows.map(_channelFromMap).toList();
  }

  Future<void> insertChannel(Channel c) async {
    final db = await _database;
    await db.insert(
      'channels',
      _channelToMap(c),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateChannel(Channel c) async {
    final db = await _database;
    await db.update(
      'channels',
      _channelToMap(c),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<Message>> getMessagesForContact(String contactId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_messageFromMap).toList();
  }

  Future<List<Message>> getMessagesForChannel(String channelId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'channelId = ?',
      whereArgs: [channelId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_messageFromMap).toList();
  }

  Future<void> upsertMessage(
    Message msg, {
    String? contactId,
    String? channelId,
  }) async {
    final db = await _database;
    await db.insert(
      'messages',
      _messageToMap(msg, contactId: contactId, channelId: channelId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMessage(String id) async {
    final db = await _database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  // ── Serialization helpers ─────────────────────────────────────────────────

  Map<String, dynamic> _contactToMap(Contact c) {
    return {
      'id': c.id,
      'name': c.name,
      'alias': c.alias,
      'address': c.address,
      'trustLevel': c.trustLevel.index,
      'signalStrength': c.signalStrength,
      'hopCount': c.hopCount,
      'isOnline': c.isOnline ? 1 : 0,
      'lastSeen': c.lastSeen.millisecondsSinceEpoch,
    };
  }

  Contact _contactFromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      name: map['name'] as String,
      alias: map['alias'] as String?,
      address: map['address'] as String,
      trustLevel: TrustLevel.values[map['trustLevel'] as int],
      signalStrength: map['signalStrength'] as int,
      hopCount: map['hopCount'] as int,
      isOnline: (map['isOnline'] as int) == 1,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] as int),
    );
  }

  Map<String, dynamic> _channelToMap(Channel c) {
    return {
      'id': c.id,
      'name': c.name,
      'memberCount': c.memberCount,
      'lastMessage': c.lastMessage,
      'lastMessageTime': c.lastMessageTime?.millisecondsSinceEpoch,
      'unreadCount': c.unreadCount,
      'isJoined': c.isJoined ? 1 : 0,
      'isMuted': c.isMuted ? 1 : 0,
    };
  }

  Channel _channelFromMap(Map<String, dynamic> map) {
    return Channel(
      id: map['id'] as String,
      name: map['name'] as String,
      memberCount: map['memberCount'] as int,
      lastMessage: map['lastMessage'] as String?,
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'] as int)
          : null,
      unreadCount: map['unreadCount'] as int,
      isJoined: (map['isJoined'] as int) == 1,
      isMuted: (map['isMuted'] as int) == 1,
    );
  }

  Map<String, dynamic> _messageToMap(
    Message msg, {
    String? contactId,
    String? channelId,
  }) {
    String? pathStr;
    if (msg.route != null && msg.route!.path.isNotEmpty) {
      pathStr = msg.route!.path.join(',');
    }
    return {
      'id': msg.id,
      'text': msg.text,
      'timestamp': msg.timestamp.millisecondsSinceEpoch,
      'senderId': msg.senderId,
      'isMe': msg.isMe ? 1 : 0,
      'status': msg.status.index,
      'routeHopCount': msg.route?.hopCount,
      'routeRssi': msg.route?.rssi,
      'routePath': pathStr,
      'failReason': msg.failReason,
      'retryCount': msg.retryCount,
      'senderName': msg.senderName,
      'senderColor': msg.senderColor,
      'contactId': contactId,
      'channelId': channelId,
    };
  }

  Message _messageFromMap(Map<String, dynamic> map) {
    MessageRoute? route;
    if (map['routeHopCount'] != null) {
      final pathStr = map['routePath'] as String?;
      route = MessageRoute(
        hopCount: map['routeHopCount'] as int,
        rssi: map['routeRssi'] as int?,
        path: (pathStr != null && pathStr.isNotEmpty)
            ? pathStr.split(',')
            : const [],
      );
    }
    return Message(
      id: map['id'] as String,
      text: map['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      senderId: map['senderId'] as String,
      isMe: (map['isMe'] as int) == 1,
      status: DeliveryStatus.values[map['status'] as int],
      route: route,
      failReason: map['failReason'] as String?,
      retryCount: map['retryCount'] as int,
      senderName: map['senderName'] as String?,
      senderColor: map['senderColor'] as int?,
    );
  }
}
