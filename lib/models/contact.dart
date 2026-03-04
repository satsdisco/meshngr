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

  const Contact({
    required this.id,
    required this.name,
    this.alias,
    required this.address,
    this.trustLevel = TrustLevel.unknown,
    required this.lastSeen,
    this.signalStrength = 0,
    this.hopCount = 0,
    this.isOnline = false,
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

  Contact copyWith({
    String? name,
    String? alias,
    String? address,
    TrustLevel? trustLevel,
    DateTime? lastSeen,
    int? signalStrength,
    int? hopCount,
    bool? isOnline,
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
    );
  }
}
