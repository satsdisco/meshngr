import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../models/contact.dart';
import '../widgets/contact_avatar.dart';
import 'chat_detail_screen.dart';

class ChannelChatScreen extends StatefulWidget {
  final Channel channel;
  const ChannelChatScreen({super.key, required this.channel});

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  void _showSenderProfile(BuildContext context, String senderName) {
    final cp = context.read<ChatProvider>();
    final node = cp.findNodeBySenderName(senderName);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContactAvatar(contact: Contact(id: senderName, name: senderName, lastSeen: DateTime.now()), size: 64, showOnlineIndicator: false),
            const SizedBox(height: 12),
            Text(senderName, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              node != null
                  ? (node.advType == 1 ? 'Companion Radio · ${node.lastSeenText}' : 'Repeater / Infrastructure')
                  : 'Seen in ${widget.channel.name}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    if (node != null) {
                      final saved = node.copyWith(trustLevel: TrustLevel.saved);
                      cp.addContact(saved, alias: senderName);
                    } else {
                      cp.addContact(Contact(
                        id: senderName,
                        name: senderName,
                        trustLevel: TrustLevel.saved,
                        lastSeen: DateTime.now(),
                      ), alias: senderName);
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$senderName saved to contacts')),
                    );
                  },
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Save Contact'),
                ),
                if (node != null && node.advType == 1)
                  OutlinedButton.icon(
                    onPressed: () {
                      final saved = node.copyWith(trustLevel: TrustLevel.saved);
                      cp.addContact(saved, alias: senderName);
                      Navigator.pop(ctx);
                      // Navigate to DM
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(contact: saved),
                      ));
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Send DM'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100;
      if (_showScrollToBottom == atBottom) {
        setState(() => _showScrollToBottom = !atBottom);
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatProvider>().sendChannelMessage(widget.channel.id, text);
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showMessageActions(BuildContext context, Message msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.textSecondary),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            if (msg.isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  context.read<ChatProvider>().deleteChannelMessage(widget.channel.id, msg.id);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
              title: const Text('Info'),
              onTap: () {
                Navigator.pop(context);
                _showMessageInfo(context, msg);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageInfo(BuildContext context, Message msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Message Info', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _InfoRow(label: 'From', value: msg.senderName ?? (msg.isMe ? 'You' : 'Unknown')),
            _InfoRow(label: 'Time', value: '${msg.timestamp.day}/${msg.timestamp.month}/${msg.timestamp.year} ${_formatTime(msg.timestamp)}'),
            if (msg.route != null) ...[
              _InfoRow(label: 'Hops', value: '${msg.route!.hopCount}'),
              if (msg.route!.rssi != null)
                _InfoRow(label: 'Signal', value: '${msg.route!.rssi} dBm'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tag, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.channel.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    context.read<ChatProvider>().getChannelActiveMemberCount(widget.channel.id) > 0 ? '${context.read<ChatProvider>().getChannelActiveMemberCount(widget.channel.id)} active' : 'Channel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: () => _showChannelInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final messages = chatProvider.getChannelMessages(widget.channel.id);

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.tag, size: 36, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No messages in ${widget.channel.name}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to say something!',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final prevMsg = index > 0 ? messages[index - 1] : null;
                        final showSender = prevMsg == null ||
                            prevMsg.senderId != msg.senderId ||
                            msg.timestamp.difference(prevMsg.timestamp).inMinutes > 2;

                        return GestureDetector(
                          onLongPress: () => _showMessageActions(context, msg),
                          child: _ChannelBubble(
                            message: msg,
                            showSender: showSender,
                            formatTime: _formatTime,
                            onSenderTap: (name) => _showSenderProfile(context, name),
                          ),
                        );
                      },
                    ),
                    if (_showScrollToBottom)
                      Positioned(
                        right: 16,
                        bottom: 8,
                        child: FloatingActionButton.small(
                          onPressed: () {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          backgroundColor: AppColors.surface,
                          child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Input
          Container(
            padding: EdgeInsets.only(
              left: 12, right: 8, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.channel.name}...',
                        hintStyle: const TextStyle(color: AppColors.textTertiary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded, color: AppColors.accent),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChannelInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tag, color: AppColors.accent, size: 30),
            ),
            const SizedBox(height: 16),
            Text(widget.channel.name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(context.read<ChatProvider>().getChannelActiveMemberCount(widget.channel.id) > 0 ? '${context.read<ChatProvider>().getChannelActiveMemberCount(widget.channel.id)} active' : 'Channel', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Channel messages are broadcast to all members on the mesh who have joined this channel.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
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

class _ChannelBubble extends StatelessWidget {
  final Message message;
  final bool showSender;
  final String Function(DateTime) formatTime;
  final void Function(String senderName)? onSenderTap;

  const _ChannelBubble({
    required this.message,
    required this.showSender,
    required this.formatTime,
    this.onSenderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: EdgeInsets.only(
          left: message.isMe ? 48 : 16,
          right: message.isMe ? 16 : 48,
          top: showSender ? 8 : 2,
          bottom: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isMe ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isMe ? 16 : 4),
            bottomRight: Radius.circular(message.isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSender && !message.isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => onSenderTap?.call(message.senderName ?? message.senderId),
                      child: Text(
                        message.senderName ?? message.senderId,
                        style: TextStyle(
                          color: message.senderColor != null
                              ? Color(message.senderColor!)
                              : AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (message.route != null && message.route!.hopCount > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${message.route!.hopCount}h',
                        style: TextStyle(
                          color: AppColors.textTertiary.withValues(alpha: 0.5),
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
                color: message.isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatTime(message.timestamp),
                style: TextStyle(
                  color: message.isMe
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
