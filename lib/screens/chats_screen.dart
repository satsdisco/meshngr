import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_list_item.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, cp, _) {
        final conversations = cp.activeConversations;

        if (conversations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_outline, size: 36, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 20),
                  Text('No conversations yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    'Add a contact from Nearby nodes\nand start messaging',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const Divider(indent: 76, endIndent: 16, height: 1),
          itemBuilder: (context, index) {
            final contact = conversations[index];
            return ChatListItem(
              contact: contact,
              lastMessage: cp.getLastMessage(contact.id),
              lastMessageTime: cp.getLastMessageTime(contact.id),
              unreadCount: cp.getUnreadCount(contact.id),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatDetailScreen(contact: contact)),
                );
              },
            );
          },
        );
      },
    );
  }
}
