import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/answer_state.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/widgets/question_image.dart';

class MultipleChoiceWidget extends StatefulWidget {
  final QuestionData question;
  final Function(bool isCorrect) onAnswered;
  final bool locked;
  final AnswerState answerState;

  const MultipleChoiceWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    required this.locked,
    required this.answerState,
  });

  @override
  State<MultipleChoiceWidget> createState() => _MultipleChoiceWidgetState();
}

class _MultipleChoiceWidgetState extends State<MultipleChoiceWidget> {
  late List<String> options;
  late Set<int> _selectedIndices;
  late Set<int> _correctDisplayIndices;
  late bool _isMultipleCorrect;
  late FocusNode _focusNode;
  String? _resolvedImagePath;

  bool get isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    final config = widget.question.multipleChoiceConfig!;
    _isMultipleCorrect = config.multipleCorrect;

    final originalOptions = config.options;
    final correctTexts =
        config.correctIndices.map((i) => originalOptions[i]).toSet();

    options = List.from(originalOptions);
    if (config.scrambleOptions) options.shuffle(Random());

    _selectedIndices = {};
    _correctDisplayIndices = options
        .asMap()
        .entries
        .where((e) => correctTexts.contains(e.value))
        .map((e) => e.key)
        .toSet();

    final variants = widget.question.imagePathVariants;
    if (variants.isNotEmpty) {
      _resolvedImagePath = variants[Random().nextInt(variants.length)];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleOption(int index) {
    if (widget.locked) return;

    if (!_isMultipleCorrect) {
      // Single-correct: auto-submit on first tap.
      if (_selectedIndices.isNotEmpty) return;
      setState(() => _selectedIndices = {index});
      widget.onAnswered(_correctDisplayIndices.contains(index));
    } else {
      // Multi-correct: toggle selection, submit via check button.
      setState(() {
        if (_selectedIndices.contains(index)) {
          _selectedIndices.remove(index);
        } else {
          _selectedIndices.add(index);
        }
      });
    }
  }

  void _checkAnswer() {
    if (widget.locked || _selectedIndices.isEmpty) return;
    widget.onAnswered(setEquals(_selectedIndices, _correctDisplayIndices));
  }

  /// Background colour for an option button.
  Color? _buttonColor(int index, BuildContext context) {
    if (widget.answerState == AnswerState.unanswered) {
      if (_isMultipleCorrect && _selectedIndices.contains(index)) {
        return Theme.of(context).colorScheme.primaryContainer;
      }
      return null;
    }

    final isSelected = _selectedIndices.contains(index);
    final isCorrect = _correctDisplayIndices.contains(index);

    if (!_isMultipleCorrect) {
      if (isSelected && widget.answerState == AnswerState.correct) {
        return Colors.green.shade600;
      }
      if (isSelected && widget.answerState == AnswerState.incorrect) {
        return Colors.red.shade600;
      }
      if (!isSelected &&
          isCorrect &&
          widget.answerState == AnswerState.incorrect) {
        return Colors.green.shade600;
      }
      return null;
    }

    // Multi-correct post-check: always reveal correct in green, wrong in red.
    if (isCorrect) return Colors.green.shade600;
    if (isSelected) return Colors.red.shade600;
    return null;
  }

  /// Trailing icon shown on a button after the answer is checked.
  /// Only appears on options the user actually selected, so green buttons
  /// without an icon are correct answers the user missed.
  Widget? _trailingIcon(int index) {
    if (widget.answerState == AnswerState.unanswered) return null;
    if (!_selectedIndices.contains(index)) return null;

    final isCorrect = _correctDisplayIndices.contains(index);
    return Icon(
      isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined,
      color: Colors.white,
      size: 20,
    );
  }

  Color? _textColor(int index, BuildContext context) {
    final bg = _buttonColor(index, context);
    if (bg == null) return null;
    if (widget.answerState == AnswerState.unanswered) {
      return Theme.of(context).colorScheme.onPrimaryContainer;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = widget.question.multipleChoiceConfig!;

    final buttonItems = List.generate(options.length, (index) {
      final bgColor = _buttonColor(index, context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ElevatedButton(
          onPressed: widget.locked ? null : () => _toggleOption(index),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            backgroundColor: bgColor,
            disabledBackgroundColor: bgColor,
            disabledForegroundColor: _textColor(index, context),
            foregroundColor: _textColor(index, context),
          ),
          child: Row(
            children: [
              if (isDesktop)
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 28,
                    child: _ShortcutBadge(
                      number: index + 1,
                      overrideColor: _textColor(index, context),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(options[index], textAlign: TextAlign.left),
              ),
              if (_trailingIcon(index) case final icon?) ...[
                const SizedBox(width: 8),
                icon,
              ],
            ],
          ),
        ),
      );
    });

    final half = (options.length / 2).ceil();

    Widget buttonGrid = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 500) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 60),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: buttonItems.sublist(0, half),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: buttonItems.sublist(half),
                ),
              ),
              const SizedBox(width: 60),
            ],
          );
        }
        return Row(
          children: [
            const SizedBox(width: 60),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: buttonItems,
              ),
            ),
            const SizedBox(width: 60),
          ],
        );
      },
    );

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_resolvedImagePath != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: QuestionImage(
                path: _resolvedImagePath!,
                maxHeight: double.infinity,
                occlusionData: widget.question.occlusionData,
                occlusionRevealed: widget.answerState != AnswerState.unanswered,
              ),
            ),
          )
        else
          const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isMultipleCorrect) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Chip(
                        avatar: const Icon(Icons.check_box_outlined, size: 16),
                        label: Text(
                          config.showCorrectCount
                              ? l10n.selectNCorrectAnswers(
                                  _correctDisplayIndices.length)
                              : l10n.selectAllThatApply,
                          style: const TextStyle(fontSize: 13),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                  buttonGrid,
                  if (_isMultipleCorrect &&
                      widget.answerState == AnswerState.unanswered) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed:
                          _selectedIndices.isNotEmpty ? _checkAnswer : null,
                      child: Text(l10n.checkAnswer),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (!isDesktop) return content;

    final topRowKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];

    final numpadKeys = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && !widget.locked) {
          // Number keys: toggle option.
          for (int i = 0; i < options.length && i < 9; i++) {
            if (event.logicalKey == topRowKeys[i] ||
                event.logicalKey == numpadKeys[i]) {
              _toggleOption(i);
              return KeyEventResult.handled;
            }
          }
          // Enter/Space: submit multi-select answer.
          if (_isMultipleCorrect &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            _checkAnswer();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: content,
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  final int number;
  final Color? overrideColor;

  const _ShortcutBadge({required this.number, this.overrideColor});

  @override
  Widget build(BuildContext context) {
    final color = overrideColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        number.toString(),
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
