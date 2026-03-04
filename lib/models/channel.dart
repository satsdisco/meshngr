class Channel {
  final String id;
  final String name;
  final int memberCount;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isJoined;
  final bool isMuted;

  const Channel({
    required this.id,
    required this.name,
    this.memberCount = 0,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isJoined = false,
    this.isMuted = false,
  });

  Channel copyWith({
    String? name,
    int? memberCount,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isJoined,
    bool? isMuted,
  }) {
    return Channel(
      id: id,
      name: name ?? this.name,
      memberCount: memberCount ?? this.memberCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isJoined: isJoined ?? this.isJoined,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
