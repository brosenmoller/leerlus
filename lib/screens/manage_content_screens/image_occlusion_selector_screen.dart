import 'package:flutter/material.dart';
import 'package:leerlus/models/occlusion_data.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:leerlus/widgets/unsaved_changes_guard.dart';

enum _Mode { hide, highlight }

enum _HideTool { polygon, rectangle }

enum _HighlightTool { rect, circle }

/// Preset highlight colors shown as chips in the toolbar.
const _kHighlightColors = [
  Colors.red,
  Colors.amber,
  Colors.green,
  Colors.cyan,
];

class ImageOcclusionSelectorScreen extends StatefulWidget {
  final String imagePath;
  final OcclusionData initialData;

  const ImageOcclusionSelectorScreen({
    super.key,
    required this.imagePath,
    required this.initialData,
  });

  @override
  State<ImageOcclusionSelectorScreen> createState() =>
      _ImageOcclusionSelectorScreenState();
}

class _ImageOcclusionSelectorScreenState
    extends State<ImageOcclusionSelectorScreen> {
  // ── Mode ─────────────────────────────────────────────────────────────────
  _Mode _mode = _Mode.hide;

  // ── Hide mode state ───────────────────────────────────────────────────────
  _HideTool _hideTool = _HideTool.polygon;
  late List<List<Offset>> _hiddenPolygons;
  List<Offset> _drawingPoints = [];
  Offset? _firstRectCorner;
  int? _selectedHideIndex;

  // ── Highlight mode state ──────────────────────────────────────────────────
  _HighlightTool _highlightTool = _HighlightTool.rect;
  late List<HighlightShape> _highlights;
  MaterialColor _highlightColor = _kHighlightColors[0];
  Offset? _firstHighlightCorner;
  int? _selectedHighlightIndex;

  // ── Shared ────────────────────────────────────────────────────────────────
  double? _aspectRatio;
  bool _isDirty = false;
  double _currentScale = 1.0;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _hiddenPolygons = widget.initialData.hiddenAreas
        .map((p) => List<Offset>.from(p))
        .toList();
    _highlights = List<HighlightShape>.from(widget.initialData.highlights);
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
    final s = _transformController.value.getMaxScaleOnAxis();
    if (s != _currentScale) setState(() => _currentScale = s);
  }

  bool get _isDrawing =>
      _drawingPoints.isNotEmpty ||
      _firstRectCorner != null ||
      _firstHighlightCorner != null;

  bool get _hasChanges => _isDirty || _isDrawing;

  // ── Point-in-polygon ──────────────────────────────────────────────────────
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

  static bool _isInsideHighlight(HighlightShape h, Offset p) {
    if (h.type == HighlightShapeType.rect) {
      final r = Rect.fromPoints(h.p1, h.p2);
      return r.contains(p);
    } else {
      final cx = (h.p1.dx + h.p2.dx) / 2;
      final cy = (h.p1.dy + h.p2.dy) / 2;
      final rx = (h.p2.dx - h.p1.dx).abs() / 2;
      final ry = (h.p2.dy - h.p1.dy).abs() / 2;
      if (rx == 0 || ry == 0) return false;
      final dx = p.dx - cx;
      final dy = p.dy - cy;
      return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0;
    }
  }

  // ── Tap handling ──────────────────────────────────────────────────────────
  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final viewportPos = details.localPosition;
    final scenePoint = _transformController.toScene(viewportPos);
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    final normPos = Offset(
      scenePoint.dx / size.width,
      scenePoint.dy / size.height,
    );

    setState(() {
      if (_mode == _Mode.hide) {
        _handleHideTap(normPos, viewportPos, size);
      } else {
        _handleHighlightTap(normPos);
      }
    });
  }

  void _handleHideTap(Offset normPos, Offset viewportPos, Size size) {
    if (_hideTool == _HideTool.rectangle) {
      if (_firstRectCorner == null) {
        _firstRectCorner = normPos;
      } else {
        final a = _firstRectCorner!;
        final b = normPos;
        _hiddenPolygons.add([
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

    // Polygon tool
    if (_drawingPoints.isEmpty) {
      bool tapped = false;
      for (int i = _hiddenPolygons.length - 1; i >= 0; i--) {
        if (_hiddenPolygons[i].length >= 3 &&
            _isInsidePolygon(_hiddenPolygons[i], normPos)) {
          _selectedHideIndex = (_selectedHideIndex == i) ? null : i;
          tapped = true;
          break;
        }
      }
      if (!tapped) {
        if (_selectedHideIndex != null) {
          _selectedHideIndex = null;
        } else {
          _drawingPoints.add(normPos);
        }
      }
      return;
    }

    // Close polygon when near first point
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
        _hiddenPolygons.add(List.from(_drawingPoints));
        _drawingPoints = [];
        _isDirty = true;
        return;
      }
    }
    _drawingPoints.add(normPos);
  }

  void _handleHighlightTap(Offset normPos) {
    if (_firstHighlightCorner == null) {
      // Check if tapping an existing highlight to select/deselect
      bool tapped = false;
      for (int i = _highlights.length - 1; i >= 0; i--) {
        if (_isInsideHighlight(_highlights[i], normPos)) {
          _selectedHighlightIndex = (_selectedHighlightIndex == i) ? null : i;
          tapped = true;
          break;
        }
      }
      if (!tapped) {
        if (_selectedHighlightIndex != null) {
          _selectedHighlightIndex = null;
        } else {
          _firstHighlightCorner = normPos;
        }
      }
    } else {
      final p1 = _firstHighlightCorner!;
      final p2 = normPos;
      if ((p2 - p1).distance > 0.01) {
        _highlights.add(HighlightShape(
          type: _highlightTool == _HighlightTool.circle
              ? HighlightShapeType.circle
              : HighlightShapeType.rect,
          p1: Offset(
              p1.dx < p2.dx ? p1.dx : p2.dx, p1.dy < p2.dy ? p1.dy : p2.dy),
          p2: Offset(
              p1.dx > p2.dx ? p1.dx : p2.dx, p1.dy > p2.dy ? p1.dy : p2.dy),
          colorValue: _highlightColor.toARGB32(),
        ));
        _isDirty = true;
      }
      _firstHighlightCorner = null;
    }
  }

  void _completePolygon() {
    if (_drawingPoints.length < 3) return;
    setState(() {
      _hiddenPolygons.add(List.from(_drawingPoints));
      _drawingPoints = [];
      _isDirty = true;
    });
  }

  void _cancelDrawing() {
    setState(() {
      _drawingPoints = [];
      _firstRectCorner = null;
      _firstHighlightCorner = null;
    });
  }

  void _deleteSelected() {
    setState(() {
      if (_mode == _Mode.hide && _selectedHideIndex != null) {
        _hiddenPolygons.removeAt(_selectedHideIndex!);
        _selectedHideIndex = null;
        _isDirty = true;
      } else if (_mode == _Mode.highlight && _selectedHighlightIndex != null) {
        _highlights.removeAt(_selectedHighlightIndex!);
        _selectedHighlightIndex = null;
        _isDirty = true;
      }
    });
  }

  bool get _hasSelection =>
      (_mode == _Mode.hide && _selectedHideIndex != null) ||
      (_mode == _Mode.highlight && _selectedHighlightIndex != null);

  String get _statusText {
    if (_mode == _Mode.hide) {
      if (_hideTool == _HideTool.rectangle) {
        return _firstRectCorner == null
            ? 'Tap to place the first corner'
            : 'Tap to place the opposite corner';
      }
      if (_drawingPoints.isEmpty) {
        if (_hiddenPolygons.isEmpty) return 'Tap anywhere to start drawing a hidden area';
        if (_selectedHideIndex != null) return 'Shape selected — tap Delete to remove';
        return 'Tap a shape to select it, or tap an empty area to draw a new one';
      }
      if (_drawingPoints.length < 3) {
        return 'Keep tapping to add points (${_drawingPoints.length}/3 minimum to close)';
      }
      return 'Tap near ● to close the polygon, or keep adding points';
    } else {
      if (_firstHighlightCorner == null) {
        if (_highlights.isEmpty) return 'Tap to place the first corner of a highlight shape';
        if (_selectedHighlightIndex != null) return 'Shape selected — tap Delete to remove';
        return 'Tap a shape to select it, or tap an empty area to draw a new one';
      }
      return 'Tap to place the opposite corner';
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasChanges: _hasChanges,
      message: 'Your occlusion area changes will be lost.',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Occlusion Areas'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                OcclusionData(
                  hiddenAreas: _hiddenPolygons,
                  highlights: _highlights,
                ),
              ),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode toggle
          SegmentedButton<_Mode>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(
                value: _Mode.hide,
                label: Text('Hide'),
                icon: Icon(Icons.hide_image_outlined),
              ),
              ButtonSegment(
                value: _Mode.highlight,
                label: Text('Highlight'),
                icon: Icon(Icons.highlight_alt),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _drawingPoints = [];
              _firstRectCorner = null;
              _firstHighlightCorner = null;
              _selectedHideIndex = null;
              _selectedHighlightIndex = null;
            }),
          ),
          const SizedBox(height: 6),

          if (_mode == _Mode.hide) _buildHideToolbar(),
          if (_mode == _Mode.highlight) _buildHighlightToolbar(),
        ],
      ),
    );
  }

  Widget _buildHideToolbar() {
    return Row(
      children: [
        SegmentedButton<_HideTool>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
              value: _HideTool.polygon,
              label: Text('Polygon'),
              icon: Icon(Icons.pentagon_outlined),
            ),
            ButtonSegment(
              value: _HideTool.rectangle,
              label: Text('Rectangle'),
              icon: Icon(Icons.crop_square),
            ),
          ],
          selected: {_hideTool},
          onSelectionChanged: (s) => setState(() {
            _hideTool = s.first;
            _drawingPoints = [];
            _firstRectCorner = null;
          }),
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
        if (!_isDrawing && _hasSelection) ...[
          const SizedBox(width: 8),
          _deleteButton(),
        ],
      ],
    );
  }

  Widget _buildHighlightToolbar() {
    return Row(
      children: [
        SegmentedButton<_HighlightTool>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
              value: _HighlightTool.rect,
              label: Text('Rect'),
              icon: Icon(Icons.crop_square),
            ),
            ButtonSegment(
              value: _HighlightTool.circle,
              label: Text('Circle'),
              icon: Icon(Icons.circle_outlined),
            ),
          ],
          selected: {_highlightTool},
          onSelectionChanged: (s) => setState(() {
            _highlightTool = s.first;
            _firstHighlightCorner = null;
          }),
        ),
        const SizedBox(width: 8),
        // Color chips
        ...(_kHighlightColors.map((c) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => setState(() => _highlightColor = c),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: _highlightColor == c
                        ? Border.all(width: 3, color: Colors.white)
                        : null,
                    boxShadow: _highlightColor == c
                        ? [BoxShadow(color: c.shade700, blurRadius: 4)]
                        : null,
                  ),
                ),
              ),
            ))),
        if (_isDrawing) ...[
          const SizedBox(width: 4),
          TextButton(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onPressed: _cancelDrawing,
            child: const Text('Cancel'),
          ),
        ],
        if (!_isDrawing && _hasSelection) ...[
          const SizedBox(width: 8),
          _deleteButton(),
        ],
      ],
    );
  }

  Widget _deleteButton() {
    return FilledButton.tonal(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.all(Colors.red.shade700),
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
                      AppImage(path: widget.imagePath, fit: BoxFit.contain),
                      CustomPaint(
                        painter: _OcclusionSelectorPainter(
                          hiddenPolygons: _hiddenPolygons,
                          highlights: _highlights,
                          drawingPoints: _drawingPoints,
                          firstRectCorner: _firstRectCorner,
                          firstHighlightCorner: _firstHighlightCorner,
                          highlightTool: _highlightTool,
                          highlightColor: _highlightColor,
                          selectedHideIndex: _selectedHideIndex,
                          selectedHighlightIndex: _selectedHighlightIndex,
                          scale: _currentScale,
                          mode: _mode,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (d) => _handleTap(d, constraints),
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

class _OcclusionSelectorPainter extends CustomPainter {
  final List<List<Offset>> hiddenPolygons;
  final List<HighlightShape> highlights;
  final List<Offset> drawingPoints;
  final Offset? firstRectCorner;
  final Offset? firstHighlightCorner;
  final _HighlightTool highlightTool;
  final MaterialColor highlightColor;
  final int? selectedHideIndex;
  final int? selectedHighlightIndex;
  final double scale;
  final _Mode mode;

  _OcclusionSelectorPainter({
    required this.hiddenPolygons,
    required this.highlights,
    required this.drawingPoints,
    required this.firstRectCorner,
    required this.firstHighlightCorner,
    required this.highlightTool,
    required this.highlightColor,
    required this.selectedHideIndex,
    required this.selectedHighlightIndex,
    required this.scale,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Completed hidden polygons ─────────────────────────────────────────
    for (int i = 0; i < hiddenPolygons.length; i++) {
      if (hiddenPolygons[i].length < 3) continue;
      _drawHiddenPolygon(canvas, size, hiddenPolygons[i],
          isSelected: selectedHideIndex == i);
    }

    // ── In-progress hidden polygon ────────────────────────────────────────
    if (drawingPoints.isNotEmpty) {
      final pts = drawingPoints
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();
      final stroke = Paint()
        ..color = Colors.orange.shade700
        ..strokeWidth = 2 / scale
        ..style = PaintingStyle.stroke;
      for (int i = 1; i < pts.length; i++) {
        canvas.drawLine(pts[i - 1], pts[i], stroke);
      }
      if (pts.length >= 3) {
        canvas.drawLine(
            pts.last,
            pts.first,
            Paint()
              ..color = Colors.orange.shade400
              ..strokeWidth = 1.5 / scale
              ..style = PaintingStyle.stroke);
      }
      final dotPaint = Paint()
        ..color = Colors.orange.shade700
        ..style = PaintingStyle.fill;
      for (int i = 1; i < pts.length; i++) {
        canvas.drawCircle(pts[i], 4 / scale, dotPaint);
      }
      canvas.drawCircle(pts.first, 9 / scale,
          Paint()
            ..color = Colors.orange.shade100
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          pts.first,
          9 / scale,
          Paint()
            ..color = Colors.orange.shade700
            ..strokeWidth = 2.5 / scale
            ..style = PaintingStyle.stroke);
      canvas.drawCircle(pts.first, 3 / scale, dotPaint);
    }

    // ── First rectangle corner marker ─────────────────────────────────────
    if (firstRectCorner != null) {
      final pt = Offset(
        firstRectCorner!.dx * size.width,
        firstRectCorner!.dy * size.height,
      );
      canvas.drawCircle(pt, 8 / scale,
          Paint()
            ..color = Colors.orange.shade100
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          pt, 8 / scale,
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

    // ── Completed highlight shapes ────────────────────────────────────────
    for (int i = 0; i < highlights.length; i++) {
      _drawHighlight(canvas, size, highlights[i],
          isSelected: selectedHighlightIndex == i);
    }

    // ── In-progress highlight ─────────────────────────────────────────────
    if (firstHighlightCorner != null) {
      final pt = Offset(
        firstHighlightCorner!.dx * size.width,
        firstHighlightCorner!.dy * size.height,
      );
      canvas.drawCircle(pt, 8 / scale,
          Paint()
            ..color = highlightColor.shade100
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          pt, 8 / scale,
          Paint()
            ..color = highlightColor.shade700
            ..strokeWidth = 2.5 / scale
            ..style = PaintingStyle.stroke);
    }
  }

  void _drawHiddenPolygon(Canvas canvas, Size size, List<Offset> polygon,
      {required bool isSelected}) {
    final pts =
        polygon.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    final fillColor = isSelected ? Colors.blue : Colors.black;
    final borderColor = isSelected ? Colors.blue.shade700 : Colors.grey.shade800;

    canvas.drawPath(
        path,
        Paint()
          ..color = fillColor.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = borderColor
          ..strokeWidth = 2.5 / scale
          ..style = PaintingStyle.stroke);
    for (final p in pts) {
      canvas.drawCircle(
          p, 4 / scale, Paint()..color = borderColor..style = PaintingStyle.fill);
    }
  }

  void _drawHighlight(Canvas canvas, Size size, HighlightShape h,
      {required bool isSelected}) {
    final x1 = h.p1.dx * size.width;
    final y1 = h.p1.dy * size.height;
    final x2 = h.p2.dx * size.width;
    final y2 = h.p2.dy * size.height;

    final baseColor = Color(h.colorValue);
    final strokeColor = isSelected ? Colors.blue.shade700 : baseColor;
    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 3 / scale
      ..style = PaintingStyle.stroke;

    if (h.type == HighlightShapeType.rect) {
      canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), strokePaint);
      if (isSelected) {
        canvas.drawRect(
            Rect.fromLTRB(x1, y1, x2, y2),
            Paint()
              ..color = Colors.blue.withValues(alpha: 0.15)
              ..style = PaintingStyle.fill);
      }
    } else {
      canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), strokePaint);
      if (isSelected) {
        canvas.drawOval(
            Rect.fromLTRB(x1, y1, x2, y2),
            Paint()
              ..color = Colors.blue.withValues(alpha: 0.15)
              ..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(_OcclusionSelectorPainter old) => true;
}
