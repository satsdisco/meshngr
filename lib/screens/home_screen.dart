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
        onPressed: _showNearbySheet,
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
