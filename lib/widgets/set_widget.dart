import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/answer_configs.dart';
import 'package:leerlus/models/answer_state.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/widgets/question_image.dart';

class SetWidget extends StatefulWidget {
  final QuestionData question;
  final Function(bool isCorrect) onAnswered;
  final bool locked;
  final AnswerState answerState;

  const SetWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    required this.locked,
    required this.answerState,
  });

  @override
  State<SetWidget> createState() => _SetWidgetState();
}

class _SetWidgetState extends State<SetWidget> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final _widgetFocus = FocusNode();

  final List<String> _entered = [];

  // null before submit; per-entry matched canonical answer (or null = wrong)
  List<String?>? _matches;
  List<String>? _missed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    _widgetFocus.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final alreadyEntered = _entered.any(
      (e) => e.toLowerCase() == text.toLowerCase(),
    );
    if (alreadyEntered) {
      _inputController.clear();
      return;
    }

    setState(() => _entered.add(text));
    _inputController.clear();
    _inputFocus.requestFocus();
  }

  void _removeItem(int index) {
    setState(() => _entered.removeAt(index));
  }

  void _submit() {
    if (_entered.isEmpty) return;
    final config = widget.question.setConfig!;
    final remaining = List<String>.from(config.answers);

    final matches = <String?>[
      for (final entry in _entered) SetConfig.claimMatch(entry, remaining),
    ];

    setState(() {
      _matches = matches;
      _missed = List<String>.from(remaining);
    });

    widget.onAnswered(_missed!.isEmpty && matches.every((m) => m != null));
  }

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // Key handler for the TextField: Shift+Enter adds, Enter submits (desktop only).
  KeyEventResult _handleInputKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
    if (widget.locked || _matches != null) return KeyEventResult.ignored;

    if (HardwareKeyboard.instance.isShiftPressed) {
      _addItem();
    } else if (!_isMobile) {
      if (_entered.isNotEmpty) _submit();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSubmitted = _matches != null;
    final showSubmitButton = widget.answerState == AnswerState.unanswered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.question.imagePath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: QuestionImage(
              path: widget.question.imagePath!,
              maxHeight: 180,
              occlusionData: widget.question.occlusionData,
              occlusionRevealed: widget.answerState != AnswerState.unanswered,
            ),
          ),

        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                children: [
                  if (!isSubmitted) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Focus(
                            onKeyEvent: _handleInputKey,
                            child: TextField(
                              controller: _inputController,
                              focusNode: _inputFocus,
                              readOnly: widget.locked,
                              // Mobile: Enter key adds the item.
                              // Desktop: suppress default Enter so our onKeyEvent
                              // handler owns both Shift+Enter (add) and Enter (submit).
                              textInputAction: _isMobile
                                  ? TextInputAction.done
                                  : TextInputAction.none,
                              onSubmitted: _isMobile && !widget.locked
                                  ? (_) => _addItem()
                                  : null,
                              decoration: InputDecoration(
                                hintText: l10n.setHint,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: widget.locked ? null : _addItem,
                          child: Text(l10n.setAdd),
                        ),
                      ],
                    ),
                    if (_entered.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _entered.asMap().entries.map((e) {
                          return Chip(
                            label: Text(e.value),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted:
                                widget.locked ? null : () => _removeItem(e.key),
                          );
                        }).toList(),
                      ),
                    ],
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _entered.asMap().entries.map((e) {
                        final correct = _matches![e.key] != null;
                        return Chip(
                          avatar: Icon(
                            correct ? Icons.check : Icons.close,
                            size: 16,
                            color: correct
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          label: Text(e.value),
                          backgroundColor: correct
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          side: BorderSide(
                            color: correct
                                ? Colors.green.shade300
                                : Colors.red.shade300,
                          ),
                        );
                      }).toList(),
                    ),

                    if (_missed!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.setMissed,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _missed!
                            .map(
                              (answer) => Chip(
                                label: Text(answer),
                                backgroundColor: Colors.grey.shade100,
                                side: BorderSide(color: Colors.grey.shade400),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),

        if (showSubmitButton && !isSubmitted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Center(
              child: FilledButton(
                onPressed: _entered.isEmpty ? null : _submit,
                child: Text(l10n.confirm),
              ),
            ),
          ),
      ],
    );
  }
}
