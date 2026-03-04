import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/channel.dart';
import '../models/message.dart';

class ChannelChatScreen extends StatefulWidget {
  final Channel channel;
  const ChannelChatScreen({super.key, required this.channel});

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Mock channel messages with sender names
  late final List<_ChannelMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = _mockMessages();
  }

  List<_ChannelMessage> _mockMessages() {
    return [
      _ChannelMessage(
        id: '1', sender: 'Andy', senderColor: const Color(0xFFF97316),
        text: 'Anyone heading up the north trail today?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        hopCount: 1,
      ),
      _ChannelMessage(
        id: '2', sender: 'BaseStation-01', senderColor: const Color(0xFF10B981),
        text: 'Weather looks clear. Wind picking up after 3pm.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
        hopCount: 2,
      ),
      _ChannelMessage(
        id: '3', sender: 'Sarah', senderColor: const Color(0xFF06B6D4),
        text: 'I\'m near the ridge. Signal is great from here.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        hopCount: 2,
      ),
      _ChannelMessage(
        id: '4', sender: 'You', senderColor: AppColors.accent,
        text: 'Copy that. Heading out in 20.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        isMe: true,
      ),
      _ChannelMessage(
        id: '5', sender: 'HikerNode', senderColor: const Color(0xFF8B5CF6),
        text: 'Anyone near the summit? Could use a relay check.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        hopCount: 4,
      ),
      _ChannelMessage(
        id: '6', sender: 'Andy', senderColor: const Color(0xFFF97316),
        text: 'I can see you from here. 3 bars. Try sending through Repeater-East.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        hopCount: 1,
      ),
    ];
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChannelMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'You',
        senderColor: AppColors.accent,
        text: text,
        timestamp: DateTime.now(),
        isMe: true,
      ));
    });
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
                    '${widget.channel.memberCount} members',
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
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final prevMsg = index > 0 ? _messages[index - 1] : null;
                final showSender = prevMsg == null || prevMsg.sender != msg.sender;

                return _ChannelBubble(
                  message: msg,
                  showSender: showSender,
                  formatTime: _formatTime,
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
                        hintText: 'Message #${widget.channel.name}...',
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
            Text('#${widget.channel.name}', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('${widget.channel.memberCount} members', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Channel messages are broadcast to all members. Anyone on the mesh who has joined this channel will see your messages.',
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

class _ChannelMessage {
  final String id;
  final String sender;
  final Color senderColor;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final int hopCount;

  _ChannelMessage({
    required this.id,
    required this.sender,
    required this.senderColor,
    required this.text,
    required this.timestamp,
    this.isMe = false,
    this.hopCount = 0,
  });
}

class _ChannelBubble extends StatelessWidget {
  final _ChannelMessage message;
  final bool showSender;
  final String Function(DateTime) formatTime;

  const _ChannelBubble({
    required this.message,
    required this.showSender,
    required this.formatTime,
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
            // Sender name (for non-me messages, when it changes)
            if (showSender && !message.isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.sender,
                      style: TextStyle(
                        color: message.senderColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (message.hopCount > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${message.hopCount}h',
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
