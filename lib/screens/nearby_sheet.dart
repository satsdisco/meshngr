import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/chat_provider.dart';
import '../widgets/signal_indicator.dart';

class NearbySheet extends StatefulWidget {
  const NearbySheet({super.key});

  @override
  State<NearbySheet> createState() => _NearbySheetState();
}

class _NearbySheetState extends State<NearbySheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ChatProvider>().refreshNearby());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle + header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.radar, color: AppColors.accent, size: 22),
                        const SizedBox(width: 10),
                        Text('Nearby Nodes', style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        Consumer<ChatProvider>(
                          builder: (_, cp, __) {
                            if (cp.isScanning) {
                              return const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              );
                            }
                            return IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              color: AppColors.textSecondary,
                              onPressed: () => cp.refreshNearby(),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                  ],
                ),
              ),

              // Node list
              Expanded(
                child: Consumer<ChatProvider>(
                  builder: (context, cp, _) {
                    final nodes = cp.nearbyNodes;

                    if (nodes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('No new nodes found', style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text('All nearby nodes are in your contacts', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: nodes.length,
                      itemBuilder: (context, index) {
                        final node = nodes[index];
                        return _NearbyNodeRow(
                          node: node,
                          onAdd: () => _showAddDialog(context, node),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, dynamic node) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Add ${node.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Give this node a friendly name:', style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: node.name,
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final alias = controller.text.trim().isNotEmpty ? controller.text.trim() : null;
              ctx.read<ChatProvider>().addContact(node, alias: alias);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${alias ?? node.name} added to contacts')),
              );
            },
            child: const Text('Add Contact'),
          ),
        ],
      ),
    );
  }
}

class _NearbyNodeRow extends StatelessWidget {
  final dynamic node;
  final VoidCallback onAdd;

  const _NearbyNodeRow({required this.node, required this.onAdd});

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: node.isOnline
                  ? Border.all(color: AppColors.online.withValues(alpha: 0.4), width: 1.5)
                  : null,
            ),
            child: const Icon(Icons.router_outlined, color: AppColors.textTertiary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Row(
                  children: [
                    SignalIndicator(strength: node.signalStrength, size: 12),
                    const SizedBox(width: 8),
                    Text(
                      '${node.hopCount} hop${node.hopCount != 1 ? 's' : ''} · ${_formatLastSeen(node.lastSeen)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
