import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/answer_state.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';
import 'package:leerlus/widgets/question_image.dart';

class SortingWidget extends StatefulWidget {
  final QuestionData question;
  final Function(bool isCorrect) onAnswered;
  final bool locked;
  final AnswerState answerState;

  const SortingWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    required this.locked,
    required this.answerState,
  });

  @override
  State<SortingWidget> createState() => _SortingWidgetState();
}

class _SortingWidgetState extends State<SortingWidget> {
  late bool _showPreFilled;

  // Drag mode: current arrangement of item text
  late List<String> _currentOrder;

  // Type mode: one controller per item slot
  late List<TextEditingController> _typeControllers;

  // null = not yet checked; per-index bool after checking
  List<bool>? _correctness;

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    final config = widget.question.sortingConfig!;
    _showPreFilled = config.showPreFilled;

    if (_showPreFilled) {
      _currentOrder = List.from(config.items)..shuffle(Random());
      _typeControllers = [];
    } else {
      _currentOrder = [];
      _typeControllers = List.generate(
          config.items.length, (_) => TextEditingController());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    for (final c in _typeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _checkAnswer() {
    if (widget.locked) return;
    final config = widget.question.sortingConfig!;

    if (_showPreFilled) {
      final correctness = List.generate(
        config.items.length,
        (i) => _currentOrder[i] == config.items[i],
      );
      setState(() => _correctness = correctness);
      widget.onAnswered(correctness.every((c) => c));
    } else {
      final correctness = List.generate(
        config.items.length,
        (i) => _typeControllers[i].text.trim().toLowerCase() ==
            config.items[i].toLowerCase(),
      );
      setState(() => _correctness = correctness);
      widget.onAnswered(correctness.every((c) => c));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showCheckButton = widget.answerState == AnswerState.unanswered;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            !widget.locked &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          _checkAnswer();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.question.imagePath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: QuestionImage(
              path: widget.question.imagePath!,
              maxHeight: 180,
              occlusionData: widget.question.occlusionDataByImage[widget.question.imagePath],
              occlusionRevealed: widget.answerState != AnswerState.unanswered,
            ),
          ),

        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _showPreFilled
                  ? _buildDragList(context)
                  : _buildTypeList(context),
            ),
          ),
        ),

        if (showCheckButton)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Center(
              child: FilledButton(
                onPressed: _checkAnswer,
                child: Text(l10n.confirm),
              ),
            ),
          ),
      ],
    ),
    );
  }

  // Shown directly below the tiles once an incorrect answer is checked.
  Widget? _buildIncorrectHint(BuildContext context) {
    final correctness = _correctness;
    if (correctness == null || correctness.every((c) => c)) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Text(
        AppLocalizations.of(context).sortingIncorrectHint,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
      ),
    );
  }

  // ── Drag mode ──────────────────────────────────────────────────────────────

  Widget _buildDragList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isChecked = _correctness != null;
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      footer: _buildIncorrectHint(context),
      onReorder: (oldIndex, newIndex) {
        if (widget.locked || isChecked) return;
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _currentOrder.removeAt(oldIndex);
          _currentOrder.insert(newIndex, item);
        });
      },
      itemCount: _currentOrder.length,
      itemBuilder: (context, index) =>
          _buildDragItem(context, index, l10n),
    );
  }

  Widget _buildDragItem(BuildContext context, int index, AppLocalizations l10n) {
    final config = widget.question.sortingConfig!;
    final isChecked = _correctness != null;
    final isCorrect = _correctness?[index] ?? false;
    final dragLocked = widget.locked || isChecked;

    // Only correct slots are highlighted (green). An unplaced item isn't "wrong",
    // so it keeps the default colors and instead reveals what belongs here.
    Color? tileColor;
    Color? textColor;
    if (isChecked && isCorrect) {
      tileColor = Colors.green.shade600;
      textColor = Colors.white;
    }

    return Card(
      key: ValueKey('drag_${_currentOrder[index]}'),
      margin: const EdgeInsets.only(bottom: 8),
      color: tileColor,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (textColor ?? Theme.of(context).colorScheme.onSurface)
                .withValues(alpha: 0.12),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: textColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        title: Text(
          _currentOrder[index],
          style: TextStyle(color: textColor),
        ),
        subtitle: (isChecked && !isCorrect)
            ? Text(l10n.sortingCorrectAnswer(config.items[index]))
            : null,
        trailing: ReorderableDragStartListener(
          index: index,
          enabled: !dragLocked,
          child: Icon(
            Icons.drag_handle,
            color: dragLocked
                ? (textColor ?? Colors.grey)
                : (textColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  // ── Type mode ──────────────────────────────────────────────────────────────

  Widget _buildTypeList(BuildContext context) {
    final config = widget.question.sortingConfig!;
    final hint = _buildIncorrectHint(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      children: [
        for (var i = 0; i < config.items.length; i++)
          _buildTypeItem(context, i, config.items[i]),
        ?hint,
      ],
    );
  }

  Widget _buildTypeItem(BuildContext context, int i, String correctAnswer) {
    final l10n = AppLocalizations.of(context);
    final isChecked = _correctness != null;
    final isCorrect = _correctness?[i] ?? false;

    // Only correct fields are highlighted (green). An unentered answer isn't
    // "wrong", so it keeps the default color and just reveals the correct answer.
    Color? fillColor;
    if (isChecked && isCorrect) {
      fillColor = Colors.green.withValues(alpha: 0.1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: 28,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _typeControllers[i],
              readOnly: widget.locked,
              onTap: collapseSelectionOnTap(_typeControllers[i]),
              decoration: InputDecoration(
                labelText: l10n.sortingItemN(i + 1),
                border: const OutlineInputBorder(),
                filled: fillColor != null,
                fillColor: fillColor,
                helperText: (isChecked && !isCorrect)
                    ? l10n.sortingCorrectAnswer(correctAnswer)
                    : null,
                helperStyle: const TextStyle(color: Colors.green),
                suffixIcon: (isChecked && isCorrect)
                    ? Icon(
                        Icons.check_circle_outline,
                        color: Colors.green.shade600,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
