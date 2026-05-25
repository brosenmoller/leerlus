import 'dart:math';
import 'package:flutter/material.dart';
import 'package:leerlus/models/occlusion_data.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:leerlus/widgets/occluded_image.dart';

class FlashcardWidget extends StatefulWidget {
  final QuestionData question;
  final bool locked;
  final Function(bool isCorrect) onAnswered;
  final bool spacedRepetitionMode;

  const FlashcardWidget({
    super.key,
    required this.question,
    required this.locked,
    required this.onAnswered,
    required this.spacedRepetitionMode,
  });

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  bool _flipped = false;
  late bool _sidesSwapped;

  @override
  void initState() {
    super.initState();
    final config = widget.question.flashcardConfig!;
    _sidesSwapped = config.randomizeSides && Random().nextBool();
  }

  void _flip() {
    if (widget.locked) return;
    setState(() => _flipped = true);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.question.flashcardConfig!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: _flipped
                  ? _CardFace(
                      key: const ValueKey('back'),
                      label: _sidesSwapped ? 'Front' : 'Back',
                      text: _sidesSwapped ? config.frontText : config.backText,
                      imagePath: _sidesSwapped ? config.frontImagePath : config.backImagePath,
                    )
                  : _CardFace(
                      key: const ValueKey('front'),
                      label: _sidesSwapped ? 'Back' : 'Front',
                      text: _sidesSwapped ? config.backText : config.frontText,
                      imagePath: _sidesSwapped ? config.backImagePath : config.frontImagePath,
                      occlusionData: widget.question.occlusionData,
                      tapToFlip: !widget.locked,
                      onTap: _flip,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_flipped)
            Center(
              child: OutlinedButton.icon(
                onPressed: widget.locked ? null : _flip,
                icon: const Icon(Icons.flip),
                label: const Text('Flip card'),
              ),
            )
          else if (widget.spacedRepetitionMode)
            Center(
              child: FilledButton.icon(
                onPressed: widget.locked ? null : () => widget.onAnswered(true),
                icon: const Icon(Icons.check),
                label: const Text('I reviewed it'),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.locked ? null : () => widget.onAnswered(false),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Incorrect',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: widget.locked ? null : () => widget.onAnswered(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Correct'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final String label;
  final String? text;
  final String? imagePath;
  final OcclusionData? occlusionData;
  final bool tapToFlip;
  final VoidCallback? onTap;

  const _CardFace({
    super.key,
    required this.label,
    this.text,
    this.imagePath,
    this.occlusionData,
    this.tapToFlip = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: tapToFlip ? onTap : null,
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
              if (imagePath != null)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: occlusionData != null
                        ? OccludedImage(
                            imagePath: imagePath,
                            occlusionData: occlusionData!,
                            revealed: false,
                          )
                        : AppImage(
                            path: imagePath,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              if (imagePath != null && text != null) const SizedBox(height: 16),
              if (text != null)
                Text(
                  text!,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              if (tapToFlip) ...[
                const Spacer(),
                Center(
                  child: Text(
                    'Tap to flip',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
