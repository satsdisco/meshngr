import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/contact.dart';
import 'contact_avatar.dart';

class ChatListItem extends StatelessWidget {
  final Contact contact;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.contact,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    required this.onTap,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ContactAvatar(contact: contact, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(lastMessageTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: hasUnread ? AppColors.accent : AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage ?? 'No messages yet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: hasUnread ? AppColors.textSecondary : AppColors.textTertiary,
                                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
