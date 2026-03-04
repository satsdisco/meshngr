import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/broadcast.dart';

class RouteModePicker extends StatelessWidget {
  final RouteMode selected;
  final ValueChanged<RouteMode> onChanged;

  const RouteModePicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                'Message routing',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showExplainer(context),
                child: Icon(Icons.info_outline, size: 15, color: AppColors.textTertiary.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: RouteMode.values.map((mode) {
              final isSelected = mode == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(right: mode != RouteMode.flood ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.accent.withValues(alpha: 0.4) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          mode.icon,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mode.label,
                          style: TextStyle(
                            color: isSelected ? AppColors.accent : AppColors.textTertiary,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showExplainer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RoutingExplainer(),
    );
  }
}

class _RoutingExplainer extends StatelessWidget {
  const _RoutingExplainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.route, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Text('How Message Routing Works', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Mesh networks send messages through multiple nodes to reach the recipient. You can control how your messages travel:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          ...RouteMode.values.map((mode) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(mode.icon, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.label, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        mode.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: AppColors.accent.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: Smart mode works great for most conversations. Use Broadcast only when you really need to reach someone who might have moved.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.accent.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
