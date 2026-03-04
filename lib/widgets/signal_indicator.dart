import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SignalIndicator extends StatelessWidget {
  final int strength; // 0-4
  final double size;

  const SignalIndicator({super.key, required this.strength, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final isActive = i < strength;
        final barHeight = (i + 1) * (size / 4);
        return Container(
          margin: const EdgeInsets.only(right: 1.5),
          width: 3,
          height: barHeight,
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : AppColors.textTertiary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
