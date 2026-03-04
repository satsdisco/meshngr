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
        final allContacts = _filterContacts(cp.savedContacts);
        final favorites = allContacts.where((c) => c.trustLevel == TrustLevel.favorite).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        final online = allContacts.where((c) => c.isOnline && c.trustLevel != TrustLevel.favorite).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        final offline = allContacts.where((c) => !c.isOnline && c.trustLevel != TrustLevel.favorite).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

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
                    hintText: 'Search contacts...',
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
                    '${cp.savedContacts.length} contacts',
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
              child: cp.savedContacts.isEmpty
                  ? _EmptyState()
                  : allContacts.isEmpty
                      ? _NoResults(query: _searchQuery)
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 80),
                          children: [
                            if (favorites.isNotEmpty) ...[
                              _SectionHeader(title: 'FAVORITES', count: favorites.length, icon: Icons.star_rounded, iconColor: AppColors.warning),
                              ...favorites.map((c) => _SwipeableContactRow(contact: c)),
                            ],
                            if (online.isNotEmpty) ...[
                              _SectionHeader(title: 'ONLINE', count: online.length, icon: Icons.circle, iconColor: AppColors.online, iconSize: 8),
                              ...online.map((c) => _SwipeableContactRow(contact: c)),
                            ],
                            if (offline.isNotEmpty) ...[
                              _SectionHeader(title: 'OFFLINE', count: offline.length),
                              ...offline.map((c) => _SwipeableContactRow(contact: c)),
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
              'Tap the + button to scan for\nnearby mesh nodes and add them\nas contacts',
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
  const _SwipeableContactRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(contact.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: AppColors.warning.withValues(alpha: 0.2),
        child: Row(
          children: [
            Icon(
              contact.trustLevel == TrustLevel.favorite ? Icons.star_outline : Icons.star_rounded,
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              contact.trustLevel == TrustLevel.favorite ? 'Unfavorite' : 'Favorite',
              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
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
          // Favorite toggle — don't actually dismiss
          context.read<ChatProvider>().toggleFavorite(contact.id);
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
