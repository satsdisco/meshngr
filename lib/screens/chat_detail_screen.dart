import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/signal_indicator.dart';
import '../widgets/route_mode_picker.dart';
import '../models/broadcast.dart';

class ChatDetailScreen extends StatefulWidget {
  final Contact contact;

  const ChatDetailScreen({super.key, required this.contact});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  RouteMode _routeMode = RouteMode.auto;
  bool _showRoutePicker = false;

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatProvider>().sendMessage(widget.contact.id, text);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ContactAvatar(contact: widget.contact, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact.displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      SignalIndicator(strength: widget.contact.signalStrength, size: 10),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.contact.hopCount} hop${widget.contact.hopCount != 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: widget.contact.isOnline ? AppColors.success : AppColors.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Offline banner
          if (!widget.contact.isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.warning.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 14, color: AppColors.warning.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.contact.displayName} is offline — messages will be queued',
                    style: TextStyle(color: AppColors.warning.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
          // Messages
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final messages = chatProvider.getMessages(widget.contact.id);
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Start a conversation',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => MessageBubble(
                    message: messages[index],
                    onRetry: messages[index].status == DeliveryStatus.failed
                        ? () => context.read<ChatProvider>().retryMessage(
                              widget.contact.id, messages[index].id)
                        : null,
                  ),
                );
              },
            ),
          ),
          // Route mode picker (expandable)
          if (_showRoutePicker)
            RouteModePicker(
              selected: _routeMode,
              onChanged: (mode) => setState(() {
                _routeMode = mode;
                _showRoutePicker = false;
              }),
            ),
          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 6,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: _showRoutePicker ? null : const Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                // Route mode toggle
                GestureDetector(
                  onTap: () => setState(() => _showRoutePicker = !_showRoutePicker),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _showRoutePicker
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _routeMode.icon,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
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
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: AppColors.textTertiary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
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
}
