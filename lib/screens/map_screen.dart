import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/contact.dart';
import '../providers/chat_provider.dart';
import '../core/ble_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  Contact? _selectedNode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Map'),
        actions: [
          Consumer<ChatProvider>(
            builder: (context, cp, _) {
              final nodesWithLocation = _getNodesWithLocation(cp);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    '${nodesWithLocation.length} nodes',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer2<ChatProvider, BleService>(
        builder: (context, cp, ble, _) {
          final nodes = _getNodesWithLocation(cp);
          final selfInfo = ble.selfInfo;

          // Default center: Prague, or self location, or first node
          LatLng center = const LatLng(50.08, 14.43);
          if (selfInfo?.latitude != null && selfInfo!.latitude != 0) {
            center = LatLng(selfInfo.latitude!.toDouble(), selfInfo.longitude!.toDouble());
          } else if (nodes.isNotEmpty) {
            center = LatLng(nodes.first.latitude!, nodes.first.longitude!);
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 11,
                  onTap: (_, __) => setState(() => _selectedNode = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.meshngr.meshngr',
                    tileBuilder: _darkTileBuilder,
                  ),
                  MarkerLayer(
                    markers: [
                      // Self marker
                      if (selfInfo?.latitude != null && selfInfo!.latitude != 0)
                        Marker(
                          point: LatLng(selfInfo.latitude!.toDouble(), selfInfo.longitude!.toDouble()),
                          width: 40,
                          height: 40,
                          child: _SelfMarker(),
                        ),
                      // Node markers
                      ...nodes.map((node) => Marker(
                        point: LatLng(node.latitude!, node.longitude!),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedNode = node),
                          child: _NodeMarker(
                            node: node,
                            isSelected: _selectedNode?.id == node.id,
                          ),
                        ),
                      )),
                    ],
                  ),
                ],
              ),

              // Node info card
              if (_selectedNode != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: _NodeInfoCard(
                    node: _selectedNode!,
                    onClose: () => setState(() => _selectedNode = null),
                  ),
                ),

              // Empty state
              if (nodes.isEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off, size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        const Text('No nodes with GPS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          'Nodes will appear on the map once they broadcast their location. Not all nodes have GPS.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Contact> _getNodesWithLocation(ChatProvider cp) {
    final all = [...cp.myContacts, ...cp.knownNodes];
    return all.where((c) => c.hasLocation).toList();
  }

  // Dark mode tile filter
  Widget _darkTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.8, 0, 0, 0, 180,
        0, -0.8, 0, 0, 180,
        0, 0, -0.8, 0, 180,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }
}

class _SelfMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2),
        ],
      ),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }
}

class _NodeMarker extends StatelessWidget {
  final Contact node;
  final bool isSelected;

  const _NodeMarker({required this.node, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final isRepeater = node.advType >= 2;
    final color = isRepeater ? Colors.orange : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? color : color.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)]
            : null,
      ),
      child: Center(
        child: Text(
          isRepeater ? '📡' : node.name.isNotEmpty ? node.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: isRepeater ? 14 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _NodeInfoCard extends StatelessWidget {
  final Contact node;
  final VoidCallback onClose;

  const _NodeInfoCard({required this.node, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isRepeater = node.advType >= 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isRepeater ? Colors.orange : AppColors.success).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isRepeater ? '📡' : '👤',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  node.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isRepeater ? "Repeater" : "Person"} · ${node.lastSeenText} · ${node.hopCount}h',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                Text(
                  '${node.latitude!.toStringAsFixed(4)}, ${node.longitude!.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
