import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/contact.dart';
import '../providers/chat_provider.dart';
import '../widgets/signal_indicator.dart';
import 'chat_detail_screen.dart';
import 'contact_detail_sheet.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, cp, _) {
        final favorites = cp.favoriteContacts;
        final online = cp.onlineContacts.where((c) => c.trustLevel != TrustLevel.favorite).toList();
        final offline = cp.offlineContacts.where((c) => c.trustLevel != TrustLevel.favorite).toList();

        if (cp.savedContacts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: Icon(Icons.people_outline, size: 36, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 20),
                  Text('No contacts yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the radar icon to find\nnearby mesh nodes',
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
            // Favorites
            if (favorites.isNotEmpty) ...[
              _SectionHeader(title: 'FAVORITES', count: favorites.length),
              ...favorites.map((c) => _ContactRow(contact: c)),
            ],
            // Online
            if (online.isNotEmpty) ...[
              _SectionHeader(title: 'ONLINE', count: online.length),
              ...online.map((c) => _ContactRow(contact: c)),
            ],
            // Offline
            if (offline.isNotEmpty) ...[
              _SectionHeader(title: 'OFFLINE', count: offline.length),
              ...offline.map((c) => _ContactRow(contact: c)),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
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

class _ContactRow extends StatelessWidget {
  final Contact contact;
  const _ContactRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatDetailScreen(contact: contact)),
        );
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => ContactDetailSheet(contact: contact),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      contact.initials,
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
                if (contact.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (contact.trustLevel == TrustLevel.favorite)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.star, size: 14, color: AppColors.warning),
                        ),
                      Expanded(
                        child: Text(
                          contact.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (contact.alias != null) ...[
                        Text(contact.name, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.textTertiary, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        contact.isOnline
                            ? '${contact.hopCount} hop${contact.hopCount != 1 ? 's' : ''}'
                            : 'Last seen ${_formatLastSeen(contact.lastSeen)}',
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
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
