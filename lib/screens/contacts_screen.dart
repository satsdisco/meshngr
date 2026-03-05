import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/contact.dart';
import '../providers/chat_provider.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/signal_indicator.dart';
import 'chat_detail_screen.dart';
import 'contact_detail_sheet.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _searchQuery = '';
  bool _isSearching = false;

  List<Contact> _filterContacts(List<Contact> contacts) {
    if (_searchQuery.isEmpty) return contacts;
    final q = _searchQuery.toLowerCase();
    return contacts.where((c) =>
      c.displayName.toLowerCase().contains(q) ||
      c.name.toLowerCase().contains(q) ||
      c.address.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, cp, _) {
        final myFiltered = _filterContacts(cp.myContacts);
        final knownFiltered = _filterContacts(cp.knownNodes);
        final favorites = myFiltered.where((c) => c.trustLevel == TrustLevel.favorite).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        final myOnline = myFiltered.where((c) => c.isOnline && c.trustLevel != TrustLevel.favorite).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        final myOffline = myFiltered.where((c) => !c.isOnline && c.trustLevel != TrustLevel.favorite).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        final knownOnline = knownFiltered.where((c) => c.isOnline).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        final knownOffline = knownFiltered.where((c) => !c.isOnline).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

        final hasMyContacts = favorites.isNotEmpty || myOnline.isNotEmpty || myOffline.isNotEmpty;
        final hasKnownNodes = knownOnline.isNotEmpty || knownOffline.isNotEmpty;

        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    _isSearching = v.isNotEmpty;
                  }),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search contacts & nodes...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppColors.textTertiary),
                            onPressed: () => setState(() {
                              _searchQuery = '';
                              _isSearching = false;
                            }),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // Contact count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${cp.myContacts.length} saved · ${cp.knownNodes.length} known',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${cp.onlineContacts.length} online',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.online),
                  ),
                ],
              ),
            ),

            // Contact list
            Expanded(
              child: !hasMyContacts && !hasKnownNodes
                  ? _EmptyState()
                  : _isSearching && !hasMyContacts && !hasKnownNodes
                      ? _NoResults(query: _searchQuery)
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 80),
                          children: [
                            // MY CONTACTS section — show prompt when empty
                            if (myFiltered.isEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.people_outline, size: 40, color: AppColors.textTertiary),
                                      const SizedBox(height: 8),
                                      const Text('No contacts yet', style: TextStyle(fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Meet people in channels, scan their QR code, or tap a node below to save them.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (favorites.isNotEmpty) ...[
                              _SectionHeader(title: 'FAVORITES', count: favorites.length, icon: Icons.star_rounded, iconColor: AppColors.warning),
                              ...favorites.map((c) => _SwipeableContactRow(contact: c)),
                            ],
                            if (myOnline.isNotEmpty) ...[
                              _SectionHeader(title: 'MY CONTACTS · ONLINE', count: myOnline.length, icon: Icons.circle, iconColor: AppColors.online, iconSize: 8),
                              ...myOnline.map((c) => _SwipeableContactRow(contact: c)),
                            ],
                            if (myOffline.isNotEmpty) ...[
                              _SectionHeader(title: 'MY CONTACTS · OFFLINE', count: myOffline.length),
                              ...myOffline.map((c) => _SwipeableContactRow(contact: c)),
                            ],

                            // KNOWN NODES — collapsed by default
                            if (hasKnownNodes) ...[
                              const SizedBox(height: 8),
                              _CollapsibleNodesSection(
                                totalCount: knownFiltered.length,
                                repeaterCount: knownFiltered.where((c) => c.advType >= 2).length,
                                personCount: knownFiltered.where((c) => c.advType <= 1).length,
                                onlineNodes: knownOnline,
                                offlineNodes: knownOffline,
                                onClear: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Clear Known Nodes?'),
                                      content: const Text('Removes all known nodes. They\'ll repopulate as your radio hears them again.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && context.mounted) {
                                    context.read<ChatProvider>().clearKnownNodes();
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, size: 40, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),
            Text(
              'No contacts yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your radio to sync contacts.\nNearby nodes will appear when your\nradio discovers them.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary, height: 1.5),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Make sure your radio is connected first',
                    style: TextStyle(color: AppColors.accent, fontSize: 13),
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

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text('No contacts matching "$query"', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.icon,
    this.iconColor,
    this.iconSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: iconColor ?? AppColors.textTertiary),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _SwipeableContactRow extends StatelessWidget {
  final Contact contact;
  final bool isKnownNode;
  const _SwipeableContactRow({required this.contact, this.isKnownNode = false});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(contact.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: isKnownNode
            ? AppColors.accent.withValues(alpha: 0.2)
            : AppColors.warning.withValues(alpha: 0.2),
        child: Row(
          children: [
            Icon(
              isKnownNode
                  ? Icons.person_add_alt_1
                  : (contact.trustLevel == TrustLevel.favorite ? Icons.star_outline : Icons.star_rounded),
              color: isKnownNode ? AppColors.accent : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              isKnownNode
                  ? 'Save Contact'
                  : (contact.trustLevel == TrustLevel.favorite ? 'Unfavorite' : 'Favorite'),
              style: TextStyle(
                color: isKnownNode ? AppColors.accent : AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withValues(alpha: 0.2),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Remove', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Icon(Icons.person_remove_outlined, color: AppColors.error),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (isKnownNode) {
            // Save as contact
            context.read<ChatProvider>().addContact(contact);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${contact.displayName} saved to contacts')),
            );
          } else {
            // Favorite toggle
            context.read<ChatProvider>().toggleFavorite(contact.id);
          }
          return false;
        } else {
          // Remove — confirm first
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('Remove ${contact.displayName}?'),
              content: Text(
                'This will remove them from your contacts. You can add them back from Nearby nodes.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ) ?? false;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          context.read<ChatProvider>().removeContact(contact.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${contact.displayName} removed'),
              action: SnackBarAction(label: 'Undo', onPressed: () {
                // TODO: undo support
              }),
            ),
          );
        }
      },
      child: _ContactRow(contact: contact),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  const _ContactRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(contact: contact)));
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => ContactDetailSheet(contact: contact),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ContactAvatar(contact: contact, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (contact.alias != null) ...[
                        Text(
                          contact.name,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        const _Dot(),
                      ],
                      Text(
                        contact.isOnline
                            ? '${contact.hopCount} hop${contact.hopCount != 1 ? 's' : ''} away'
                            : _formatLastSeen(contact.lastSeen),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (contact.isOnline)
              SignalIndicator(strength: contact.signalStrength, size: 14),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return 'over a week ago';
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
    );
  }
}

class _CollapsibleNodesSection extends StatefulWidget {
  final int totalCount;
  final int repeaterCount;
  final int personCount;
  final List<Contact> onlineNodes;
  final List<Contact> offlineNodes;
  final VoidCallback onClear;

  const _CollapsibleNodesSection({
    required this.totalCount,
    required this.repeaterCount,
    required this.personCount,
    required this.onlineNodes,
    required this.offlineNodes,
    required this.onClear,
  });

  @override
  State<_CollapsibleNodesSection> createState() => _CollapsibleNodesSectionState();
}

class _CollapsibleNodesSectionState extends State<_CollapsibleNodesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Collapsed summary bar
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.cell_tower, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.totalCount} nodes on your radio',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.repeaterCount > 0
                              ? '${widget.personCount} 👤 people · ${widget.repeaterCount} 📡 repeaters'
                              : 'Nodes your radio has heard on the mesh',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expanded list
        if (_expanded) ...[
          if (widget.onlineNodes.isNotEmpty) ...[
            _SectionHeader(title: 'ONLINE', count: widget.onlineNodes.length, icon: Icons.circle, iconColor: AppColors.online, iconSize: 8),
            ...widget.onlineNodes.map((c) => _NodeRow(contact: c)),
          ],
          ...widget.offlineNodes.map((c) => _NodeRow(contact: c)),
        ],
      ],
    );
  }
}

class _NodeRow extends StatelessWidget {
  final Contact contact;
  const _NodeRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    final isRepeater = contact.advType >= 2;
    return ListTile(
      dense: true,
      leading: Stack(
        children: [
          ContactAvatar(contact: contact, size: 36, showOnlineIndicator: false),
          if (isRepeater)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: const Text('📡', style: TextStyle(fontSize: 10)),
              ),
            ),
        ],
      ),
      title: Text(contact.name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        isRepeater ? 'Repeater' : contact.lastSeenText,
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
      onTap: () {
        // Show contact detail or save option
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => _NodeDetailSheet(contact: contact),
        );
      },
    );
  }
}

class _NodeDetailSheet extends StatelessWidget {
  final Contact contact;
  const _NodeDetailSheet({required this.contact});

  @override
  Widget build(BuildContext context) {
    final isRepeater = contact.advType >= 2;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              ContactAvatar(contact: contact, size: 64, showOnlineIndicator: false),
              if (isRepeater)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: const Text('📡', style: TextStyle(fontSize: 14)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(contact.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            isRepeater ? 'Repeater / Infrastructure' : 'Companion Radio · ${contact.lastSeenText}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.icon(
                onPressed: () {
                  final saved = contact.copyWith(trustLevel: TrustLevel.saved);
                  context.read<ChatProvider>().addContact(saved, alias: contact.name);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${contact.name} saved to contacts')),
                  );
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Save Contact'),
              ),
              if (!isRepeater)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to DM — for now just save and show message
                    final saved = contact.copyWith(trustLevel: TrustLevel.saved);
                    context.read<ChatProvider>().addContact(saved, alias: contact.name);
                    Navigator.pushNamed(context, '/chat', arguments: saved);
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Send DM'),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
