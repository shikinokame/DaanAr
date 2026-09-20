import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import 'category_badge.dart';

/// Horizontal card used in the Featured section on the Home screen.
class FeaturedLandmarkCard extends StatelessWidget {
  final Landmark landmark;

  const FeaturedLandmarkCard({super.key, required this.landmark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/landmarks/${landmark.id}'),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Hero image or gradient placeholder
              _buildImage(),

              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Content overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CategoryBadge(category: landmark.category, small: true),
                      const SizedBox(height: 6),
                      Text(
                        landmark.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.secondary, size: 12),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              landmark.municipality?.name ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Featured star
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = landmark.media.heroImage;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        height: 200,
        width: 220,
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
      height: 200,
      width: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.6)],
        ),
      ),
      child: Icon(
        _categoryIcon(landmark.category),
        color: Colors.white.withValues(alpha: 0.4),
        size: 64,
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    return switch (cat) {
      'church'    => Icons.church,
      'park'      => Icons.park,
      'historical'=> Icons.account_balance,
      'natural'   => Icons.landscape,
      'cultural'  => Icons.museum,
      _           => Icons.place,
    };
  }
}
