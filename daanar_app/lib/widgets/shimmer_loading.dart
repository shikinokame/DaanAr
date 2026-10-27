import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';

class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const ShimmerCard({
    super.key,
    this.height = 200,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.divider,
      highlightColor: AppColors.background,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: borderRadius ?? BorderRadius.circular(2),
          border: Border.all(color: AppColors.rule, width: 0.8),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: ShimmerCard(height: 130, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}
