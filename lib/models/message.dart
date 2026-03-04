enum DeliveryStatus {
  pending,    // queued locally, not yet sent to radio
  sent,       // sent to radio, awaiting ack
  delivered,  // delivery confirmed by recipient
  read,       // read by recipient (future)
  failed,     // delivery failed after retries
}

class MessageRoute {
  final int hopCount;
  final List<String> path; // node addresses in the route
  final int? rssi;         // signal strength at final hop

  const MessageRoute({
    required this.hopCount,
    this.path = const [],
    this.rssi,
  });
}

class Message {
  final String id;
  final String text;
  final DateTime timestamp;
  final String senderId;
  final bool isMe;
  final DeliveryStatus status;
  final MessageRoute? route;
  final String? failReason;
  final int retryCount;

  const Message({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.senderId,
    required this.isMe,
    this.status = DeliveryStatus.pending,
    this.route,
    this.failReason,
    this.retryCount = 0,
  });

  // Compat getters
  bool get delivered => status == DeliveryStatus.delivered || status == DeliveryStatus.read;

  Message copyWith({
    DeliveryStatus? status,
    MessageRoute? route,
    String? failReason,
    int? retryCount,
  }) {
    return Message(
      id: id,
      text: text,
      timestamp: timestamp,
      senderId: senderId,
      isMe: isMe,
      status: status ?? this.status,
      route: route ?? this.route,
      failReason: failReason ?? this.failReason,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
