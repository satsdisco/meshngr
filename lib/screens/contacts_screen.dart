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
                            // MY CONTACTS section
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

                            // KNOWN NODES section (from radio)
                            if (hasKnownNodes) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 14, color: AppColors.accent.withValues(alpha: 0.7)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Nodes from your radio. Tap to save as a contact.',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.accent.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (knownOnline.isNotEmpty) ...[
                              _SectionHeader(title: 'KNOWN NODES · ONLINE', count: knownOnline.length, icon: Icons.circle, iconColor: AppColors.online, iconSize: 8),
                              ...knownOnline.map((c) => _SwipeableContactRow(contact: c, isKnownNode: true)),
                            ],
                            if (knownOffline.isNotEmpty) ...[
                              _SectionHeader(title: 'KNOWN NODES', count: knownOffline.length),
                              ...knownOffline.map((c) => _SwipeableContactRow(contact: c, isKnownNode: true)),
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
