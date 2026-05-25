import 'package:flutter/material.dart';
import 'package:leerlus/models/occlusion_data.dart';
import 'package:leerlus/widgets/app_image.dart';

/// Wraps [AppImage] with an occlusion overlay.
///
/// Hidden areas are drawn as opaque black polygons before [revealed] is true,
/// and as semi-transparent green overlays after reveal (so the student can see
/// what was hidden).
///
/// Highlight shapes (rect/circle borders) are always drawn regardless of
/// [revealed].
class OccludedImage extends StatelessWidget {
  final String? imagePath;
  final OcclusionData occlusionData;

  /// When false, hidden areas are fully opaque (blocking view).
  /// When true, hidden areas become semi-transparent to show the reveal.
  final bool revealed;

  final BoxFit fit;

  const OccludedImage({
    super.key,
    required this.imagePath,
    required this.occlusionData,
    required this.revealed,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppImage(path: imagePath, fit: fit),
        CustomPaint(
          painter: _OcclusionOverlayPainter(
            occlusionData: occlusionData,
            revealed: revealed,
          ),
        ),
      ],
    );
  }
}

class _OcclusionOverlayPainter extends CustomPainter {
  final OcclusionData occlusionData;
  final bool revealed;

  _OcclusionOverlayPainter({
    required this.occlusionData,
    required this.revealed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Hidden areas ──────────────────────────────────────────────────────
    for (final polygon in occlusionData.hiddenAreas) {
      if (polygon.length < 3) continue;
      final pts =
          polygon.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();

      if (revealed) {
        // Semi-transparent green tint so the student sees what was hidden
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.green.withValues(alpha: 0.35)
              ..style = PaintingStyle.fill);
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.green.shade700
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke);
      } else {
        // Fully opaque black block
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.black
              ..style = PaintingStyle.fill);
      }
    }

    // ── Highlight shapes (always visible) ─────────────────────────────────
    for (final h in occlusionData.highlights) {
      final x1 = h.p1.dx * size.width;
      final y1 = h.p1.dy * size.height;
      final x2 = h.p2.dx * size.width;
      final y2 = h.p2.dy * size.height;

      final paint = Paint()
        ..color = Color(h.colorValue)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      if (h.type == HighlightShapeType.rect) {
        canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), paint);
      } else {
        canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_OcclusionOverlayPainter old) =>
      old.revealed != revealed ||
      old.occlusionData != occlusionData;
}
