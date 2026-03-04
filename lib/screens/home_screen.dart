import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meshngr'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_searching, color: AppTheme.meshBlue),
            onPressed: () {
              // TODO: BLE scan/connect
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            onPressed: () {
              // TODO: Settings
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Channels',
          ),
          NavigationDestination(
            icon: Icon(Icons.cell_tower_outlined),
            selectedIcon: Icon(Icons.cell_tower),
            label: 'Nodes',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildChatsTab();
      case 1:
        return _buildChannelsTab();
      case 2:
        return _buildNodesTab();
      default:
        return _buildChatsTab();
    }
  }

  Widget _buildChatsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cell_tower, size: 80, color: AppTheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          const Text(
            'No radio connected',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect to a MeshCore radio via Bluetooth\nto start messaging off-grid',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              // TODO: BLE scan
            },
            icon: const Icon(Icons.bluetooth),
            label: const Text('Scan for Radios'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsTab() {
    return const Center(
      child: Text(
        'Public channels will appear here',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildNodesTab() {
    return const Center(
      child: Text(
        'Nearby mesh nodes will appear here',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}
