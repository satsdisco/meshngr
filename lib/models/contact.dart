enum TrustLevel { unknown, saved, favorite }

class Contact {
  final String id;
  final String name;
  final String? alias; // user-given nickname
  final String address;
  final TrustLevel trustLevel;
  final DateTime lastSeen;
  final int signalStrength; // 0-4 bars
  final int hopCount;
  final bool isOnline;
  final int advType; // 1 = companion radio (person), other = repeater/infra

  const Contact({
    required this.id,
    required this.name,
    this.alias,
    this.address = '',
    this.trustLevel = TrustLevel.unknown,
    required this.lastSeen,
    this.signalStrength = 0,
    this.hopCount = 0,
    this.isOnline = false,
    this.advType = 1,
  });

  String get displayName => alias ?? name;

  String get initials {
    final n = displayName.trim();
    final parts = n.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
  }

  bool get isSaved => trustLevel == TrustLevel.saved || trustLevel == TrustLevel.favorite;

  String get lastSeenText {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 5) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return 'over a week ago';
  }

  Contact copyWith({
    String? name,
    String? alias,
    String? address,
    TrustLevel? trustLevel,
    DateTime? lastSeen,
    int? signalStrength,
    int? hopCount,
    bool? isOnline,
    int? advType,
  }) {
    return Contact(
      id: id,
      name: name ?? this.name,
      alias: alias ?? this.alias,
      address: address ?? this.address,
      trustLevel: trustLevel ?? this.trustLevel,
      lastSeen: lastSeen ?? this.lastSeen,
      signalStrength: signalStrength ?? this.signalStrength,
      hopCount: hopCount ?? this.hopCount,
      isOnline: isOnline ?? this.isOnline,
      advType: advType ?? this.advType,
    );
  }
}
