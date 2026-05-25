import 'package:flutter/material.dart';
import 'package:leerlus/models/answer_state.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/widgets/app_image.dart';

class ImageClickWidget extends StatefulWidget {
  final QuestionData question;
  final Function(bool isCorrect) onAnswered;
  final bool locked;
  final AnswerState answerState;

  const ImageClickWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    required this.locked,
    required this.answerState,
  });

  @override
  State<ImageClickWidget> createState() => _ImageClickWidgetState();
}

class _ImageClickWidgetState extends State<ImageClickWidget> {
  Offset? _tapPosition;
  double? _aspectRatio;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    final path = widget.question.imagePath;
    if (path != null) {
      resolveImageAspectRatio(path).then((ratio) {
        if (mounted) setState(() => _aspectRatio = ratio);
      });
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    if (widget.locked) return;

    // toScene converts viewport coords → scene (image) coords, accounting for zoom/pan
    final scenePoint = _transformController.toScene(details.localPosition);

    final size = Size(constraints.maxWidth, constraints.maxHeight);
    final normalizedTap = Offset(
      scenePoint.dx / size.width,
      scenePoint.dy / size.height,
    );

    final isCorrect =
        widget.question.imageClickConfig!.isCorrect(normalizedTap);

    setState(() {
      _tapPosition = normalizedTap;
      // Zoom out fully to reveal the result overlay
      _transformController.value = Matrix4.identity();
    });

    widget.onAnswered(isCorrect);
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.question.imagePath;

    if (imagePath == null) {
      return const Center(
        child: Text(
          'No image set for this question.',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    final config = widget.question.imageClickConfig!;
    final answered = widget.answerState != AnswerState.unanswered;
    final isCorrect = widget.answerState == AnswerState.correct;

    if (_aspectRatio == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: AspectRatio(
            aspectRatio: _aspectRatio!,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // InteractiveViewer handles pinch-to-zoom and scroll-wheel
                    // zoom on desktop. clipBehavior keeps zoomed content within
                    // the original widget bounds.
                    InteractiveViewer(
                      transformationController: _transformController,
                      clipBehavior: Clip.hardEdge,
                      minScale: 1.0,
                      maxScale: 8.0,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppImage(
                            path: imagePath,
                            fit: BoxFit.contain,
                          ),
                          // Overlay lives inside the viewer so it zooms and
                          // pans with the image — polygons stay perfectly
                          // aligned at any zoom level.
                          if (answered)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _ClickOverlayPainter(
                                  correctAreas: config.correctAreas,
                                  tapPosition: _tapPosition,
                                  wasCorrect: isCorrect,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Transparent tap detector on top. HitTestBehavior.translucent
                    // lets pan/zoom events pass through to the InteractiveViewer.
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (details) => _handleTap(details, constraints),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}


class _ClickOverlayPainter extends CustomPainter {
  final List<List<Offset>> correctAreas; // normalized 0.0–1.0 polygons
  final Offset? tapPosition;             // normalized 0.0–1.0
  final bool wasCorrect;

  _ClickOverlayPainter({
    required this.correctAreas,
    required this.tapPosition,
    required this.wasCorrect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final polygon in correctAreas) {
      if (polygon.length < 3) continue;

      final pts =
          polygon.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) { path.lineTo(p.dx, p.dy); }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.green.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.green.shade600
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Red cross at the tap position if the answer was wrong
    if (!wasCorrect && tapPosition != null) {
      final scaledTap = Offset(
        tapPosition!.dx * size.width,
        tapPosition!.dy * size.height,
      );
      const r = 10.0;
      final crossPaint = Paint()
        ..color = Colors.red.shade600
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          scaledTap.translate(-r, -r), scaledTap.translate(r, r), crossPaint);
      canvas.drawLine(
          scaledTap.translate(r, -r), scaledTap.translate(-r, r), crossPaint);
    }
  }

  @override
  bool shouldRepaint(_ClickOverlayPainter old) => true;
}
