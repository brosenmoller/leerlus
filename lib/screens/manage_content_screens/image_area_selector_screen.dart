import 'package:flutter/material.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:leerlus/widgets/unsaved_changes_guard.dart';

enum _Tool { polygon, rectangle }

class ImageAreaSelectorScreen extends StatefulWidget {
  final String imagePath;
  final List<List<Offset>> initialAreas;

  const ImageAreaSelectorScreen({
    super.key,
    required this.imagePath,
    required this.initialAreas,
  });

  @override
  State<ImageAreaSelectorScreen> createState() =>
      _ImageAreaSelectorScreenState();
}

class _ImageAreaSelectorScreenState extends State<ImageAreaSelectorScreen> {
  _Tool _tool = _Tool.polygon;
  late List<List<Offset>> _polygons;
  List<Offset> _drawingPoints = [];
  Offset? _firstRectCorner;
  int? _selectedIndex;
  double? _aspectRatio;
  bool _isDirty = false;
  double _currentScale = 1.0;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _polygons = widget.initialAreas.map((p) => List<Offset>.from(p)).toList();
    _transformController.addListener(_onTransformChanged);
    resolveImageAspectRatio(widget.imagePath).then((ratio) {
      if (mounted) setState(() => _aspectRatio = ratio);
    });
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final newScale = _transformController.value.getMaxScaleOnAxis();
    if (newScale != _currentScale) {
      setState(() => _currentScale = newScale);
    }
  }

  bool get _isDrawing => _drawingPoints.isNotEmpty || _firstRectCorner != null;
  bool get _hasChanges => _isDirty || _isDrawing;

  static bool _isInsidePolygon(List<Offset> polygon, Offset point) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy) &&
          point.dx <
              (polygon[j].dx - polygon[i].dx) *
                      (point.dy - polygon[i].dy) /
                      (polygon[j].dy - polygon[i].dy) +
                  polygon[i].dx) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final viewportPos = details.localPosition;
    final scenePoint = _transformController.toScene(viewportPos);
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    final normPos = Offset(
      scenePoint.dx / size.width,
      scenePoint.dy / size.height,
    );

    setState(() {
      // ── Rectangle tool ──────────────────────────────────────────────────
      if (_tool == _Tool.rectangle) {
        if (_firstRectCorner == null) {
          _firstRectCorner = normPos;
        } else {
          final a = _firstRectCorner!;
          final b = normPos;
          _polygons.add([
            Offset(a.dx, a.dy),
            Offset(b.dx, a.dy),
            Offset(b.dx, b.dy),
            Offset(a.dx, b.dy),
          ]);
          _firstRectCorner = null;
          _isDirty = true;
        }
        return;
      }

      // ── Polygon tool, not currently drawing ─────────────────────────────
      if (_drawingPoints.isEmpty) {
        bool tappedPolygon = false;
        for (int i = _polygons.length - 1; i >= 0; i--) {
          if (_polygons[i].length >= 3 &&
              _isInsidePolygon(_polygons[i], normPos)) {
            _selectedIndex = (_selectedIndex == i) ? null : i;
            tappedPolygon = true;
            break;
          }
        }
        if (!tappedPolygon) {
          if (_selectedIndex != null) {
            // First tap outside with a selection → just deselect
            _selectedIndex = null;
          } else {
            // Nothing selected → start a new polygon
            _drawingPoints.add(normPos);
          }
        }
        return;
      }

      // ── Polygon tool, currently drawing ─────────────────────────────────
      // Close polygon when tapping near the first point (22 px in viewport)
      if (_drawingPoints.length >= 3) {
        final firstScene = Offset(
          _drawingPoints.first.dx * size.width,
          _drawingPoints.first.dy * size.height,
        );
        final firstViewport = MatrixUtils.transformPoint(
          _transformController.value,
          firstScene,
        );
        if ((viewportPos - firstViewport).distance < 22.0) {
          _polygons.add(List.from(_drawingPoints));
          _drawingPoints = [];
          _isDirty = true;
          return;
        }
      }
      _drawingPoints.add(normPos);
    });
  }

  void _completePolygon() {
    if (_drawingPoints.length < 3) return;
    setState(() {
      _polygons.add(List.from(_drawingPoints));
      _drawingPoints = [];
      _isDirty = true;
    });
  }

  void _cancelDrawing() {
    setState(() {
      _drawingPoints = [];
      _firstRectCorner = null;
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null) return;
    setState(() {
      _polygons.removeAt(_selectedIndex!);
      _selectedIndex = null;
      _isDirty = true;
    });
  }

  String get _statusText {
    if (_tool == _Tool.rectangle) {
      return _firstRectCorner == null
          ? 'Tap to place the first corner'
          : 'Tap to place the opposite corner';
    }
    if (_drawingPoints.isEmpty) {
      if (_polygons.isEmpty) return 'Tap anywhere to start drawing a polygon';
      if (_selectedIndex != null) {
        return 'Shape selected — tap Delete to remove, or tap outside to deselect';
      }
      return 'Tap a shape to select it, or tap an empty area to start a new polygon';
    }
    if (_drawingPoints.length < 3) {
      return 'Keep tapping to add points (${_drawingPoints.length}/3 minimum to close)';
    }
    return 'Tap near ● to close the polygon, or keep adding points';
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasChanges: _hasChanges,
      message: 'Your area selection changes will be lost.',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Click Areas'),
          actions: [
            TextButton(
              // Direct pop bypasses UnsavedChangesGuard — always saves.
              onPressed: () => Navigator.pop(context, _polygons),
              child: const Text('Save'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                _statusText,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ),
            Expanded(
              child: _aspectRatio == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCanvas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          SegmentedButton<_Tool>(
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: _Tool.polygon,
                label: Text('Polygon'),
                icon: Icon(Icons.pentagon_outlined),
              ),
              ButtonSegment(
                value: _Tool.rectangle,
                label: Text('Rectangle'),
                icon: Icon(Icons.crop_square),
              ),
            ],
            selected: {_tool},
            onSelectionChanged: (s) {
              setState(() {
                _tool = s.first;
                _drawingPoints = [];
                _firstRectCorner = null;
              });
            },
          ),
          const SizedBox(width: 8),
          if (_drawingPoints.length >= 3)
            FilledButton.tonal(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onPressed: _completePolygon,
              child: const Text('Complete'),
            ),
          if (_isDrawing) ...[
            const SizedBox(width: 4),
            TextButton(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onPressed: _cancelDrawing,
              child: const Text('Cancel'),
            ),
          ],
          if (!_isDrawing && _selectedIndex != null) ...[
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor:
                    WidgetStateProperty.all(Colors.red.shade700),
              ),
              onPressed: _deleteSelected,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  const Text('Delete'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Center(
      child: AspectRatio(
        aspectRatio: _aspectRatio!,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  transformationController: _transformController,
                  clipBehavior: Clip.hardEdge,
                  minScale: 1.0,
                  maxScale: 8.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImage(
                        path: widget.imagePath,
                        fit: BoxFit.contain,
                      ),
                      CustomPaint(
                        painter: _AreaPainter(
                          polygons: _polygons,
                          drawingPoints: _drawingPoints,
                          firstRectCorner: _firstRectCorner,
                          selectedIndex: _selectedIndex,
                          scale: _currentScale,
                        ),
                      ),
                    ],
                  ),
                ),
                // Transparent tap catcher on top; translucent so pan/zoom
                // events still reach the InteractiveViewer beneath.
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) => _handleTap(details, constraints),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _AreaPainter extends CustomPainter {
  final List<List<Offset>> polygons;
  final List<Offset> drawingPoints;
  final Offset? firstRectCorner;
  final int? selectedIndex;
  /// Current zoom level from InteractiveViewer. All pixel sizes are divided by
  /// this so they appear the same physical size on screen at any zoom level.
  final double scale;

  _AreaPainter({
    required this.polygons,
    required this.drawingPoints,
    required this.firstRectCorner,
    required this.selectedIndex,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Completed polygons
    for (int i = 0; i < polygons.length; i++) {
      if (polygons[i].length < 3) continue;
      _drawPolygon(canvas, size, polygons[i], isSelected: selectedIndex == i);
    }

    // In-progress polygon
    if (drawingPoints.isNotEmpty) {
      final pts = drawingPoints
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();

      final strokePaint = Paint()
        ..color = Colors.orange.shade700
        ..strokeWidth = 2 / scale
        ..style = PaintingStyle.stroke;

      for (int i = 1; i < pts.length; i++) {
        canvas.drawLine(pts[i - 1], pts[i], strokePaint);
      }

      // Closing-line preview when >= 3 points
      if (pts.length >= 3) {
        canvas.drawLine(
          pts.last,
          pts.first,
          Paint()
            ..color = Colors.orange.shade400
            ..strokeWidth = 1.5 / scale
            ..style = PaintingStyle.stroke,
        );
      }

      // Regular point dots (all except first)
      final dotPaint = Paint()
        ..color = Colors.orange.shade700
        ..style = PaintingStyle.fill;
      for (int i = 1; i < pts.length; i++) {
        canvas.drawCircle(pts[i], 4 / scale, dotPaint);
      }

      // First point: larger ring to signal "tap here to close"
      canvas.drawCircle(pts.first, 9 / scale,
          Paint()..color = Colors.orange.shade100..style = PaintingStyle.fill);
      canvas.drawCircle(
          pts.first,
          9 / scale,
          Paint()
            ..color = Colors.orange.shade700
            ..strokeWidth = 2.5 / scale
            ..style = PaintingStyle.stroke);
      canvas.drawCircle(pts.first, 3 / scale, dotPaint);
    }

    // First rectangle corner marker
    if (firstRectCorner != null) {
      final pt = Offset(
        firstRectCorner!.dx * size.width,
        firstRectCorner!.dy * size.height,
      );
      canvas.drawCircle(
          pt,
          8 / scale,
          Paint()
            ..color = Colors.orange.shade100
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          pt,
          8 / scale,
          Paint()
            ..color = Colors.orange.shade700
            ..strokeWidth = 2.5 / scale
            ..style = PaintingStyle.stroke);
      final r = 5.0 / scale;
      final cross = Paint()
        ..color = Colors.orange.shade700
        ..strokeWidth = 2 / scale;
      canvas.drawLine(pt.translate(-r, 0), pt.translate(r, 0), cross);
      canvas.drawLine(pt.translate(0, -r), pt.translate(0, r), cross);
    }
  }

  void _drawPolygon(
    Canvas canvas,
    Size size,
    List<Offset> polygon, {
    required bool isSelected,
  }) {
    final pts =
        polygon.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) { path.lineTo(p.dx, p.dy); }
    path.close();

    final base = isSelected ? Colors.blue : Colors.green;
    final border = isSelected ? Colors.blue.shade700 : Colors.green.shade700;

    canvas.drawPath(
        path, Paint()..color = base.withValues(alpha: 0.2)..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = border
          ..strokeWidth = 2.5 / scale
          ..style = PaintingStyle.stroke);

    // Vertex dots
    for (final p in pts) {
      canvas.drawCircle(
          p, 4 / scale, Paint()..color = border..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_AreaPainter old) => true;
}
