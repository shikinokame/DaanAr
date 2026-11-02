import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import 'archival.dart';

/// Featured landmark rendered as a mounted archival print
/// (ivory mat, engraved hairline, catalogue stamp, folio caption).
class FeaturedLandmarkCard extends StatelessWidget {
  final Landmark landmark;
  final double width;

  const FeaturedLandmarkCard({
    super.key,
    required this.landmark,
    this.width = 262,
  });

  String get _stampLabel {
    final era = landmark.era?.trim();
    if (era != null && era.isNotEmpty) return era;
    return landmark.category;
  }

  String get _location {
    final town = landmark.municipality?.name;
    final province = landmark.municipality?.province ?? 'Pangasinan';
    return town == null ? province : '$town, $province';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Semantics(
        button: true,
        label: '${landmark.name}, $_location',
        child: Material(
          color: AppColors.surface,
          child: InkWell(
            onTap: () => context.push('/landmarks/${landmark.id}'),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.rule),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A3B1F).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mounted print
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ArchivalPhoto(
                            url: landmark.media.heroImage,
                            placeholderIcon: categoryIcon(landmark.category),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: ArchivalStamp(_stampLabel),
                          ),
                          if (landmark.isArReady)
                            const Positioned(
                              top: 8,
                              right: 8,
                              child: ArchivalStamp(
                                '3D · AR',
                                icon: Icons.view_in_ar_outlined,
                                background: AppColors.surface,
                                foreground: AppColors.ink,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Caption
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FolioLabel(landmark.id),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 50,
                          child: Text(
                            landmark.name,
                            style: AppText.cardTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 13, color: AppColors.brassInk),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _location.toUpperCase(),
                                style: AppText.meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
