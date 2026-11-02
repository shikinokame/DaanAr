import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Shown at the top of any screen when data is being served from local cache
/// (i.e. the server is unreachable). Tapping it can trigger a refresh.
class OfflineBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          border: Border.all(color: AppColors.rule),
        ),
        child: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppColors.brassInk, size: 15),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Archival Offline Mode viewing locally preserved records',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  color: AppColors.charcoal,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRetry != null)
              InkWell(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.rule),
                  ),
                  child: const Text(
                    'SYNC',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      color: AppColors.ink,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen error widget for when there's no network AND no cached data.
class NoConnectionScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const NoConnectionScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: AppColors.brassInk,
            ),
            const SizedBox(height: 18),
            Text(
              'Archive Unreachable',
              style: AppText.sectionTitle.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 10),
            const Text(
              'The remote repository could not be reached and no local folio cache is available yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('RETRY ARCHIVE'),
            ),
          ],
        ),
      ),
    );
  }
}
