import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import 'archival.dart';

/// Mounted archival card used in the Explore / Trails 2-column grid.
class LandmarkCard extends StatelessWidget {
  final Landmark landmark;

  const LandmarkCard({super.key, required this.landmark});

  String get _stampLabel {
    final era = landmark.era?.trim();
    if (era != null && era.isNotEmpty) return era;
    return landmark.category;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => context.push('/landmarks/${landmark.id}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.rule),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A3B1F).withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mounted archival photograph
              SizedBox(
                height: 118,
                width: double.infinity,
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
                        top: 6,
                        left: 6,
                        child: ArchivalStamp(_stampLabel),
                      ),
                      if (landmark.isArReady)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: ArchivalStamp(
                            '3D',
                            icon: Icons.view_in_ar_outlined,
                            background: AppColors.surface,
                            foreground: AppColors.ink,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Archival folio caption
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FolioLabel(landmark.id),
                      const SizedBox(height: 3),
                      Expanded(
                        child: Text(
                          landmark.name,
                          style: AppText.cardTitle.copyWith(fontSize: 17.5, height: 1.15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: AppColors.brassInk,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              (landmark.municipality?.name ?? 'Pangasinan').toUpperCase(),
                              style: AppText.meta.copyWith(fontSize: 9.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
