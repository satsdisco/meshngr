import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/chat_provider.dart';
import '../core/ble_service.dart';
import '../widgets/connection_status.dart';
import 'chats_screen.dart';
import 'channels_screen.dart';
import 'contacts_screen.dart';
import 'settings_screen.dart';
import 'nearby_sheet.dart';
import 'add_channel_screen.dart';
import 'share_contact_screen.dart';
import 'add_contact_screen.dart';
import 'qr_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddContactOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
              title: const Text('Scan QR Code'),
              subtitle: const Text('Scan someone\'s QR code nearby'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.key, color: AppColors.accent),
              title: const Text('Paste Public Key'),
              subtitle: const Text('Add someone far away by their key'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContactScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.radar, color: AppColors.accent),
              title: const Text('Scan Nearby'),
              subtitle: const Text('Find nodes broadcasting right now'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _showNearbySheet();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showNearbySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NearbySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('meshngr'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Consumer<BleService>(
            builder: (context, ble, _) => Center(
              child: ConnectionStatusDot(state: ble.state, size: 10),
            ),
          ),
        ),
        leadingWidth: 32,
        actions: [
          IconButton(
            icon: const Icon(Icons.radar, size: 22),
            tooltip: 'Nearby nodes',
            onPressed: _showNearbySheet,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code, size: 22),
            tooltip: 'My QR Code',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShareContactScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            _buildTab('Messages', context),
            _buildTab('Channels', context),
            _buildTab('Contacts', context),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ChatsScreen(),
          ChannelsScreen(),
          ContactsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 1) {
            // Channels tab → Add Channel
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AddChannelScreen()));
          } else if (_tabController.index == 2) {
            // Contacts tab → Add contact options
            _showAddContactOptions();
          } else {
            // Messages → Nearby sheet
            _showNearbySheet();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTab(String label, BuildContext context) {
    // Show unread badge on Messages tab
    if (label == 'Messages') {
      return Consumer<ChatProvider>(
        builder: (context, cp, _) {
          final totalUnread = cp.activeConversations.fold<int>(
            0, (sum, c) => sum + cp.getUnreadCount(c.id),
          );
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (totalUnread > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      totalUnread.toString(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }
    if (label == 'Channels') {
      return Consumer<ChatProvider>(
        builder: (context, cp, _) {
          final totalUnread = cp.joinedChannels.fold<int>(0, (sum, c) => sum + c.unreadCount);
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (totalUnread > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      totalUnread.toString(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }
    return Tab(text: label);
  }
}
