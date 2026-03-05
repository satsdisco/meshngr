import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/signal_indicator.dart';
import '../widgets/route_mode_picker.dart';
import '../widgets/date_header.dart';
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
  bool _showScrollToBottom = false;

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

  void _showMessageContextMenu(BuildContext context, Message message) {
    final chatProvider = context.read<ChatProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageContextMenu(
        message: message,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: message.text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        },
        onDelete: message.isMe
            ? () {
                chatProvider.deleteMessage(widget.contact.id, message.id);
              }
            : null,
        onInfo: () => _showMessageInfo(context, message),
      ),
    );
  }

  void _showMessageInfo(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MessageInfoSheet(message: message),
    );
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
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      SignalIndicator(
                          strength: widget.contact.signalStrength, size: 10),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.contact.hopCount} hop${widget.contact.hopCount != 1 ? 's' : ''}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: widget.contact.isOnline
                              ? AppColors.success
                              : AppColors.textTertiary,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.warning.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.cloud_off,
                      size: 14,
                      color: AppColors.warning.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.contact.displayName} is offline — messages will be queued',
                    style: TextStyle(
                        color: AppColors.warning.withValues(alpha: 0.8),
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          // Messages
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final messages =
                    chatProvider.getMessages(widget.contact.id);
                final typing = chatProvider.isTyping(widget.contact.id);

                if (messages.isEmpty) {
                  return _EmptyConversation(contact: widget.contact);
                }
                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length + (typing ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Typing indicator at the end
                        if (typing && index == messages.length) {
                          return const _TypingIndicatorBubble();
                        }

                        final msg = messages[index];
                        final prevMsg = index > 0 ? messages[index - 1] : null;

                        final showDate = prevMsg == null ||
                            msg.timestamp.day != prevMsg.timestamp.day ||
                            msg.timestamp.month != prevMsg.timestamp.month;

                        final isGrouped = prevMsg != null &&
                            prevMsg.isMe == msg.isMe &&
                            msg.timestamp
                                    .difference(prevMsg.timestamp)
                                    .inMinutes <
                                2;

                        return Column(
                          children: [
                            if (showDate) DateHeader(date: msg.timestamp),
                            Padding(
                              padding:
                                  EdgeInsets.only(top: isGrouped ? 0 : 4),
                              child: MessageBubble(
                                message: msg,
                                onRetry: msg.status == DeliveryStatus.failed
                                    ? () =>
                                        context.read<ChatProvider>().retryMessage(
                                            widget.contact.id, msg.id)
                                    : null,
                                onLongPress: () =>
                                    _showMessageContextMenu(context, msg),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    // Scroll to bottom FAB
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
                          child: const Icon(Icons.keyboard_arrow_down,
                              color: AppColors.textSecondary),
                        ),
                      ),
                  ],
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
              border: _showRoutePicker
                  ? null
                  : const Border(
                      top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                // Route mode toggle
                GestureDetector(
                  onTap: () =>
                      setState(() => _showRoutePicker = !_showRoutePicker),
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
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: AppColors.textTertiary),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10),
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyConversation extends StatelessWidget {
  final Contact contact;
  const _EmptyConversation({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.textTertiary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Messages are sent directly over the mesh',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator bubble ───────────────────────────────────────────────────

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 48, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const _BouncingDots(),
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value - i * 0.22) % 1.0;
            final bounce =
                phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0;
            final yOffset = -bounce * 5.0;
            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary
                      .withValues(alpha: 0.5 + bounce * 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Context menu ──────────────────────────────────────────────────────────────

class _MessageContextMenu extends StatelessWidget {
  final Message message;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;
  final VoidCallback onInfo;

  const _MessageContextMenu({
    required this.message,
    required this.onCopy,
    this.onDelete,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // Message preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              message.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          const Divider(height: 1),
          _MenuOption(
            icon: Icons.copy_outlined,
            label: 'Copy',
            onTap: () {
              Navigator.pop(context);
              onCopy();
            },
          ),
          _MenuOption(
            icon: Icons.info_outline_rounded,
            label: 'Message info',
            onTap: () {
              Navigator.pop(context);
              onInfo();
            },
          ),
          if (onDelete != null) ...[
            const Divider(height: 1),
            _MenuOption(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                onDelete!();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: c,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message info sheet ────────────────────────────────────────────────────────

class _MessageInfoSheet extends StatelessWidget {
  final Message message;
  const _MessageInfoSheet({required this.message});

  String _formatFullTime(DateTime t) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '${months[t.month - 1]} ${t.day}, ${t.year}  $h:$m';
  }

  String _statusLabel(DeliveryStatus s) {
    switch (s) {
      case DeliveryStatus.pending:
        return 'Queued — waiting to be sent';
      case DeliveryStatus.sent:
        return 'Sent — waiting for confirmation';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.read:
        return 'Read';
      case DeliveryStatus.failed:
        return 'Failed to deliver';
    }
  }

  Color _statusColor(DeliveryStatus s) {
    switch (s) {
      case DeliveryStatus.delivered:
      case DeliveryStatus.read:
        return AppColors.success;
      case DeliveryStatus.failed:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = message.route;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Message info',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),

          // Timestamp
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Sent at',
            value: _formatFullTime(message.timestamp),
          ),
          const SizedBox(height: 12),

          // Delivery status
          if (message.isMe) ...[
            _InfoRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Status',
              value: _statusLabel(message.status),
              valueColor: _statusColor(message.status),
            ),
            const SizedBox(height: 12),
          ],

          // Route / hops
          if (route != null) ...[
            _InfoRow(
              icon: Icons.route_rounded,
              label: route.hopCount == 1
                  ? '1 hop (direct)'
                  : '${route.hopCount} hops',
              value: route.path.isNotEmpty
                  ? route.path.join(' → ')
                  : 'Path not recorded',
            ),
            const SizedBox(height: 12),
            if (route.rssi != null) ...[
              _InfoRow(
                icon: Icons.signal_cellular_alt_rounded,
                label: 'Signal strength',
                value: '${route.rssi} dBm',
              ),
              const SizedBox(height: 12),
            ],
          ],

          // Retry count
          if (message.retryCount > 0) ...[
            _InfoRow(
              icon: Icons.refresh_rounded,
              label: 'Retried',
              value:
                  '${message.retryCount} time${message.retryCount != 1 ? 's' : ''}',
            ),
            const SizedBox(height: 12),
          ],

          // Fail reason
          if (message.failReason != null) ...[
            _InfoRow(
              icon: Icons.error_outline_rounded,
              label: 'Failure reason',
              value: message.failReason!,
              valueColor: AppColors.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
