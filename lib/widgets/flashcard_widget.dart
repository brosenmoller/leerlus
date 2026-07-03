import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leerlus/models/occlusion_data.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/user_question_data.dart';
import 'package:leerlus/screens/question_display/srs_buttons.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:leerlus/widgets/auto_scale_text.dart';
import 'package:leerlus/widgets/occluded_image.dart';

class FlashcardWidget extends StatefulWidget {
  final QuestionData question;
  final bool locked;
  final Function(bool isCorrect) onAnswered;
  final Function(SrsQuality quality)? onSrsAnswered;
  final bool spacedRepetitionMode;

  const FlashcardWidget({
    super.key,
    required this.question,
    required this.locked,
    required this.onAnswered,
    this.onSrsAnswered,
    required this.spacedRepetitionMode,
  });

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with SingleTickerProviderStateMixin {
  late bool _sidesSwapped;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final config = widget.question.flashcardConfig!;
    _sidesSwapped = config.randomizeSides && Random().nextBool();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    // Rebuild button section on status changes (dismissed / completed).
    // The card uses AnimatedBuilder for per-frame updates; buttons only need status.
    _controller.addStatusListener((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (widget.locked || !_controller.isDismissed) return;
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.question.flashcardConfig!;

    final frontText = _sidesSwapped ? config.backText : config.frontText;
    final frontImagePath = _sidesSwapped
        ? config.backImagePath
        : config.frontImagePath;
    final backText = _sidesSwapped ? config.frontText : config.backText;
    final backImagePath = _sidesSwapped
        ? config.frontImagePath
        : config.backImagePath;
    final frontLabel = _sidesSwapped ? 'Back' : 'Front';
    final backLabel = _sidesSwapped ? 'Front' : 'Back';
    final frontOcclusion =
        widget.question.occlusionDataByImage[_sidesSwapped ? 'back' : 'front'];

    // A face showing both an image and text needs more vertical room, so the
    // card switches to a portrait shape whenever either side has both.
    final frontHasBoth = frontImagePath != null && frontText != null;
    final backHasBoth = backImagePath != null && backText != null;
    final cardAspectRatio = (frontHasBoth || backHasBoth) ? 4 / 5 : 5 / 4;

    // The answer buttons are always in the layout tree to anchor the button
    // section height. They fade in on completion; the flip button is overlaid
    // as a positioned child so it never affects layout height.
    // This keeps the Expanded card area — and therefore card position — stable
    // across all three states: before flip, during flip, and after flip.
    final answerButtons = widget.spacedRepetitionMode
        ? SrsButtons(
            question: widget.question,
            autofocus: _controller.isCompleted,
            onAnswered: (quality) =>
                widget.onSrsAnswered?.call(quality) ?? widget.onAnswered(true),
          )
        : Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.locked
                        ? null
                        : () => widget.onAnswered(false),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'Incorrect',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: widget.locked
                        ? null
                        : () => widget.onAnswered(true),
                    icon: const Icon(Icons.check),
                    label: const Text('Correct'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Enter / Space flips the card while it's still on the front.
        // Once flipped, let the event propagate so focused answer/SRS
        // buttons handle it normally.
        if (event is KeyDownEvent &&
            _controller.isDismissed &&
            !widget.locked &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          _flip();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: AspectRatio(
                      aspectRatio: cardAspectRatio,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final t = _controller.value;
                          final showFront = t < 0.5;
                          // Normalize t to 0→1 within each half and apply a curve
                          // so the first half eases in (compress) and second eases out (expand).
                          final halfT = showFront ? t / 0.5 : (t - 0.5) / 0.5;
                          final curvedT = showFront
                              ? Curves.easeIn.transform(halfT)
                              : Curves.easeOut.transform(halfT);
                          final scaleX = showFront ? 1.0 - curvedT : curvedT;

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Transform.scale(
                                scaleX: scaleX,
                                child: showFront
                                    ? _CardFace(
                                        label: frontLabel,
                                        text: frontText,
                                        imagePath: frontImagePath,
                                        occlusionData: frontOcclusion,
                                        tapToFlip: !widget.locked,
                                        onTap: _flip,
                                      )
                                    : _CardFace(
                                        label: backLabel,
                                        text: backText,
                                        imagePath: backImagePath,
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Stack(
                  children: [
                    // Answer buttons: always in layout (height anchor).
                    // Non-interactive and invisible until animation completes.
                    ExcludeFocus(
                      excluding: !_controller.isCompleted,
                      child: IgnorePointer(
                        ignoring: !_controller.isCompleted,
                        child: AnimatedOpacity(
                          opacity: _controller.isCompleted ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: answerButtons,
                        ),
                      ),
                    ),
                    // Flip button: positioned overlay, only present when dismissed.
                    // Does not contribute to Stack height.
                    if (_controller.isDismissed)
                      Positioned.fill(
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: widget.locked ? null : _flip,
                            icon: const Icon(Icons.flip),
                            label: const Text('Flip card'),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatefulWidget {
  final String label;
  final String? text;
  final String? imagePath;
  final OcclusionData? occlusionData;
  final bool tapToFlip;
  final VoidCallback? onTap;

  const _CardFace({
    required this.label,
    this.text,
    this.imagePath,
    this.occlusionData,
    this.tapToFlip = false,
    this.onTap,
  });

  @override
  State<_CardFace> createState() => _CardFaceState();
}

class _CardFaceState extends State<_CardFace> {
  // Real aspect ratio of the image, resolved async when occlusion is present so
  // the overlay is painted on an AspectRatio that exactly matches the image
  // (no letterboxing offset). Mirrors QuestionImage.
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatioIfNeeded();
  }

  @override
  void didUpdateWidget(_CardFace old) {
    super.didUpdateWidget(old);
    if (widget.imagePath != old.imagePath) {
      _aspectRatio = null;
      _resolveAspectRatioIfNeeded();
    }
  }

  void _resolveAspectRatioIfNeeded() {
    final path = widget.imagePath;
    if (widget.occlusionData == null || path == null) return;
    resolveImageAspectRatio(path).then((r) {
      if (mounted) setState(() => _aspectRatio = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.label;
    final text = widget.text;
    final imagePath = widget.imagePath;
    final occlusionData = widget.occlusionData;
    final tapToFlip = widget.tapToFlip;

    // Image rendering shared between the image-only and image+text layouts.
    // With occlusion, paint the overlay on an AspectRatio that matches the
    // image so hidden/highlight areas land exactly on it. Until the ratio
    // resolves (or without occlusion), fall back to a plain contained image.
    Widget buildImage(String path) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: occlusionData != null && _aspectRatio != null
              ? AspectRatio(
                  aspectRatio: _aspectRatio!,
                  child: OccludedImage(
                    imagePath: path,
                    occlusionData: occlusionData,
                    revealed: false,
                  ),
                )
              : AppImage(path: path, fit: BoxFit.contain),
        ),
      );
    }

    Widget buildContent() {
      if (imagePath != null && text != null) {
        // Image section capped at ~50% of the face; text takes the rest and
        // scales down then scrolls (via AutoScaleText) so it never overflows.
        return LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.5,
                  ),
                  child: buildImage(imagePath),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AutoScaleText(
                    text: text,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            );
          },
        );
      }
      if (imagePath != null) {
        return buildImage(imagePath);
      }
      if (text != null) {
        return AutoScaleText(text: text, style: theme.textTheme.titleLarge);
      }
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: tapToFlip ? widget.onTap : null,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Divider(height: 20),
              Expanded(child: buildContent()),
              if (tapToFlip)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      'Tap to flip',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
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
