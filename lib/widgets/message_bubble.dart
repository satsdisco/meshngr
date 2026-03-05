import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onRetry;
  final VoidCallback? onLongPress;
  final bool showSenderName; // For channel messages: show sender name above bubble

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onLongPress,
    this.showSenderName = false,
  });

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isFailed = message.status == DeliveryStatus.failed;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: EdgeInsets.only(
            left: message.isMe ? 48 : 16,
            right: message.isMe ? 16 : 48,
            top: showSenderName ? 8 : 2,
            bottom: 2,
          ),
          child: Column(
            crossAxisAlignment:
                message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Main bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isFailed
                      ? AppColors.error.withValues(alpha: 0.15)
                      : message.isMe
                          ? AppColors.accent
                          : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(message.isMe ? 16 : 4),
                    bottomRight: Radius.circular(message.isMe ? 4 : 16),
                  ),
                  border: isFailed
                      ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender name for channel messages
                    if (showSenderName && !message.isMe && message.senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.senderName!,
                              style: TextStyle(
                                color: message.senderColor != null
                                    ? Color(message.senderColor!)
                                    : AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (message.route != null &&
                                message.route!.hopCount > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${message.route!.hopCount}h',
                                style: TextStyle(
                                  color: AppColors.textTertiary
                                      .withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isFailed
                            ? AppColors.error
                            : message.isMe
                                ? Colors.white
                                : AppColors.textPrimary,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Route info for received DM messages
                          if (!message.isMe &&
                              message.route != null &&
                              !showSenderName) ...[
                            Icon(
                              Icons.route,
                              size: 11,
                              color: AppColors.textTertiary.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${message.route!.hopCount}h',
                              style: TextStyle(
                                color:
                                    AppColors.textTertiary.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          // Timestamp
                          Text(
                            _formatTime(message.timestamp),
                            style: TextStyle(
                              color: isFailed
                                  ? AppColors.error.withValues(alpha: 0.7)
                                  : message.isMe
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          // Delivery status for sent messages
                          if (message.isMe) ...[
                            const SizedBox(width: 4),
                            _DeliveryIcon(status: message.status),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Failed message actions
              if (isFailed) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh,
                            size: 13, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(
                          message.failReason ?? 'Failed to send',
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '· Tap to retry',
                          style: TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Route info for sent DM messages (below bubble)
              if (message.isMe &&
                  message.route != null &&
                  message.route!.hopCount > 0 &&
                  !showSenderName) ...[
                const SizedBox(height: 2),
                Text(
                  '${message.route!.hopCount} hop${message.route!.hopCount != 1 ? 's' : ''}${message.route!.rssi != null ? ' · ${message.route!.rssi} dBm' : ''}',
                  style: TextStyle(
                    color: AppColors.textTertiary.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  final DeliveryStatus status;
  const _DeliveryIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DeliveryStatus.pending:
        return Icon(Icons.access_time,
            size: 13, color: Colors.white.withValues(alpha: 0.4));
      case DeliveryStatus.sent:
        return Icon(Icons.done,
            size: 14, color: Colors.white.withValues(alpha: 0.5));
      case DeliveryStatus.delivered:
        return Icon(Icons.done_all,
            size: 14, color: Colors.white.withValues(alpha: 0.7));
      case DeliveryStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Colors.white);
      case DeliveryStatus.failed:
        return const Icon(Icons.error_outline,
            size: 13, color: AppColors.error);
    }
  }
}
