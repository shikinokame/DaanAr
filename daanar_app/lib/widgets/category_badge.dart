import 'package:flutter/material.dart';
import '../core/theme.dart';

class CategoryBadge extends StatelessWidget {
  final String category;
  final bool small;

  const CategoryBadge({super.key, required this.category, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColors[category] ?? AppColors.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        category[0].toUpperCase() + category.substring(1),
        style: TextStyle(
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
