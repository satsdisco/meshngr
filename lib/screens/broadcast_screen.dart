import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/broadcast.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  AdvertType _selectedAdvert = AdvertType.local;
  bool _privacyMode = false;
  bool _isBroadcasting = false;

  void _sendAdvert() async {
    setState(() => _isBroadcasting = true);
    // TODO: actual BLE call — connector.sendSelfAdvert(flood: _selectedAdvert == AdvertType.flood)
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isBroadcasting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You\'re now visible on the mesh ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero explainer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cell_tower, color: AppColors.accent, size: 24),
                    const SizedBox(width: 10),
                    Text('Make Yourself Visible', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Broadcasting tells other mesh users you\'re here. They\'ll see your name and can message you. You control who sees you and how far your signal reaches.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Reach picker
          Text('REACH', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 8),
          _ReachOption(
            type: AdvertType.local,
            isSelected: _selectedAdvert == AdvertType.local,
            onTap: () => setState(() => _selectedAdvert = AdvertType.local),
          ),
          const SizedBox(height: 8),
          _ReachOption(
            type: AdvertType.flood,
            isSelected: _selectedAdvert == AdvertType.flood,
            onTap: () => setState(() => _selectedAdvert = AdvertType.flood),
          ),

          const SizedBox(height: 24),

          // Privacy toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _privacyMode
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _privacyMode ? Icons.visibility_off : Icons.visibility,
                    color: _privacyMode ? AppColors.warning : AppColors.textTertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Privacy Mode', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        _privacyMode
                            ? 'Your name and location are hidden'
                            : 'Your name is visible to others',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _privacyMode,
                  onChanged: (v) => setState(() => _privacyMode = v),
                  activeColor: AppColors.warning,
                ),
              ],
            ),
          ),

          if (_privacyMode) ...[
            const SizedBox(height: 8),
            _InfoBubble(
              icon: Icons.info_outline,
              text: 'Others will see your node address but not your name or location. You can still send and receive messages.',
              color: AppColors.warning,
            ),
          ],

          const SizedBox(height: 32),

          // Broadcast button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _isBroadcasting ? null : _sendAdvert,
              icon: _isBroadcasting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cell_tower),
              label: Text(
                _isBroadcasting ? 'Broadcasting...' : 'Broadcast Now',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // What happens next
          _InfoBubble(
            icon: Icons.lightbulb_outline,
            text: _selectedAdvert == AdvertType.local
                ? 'Nearby nodes will see you immediately. New contacts may appear in your Nearby list within seconds.'
                : 'Your broadcast will travel through repeaters across the whole network. This may take a few seconds depending on mesh size.',
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _ReachOption extends StatelessWidget {
  final AdvertType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReachOption({required this.type, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLocal = type == AdvertType.local;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.divider,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLocal ? Icons.bluetooth : Icons.cell_tower,
                color: isSelected ? AppColors.accent : AppColors.textTertiary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected ? AppColors.textSecondary : AppColors.textTertiary,
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.textTertiary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBubble extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBubble({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
