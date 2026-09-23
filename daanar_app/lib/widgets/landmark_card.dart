import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import 'category_badge.dart';

/// List/grid card used in the Trails (explore) screen.
class LandmarkCard extends StatelessWidget {
  final Landmark landmark;

  const LandmarkCard({super.key, required this.landmark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/landmarks/${landmark.id}'),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                children: [
                  _buildImage(),
                  if (landmark.isFeatured)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 11),
                            SizedBox(width: 3),
                            Text('Featured', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CategoryBadge(category: landmark.category, small: true),
                      if (landmark.era != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            landmark.era!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    landmark.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          landmark.municipality?.name ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Description omitted from grid cards to prevent overflow.
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = landmark.media.heroImage;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, _1) => _placeholder(),
        errorWidget: (_, _1, _2) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final color = AppColors.categoryColors[landmark.category] ?? AppColors.primary;
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.55)],
        ),
      ),
      child: Center(
        child: Icon(
          _categoryIcon(landmark.category),
          color: Colors.white.withValues(alpha: 0.5),
          size: 48,
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) => switch (cat) {
    'church'    => Icons.church,
    'park'      => Icons.park,
    'historical'=> Icons.account_balance,
    'natural'   => Icons.landscape,
    'cultural'  => Icons.museum,
    _           => Icons.place,
  };
}
