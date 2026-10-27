import 'package:flutter/material.dart';
import '../core/theme.dart';

class CategoryBadge extends StatelessWidget {
  final String category;
  final bool small;

  const CategoryBadge({super.key, required this.category, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColors[category] ?? AppColors.ink;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 9,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: AppColors.surface.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: small ? 9.0 : 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.surface,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
