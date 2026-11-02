import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Shared building blocks for the DaanAR "archival field guide" look.
///
/// Keep decoration subtle: hairline rules, faint paper grain, restrained
/// sepia. Nothing here should reduce readability or touch-target size.

// Paper

/// Ivory paper background with a very faint, static grain.
/// Place it *behind* scrolling content (it is cached via RepaintBoundary).
class PaperBackground extends StatelessWidget {
  final Widget child;
  final Color color;

  const PaperBackground({
    super.key,
    required this.child,
    this.color = AppColors.background,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _PaperGrainPainter(color)),
          ),
        ),
        child,
      ],
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  final Color base;
  _PaperGrainPainter(this.base);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    // Deterministic speckle so the grain never "shimmers" between frames.
    final rnd = math.Random(1898);
    final dark = Paint()..color = const Color(0xFF6B5A3A).withValues(alpha: 0.05);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.35);
    final count = (size.width * size.height / 260).clamp(0, 9000).toInt();
    for (var i = 0; i < count; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawCircle(p, rnd.nextDouble() * 0.7 + 0.2, i.isEven ? dark : light);
    }

    // Soft vignette toward the edges, like aged paper stock.
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 1.1,
        colors: [Colors.transparent, const Color(0xFF8A7650).withValues(alpha: 0.06)],
        stops: const [0.65, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter old) => old.base != base;
}

// Rules, frames & ornaments

/// Double engraved border: an outer hairline plus an inset hairline.
class EngravedFrame extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? fill;
  final double inset;
  final EdgeInsetsGeometry padding;

  const EngravedFrame({
    super.key,
    required this.child,
    this.color = AppColors.rule,
    this.fill,
    this.inset = 4,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: color, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.55), width: 0.6),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// ` ◆ ` divider flourish.
class OrnamentDivider extends StatelessWidget {
  final Color color;
  final double width;

  const OrnamentDivider({
    super.key,
    this.color = AppColors.brass,
    this.width = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 10,
      child: Row(
        children: [
          Expanded(child: Container(height: 0.8, color: color.withValues(alpha: 0.7))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(width: 5, height: 5, color: color),
            ),
          ),
          Expanded(child: Container(height: 0.8, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

/// Small printer's registration corners (top-left & bottom-right).
class CornerMarks extends StatelessWidget {
  final Widget child;
  final Color color;
  final double length;

  const CornerMarks({
    super.key,
    required this.child,
    this.color = AppColors.textMuted,
    this.length = 8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _CornerPainter(color, length),
      child: child,
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double len;
  _CornerPainter(this.color, this.len);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    const o = 5.0;
    canvas.drawPath(
      Path()
        ..moveTo(o, o + len)
        ..lineTo(o, o)
        ..lineTo(o + len, o),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - o - len, size.height - o)
        ..lineTo(size.width - o, size.height - o)
        ..lineTo(size.width - o, size.height - o - len),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.color != color || old.len != len;
}

// Typography helpers

/// Eyebrow label + serif title, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 12, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(), style: AppText.eyebrow),
                const SizedBox(height: 4),
                Text(title, style: AppText.sectionTitle),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!.toUpperCase(), style: AppText.action),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 14, color: AppColors.ink),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Italic "Folio No. 07" caption.
class FolioLabel extends StatelessWidget {
  final int number;
  final Color color;

  const FolioLabel(this.number, {super.key, this.color = AppColors.brassInk});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Folio No. ${number.toString().padLeft(2, '0')}',
      style: AppText.folio.copyWith(color: color),
    );
  }
}

/// Dark rectangular "catalogue stamp" (e.g. SPANISH ERA, CHURCH).
class ArchivalStamp extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const ArchivalStamp(
    this.label, {
    super.key,
    this.background = AppColors.inkDeep,
    this.foreground = AppColors.surface,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: foreground.withValues(alpha: 0.35), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// Photographs

/// Restrained sepia toning. [amount] 0 = original colour, 1 = full sepia.
ColorFilter sepiaFilter([double amount = 0.35]) {
  final a = amount.clamp(0.0, 1.0);
  final i = 1 - a;
  // Blend identity matrix with the classic sepia matrix.
  return ColorFilter.matrix(<double>[
    i + a * 0.393, a * 0.769, a * 0.189, 0, 0,
    a * 0.349, i + a * 0.686, a * 0.168, 0, 0,
    a * 0.272, a * 0.534, i + a * 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// Network photo with optional sepia and an archival placeholder.
class ArchivalPhoto extends StatelessWidget {
  final String? url;
  final double sepia;
  final IconData placeholderIcon;
  final BoxFit fit;

  const ArchivalPhoto({
    super.key,
    required this.url,
    this.sepia = 0.3,
    this.placeholderIcon = Icons.account_balance,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.paperDeep,
      alignment: Alignment.center,
      child: Icon(placeholderIcon, size: 42, color: AppColors.rule),
    );

    if (url == null || url!.isEmpty) return placeholder;

    final img = CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
    return sepia > 0 ? ColorFiltered(colorFilter: sepiaFilter(sepia), child: img) : img;
  }
}

IconData categoryIcon(String cat) => switch (cat) {
      'church' => Icons.church_outlined,
      'park' => Icons.park_outlined,
      'historical' => Icons.account_balance_outlined,
      'natural' => Icons.landscape_outlined,
      'cultural' => Icons.museum_outlined,
      _ => Icons.place_outlined,
    };

