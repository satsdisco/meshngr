import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/contact.dart';

/// Generates a consistent color from a string (name/address)
Color _avatarColor(String seed) {
  final colors = [
    const Color(0xFF4A9EFF), // blue
    const Color(0xFF8B5CF6), // purple
    const Color(0xFFEC4899), // pink
    const Color(0xFFF97316), // orange
    const Color(0xFF10B981), // emerald
    const Color(0xFF06B6D4), // cyan
    const Color(0xFFF59E0B), // amber
    const Color(0xFFEF4444), // red
    const Color(0xFF6366F1), // indigo
    const Color(0xFF14B8A6), // teal
  ];
  int hash = 0;
  for (var char in seed.codeUnits) {
    hash = (hash * 31 + char) & 0x7FFFFFFF;
  }
  return colors[hash % colors.length];
}

class ContactAvatar extends StatelessWidget {
  final Contact contact;
  final double size;
  final bool showOnlineIndicator;

  const ContactAvatar({
    super.key,
    required this.contact,
    this.size = 48,
    this.showOnlineIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(contact.address);
    final indicatorSize = size * 0.27;
    final borderWidth = size * 0.04;

    return SizedBox(
      width: size + (showOnlineIndicator ? 2 : 0),
      height: size + (showOnlineIndicator ? 2 : 0),
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.initials,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.35,
                ),
              ),
            ),
          ),
          if (showOnlineIndicator && contact.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: borderWidth),
                ),
              ),
            ),
          if (showOnlineIndicator && contact.trustLevel == TrustLevel.favorite)
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star_rounded, size: indicatorSize * 0.8, color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}
