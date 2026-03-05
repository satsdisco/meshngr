import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/chat_provider.dart';
import 'channel_chat_screen.dart';

class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key});

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, cp, _) {
        final joined = cp.joinedChannels;
        final available = cp.availableChannels;

        if (joined.isEmpty && available.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.tag, size: 36, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 20),
                  Text('No channels yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    'Channels from your radio will\nappear here when connected.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Joined channels
            if (joined.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'JOINED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
                ),
              ),
              ...joined.map((channel) => _ChannelTile(
                channel: channel,
                timeLabel: _formatTime(channel.lastMessageTime),
                onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelChatScreen(channel: channel))); },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (channel.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          channel.unreadCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textTertiary),
                      color: AppColors.surfaceLight,
                      onSelected: (action) {
                        if (action == 'mute') cp.toggleMuteChannel(channel.id);
                        if (action == 'leave') cp.leaveChannel(channel.id);
                        if (action == 'remove') {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              title: Text('Remove #${channel.name}?'),
                              content: const Text('This will clear the channel slot on your radio. You can re-add it later.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () { Navigator.pop(ctx); cp.removeChannel(channel.id); },
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'mute',
                          child: Row(
                            children: [
                              Icon(channel.isMuted ? Icons.notifications : Icons.notifications_off, size: 18),
                              const SizedBox(width: 8),
                              Text(channel.isMuted ? 'Unmute' : 'Mute'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'leave',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 18, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Leave', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Remove from radio', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
            ],

            // Discovered channels (received messages but not explicitly joined)
            if (available.isNotEmpty) ...[
              if (joined.isNotEmpty) const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'OTHER ACTIVITY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Channels your radio picked up. Join to participate.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary, fontSize: 11),
                ),
              ),
              ...available.map((channel) => _ChannelTile(
                channel: channel,
                timeLabel: _formatTime(channel.lastMessageTime),
                onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelChatScreen(channel: channel))); },
                trailing: FilledButton.tonal(
                  onPressed: () => cp.joinChannel(channel.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Join'),
                ),
              )),
            ],
          ],
        );
      },
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final dynamic channel;
  final String timeLabel;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ChannelTile({
    required this.channel,
    required this.timeLabel,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tag, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(channel.name, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (timeLabel.isNotEmpty)
                        Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${channel.memberCount} members',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (channel.lastMessage != null) ...[
                        const SizedBox(width: 6),
                        Text('·', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            channel.lastMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
