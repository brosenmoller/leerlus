import 'dart:math';
import 'package:flutter/foundation.dart';
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
  late bool _manualAddItems;

  // Drag mode: current arrangement of item text
  late List<String> _currentOrder;

  // Type mode: one controller per entry, in the student's chosen order.
  late List<TextEditingController> _typeControllers;

  // Type mode (manual): input for adding a new entry.
  final _manualInputController = TextEditingController();
  final _manualInputFocus = FocusNode();

  // null = not yet checked. Drag mode: one bool per correct position. Type mode:
  // one bool per entered row.
  List<bool>? _correctness;
  bool _allCorrect = false;

  late final FocusNode _focusNode;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    final config = widget.question.sortingConfig!;
    _showPreFilled = config.showPreFilled;
    _manualAddItems = config.manualAddItems;

    if (_showPreFilled) {
      _currentOrder = List.from(config.items)..shuffle(Random());
      _typeControllers = [];
    } else {
      _currentOrder = [];
      _typeControllers = _manualAddItems
          ? []
          : List.generate(
              config.items.length, (_) => TextEditingController());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_showPreFilled && _manualAddItems) {
        _manualInputFocus.requestFocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _manualInputController.dispose();
    _manualInputFocus.dispose();
    for (final c in _typeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _checkAnswer() {
    if (widget.locked || _correctness != null) return;
    final config = widget.question.sortingConfig!;

    if (_showPreFilled) {
      final correctness = List.generate(
        config.items.length,
        (i) => _currentOrder[i] == config.items[i],
      );
      final allCorrect = correctness.every((c) => c);
      setState(() {
        _correctness = correctness;
        _allCorrect = allCorrect;
      });
      widget.onAnswered(allCorrect);
    } else {
      final correctness = List.generate(
        _typeControllers.length,
        (i) =>
            i < config.items.length &&
            config.matchesAt(i, _typeControllers[i].text.trim()),
      );
      // Extra or missing entries also make the answer wrong, so the entry count
      // must match the number of items exactly.
      final allCorrect = _typeControllers.length == config.items.length &&
          correctness.every((c) => c);
      setState(() {
        _correctness = correctness;
        _allCorrect = allCorrect;
      });
      widget.onAnswered(allCorrect);
    }
  }

  // ── Type mode helpers ────────────────────────────────────────────────────

  void _addManualEntry() {
    if (widget.locked || _correctness != null) return;
    final text = _manualInputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _typeControllers.add(TextEditingController(text: text)));
    _manualInputController.clear();
    _manualInputFocus.requestFocus();
  }

  void _removeEntry(int index) {
    if (widget.locked || _correctness != null) return;
    setState(() => _typeControllers.removeAt(index).dispose());
  }

  void _reorderEntry(int oldIndex, int newIndex) {
    if (widget.locked || _correctness != null) return;
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final c = _typeControllers.removeAt(oldIndex);
      _typeControllers.insert(newIndex, c);
    });
  }

  // Enter/done in the manual input adds the entry (and, on desktop, is consumed
  // so the surrounding Enter-to-check handler doesn't also fire).
  KeyEventResult _handleManualInputKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (widget.locked || _correctness != null) return KeyEventResult.ignored;
    _addManualEntry();
    return KeyEventResult.handled;
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
                occlusionData: widget
                    .question.occlusionDataByImage[widget.question.imagePath],
                occlusionRevealed:
                    widget.answerState != AnswerState.unanswered,
              ),
            ),

          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _showPreFilled
                    ? _buildDragList(context)
                    : _buildTypeSection(context),
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
    if (_correctness == null || _allCorrect) return null;
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

  // Small numbered position badge reused by the type editor and results.
  Widget _positionBadge(BuildContext context, int i) {
    return SizedBox(
      width: 28,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Theme.of(context).colorScheme.primary),
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
      itemBuilder: (context, index) => _buildDragItem(context, index, l10n),
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

  Widget _buildTypeSection(BuildContext context) {
    if (_correctness == null) return _buildTypeEditor(context);
    return _buildTypeResults(context);
  }

  Widget _buildTypeEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_manualAddItems)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildManualInputRow(context),
          ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            buildDefaultDragHandles: false,
            onReorder: _reorderEntry,
            itemCount: _typeControllers.length,
            itemBuilder: (context, index) =>
                _buildTypeEditorItem(context, index),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInputRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Focus(
            onKeyEvent: _handleManualInputKey,
            child: TextField(
              controller: _manualInputController,
              focusNode: _manualInputFocus,
              readOnly: widget.locked,
              onTap: collapseSelectionOnTap(_manualInputController),
              // Mobile: the Enter/done key adds the entry. Desktop: suppress the
              // default so our onKeyEvent handler owns Enter.
              textInputAction:
                  _isMobile ? TextInputAction.done : TextInputAction.none,
              onSubmitted:
                  _isMobile && !widget.locked ? (_) => _addManualEntry() : null,
              decoration: InputDecoration(
                hintText: l10n.sortingEntryHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: widget.locked ? null : _addManualEntry,
          child: Text(l10n.addItem),
        ),
      ],
    );
  }

  Widget _buildTypeEditorItem(BuildContext context, int i) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: ValueKey(_typeControllers[i]),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _positionBadge(context, i),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _typeControllers[i],
              readOnly: widget.locked,
              onTap: collapseSelectionOnTap(_typeControllers[i]),
              decoration: InputDecoration(
                labelText: l10n.sortingItemN(i + 1),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (_manualAddItems)
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: widget.locked ? Colors.grey : Colors.red,
              ),
              onPressed: widget.locked ? null : () => _removeEntry(i),
            ),
          ReorderableDragStartListener(
            index: i,
            enabled: !widget.locked,
            child: Icon(
              Icons.drag_handle,
              color: widget.locked
                  ? Colors.grey
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeResults(BuildContext context) {
    final config = widget.question.sortingConfig!;
    final hint = _buildIncorrectHint(context);
    final rowCount = max(_typeControllers.length, config.items.length);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      children: [
        for (var i = 0; i < rowCount; i++) _buildTypeResultItem(context, i),
        ?hint,
      ],
    );
  }

  Widget _buildTypeResultItem(BuildContext context, int i) {
    final l10n = AppLocalizations.of(context);
    final config = widget.question.sortingConfig!;
    final hasEntry = i < _typeControllers.length;
    final entered = hasEntry ? _typeControllers[i].text.trim() : '';
    final correctItem = i < config.items.length ? config.items[i] : null;
    final isCorrect =
        hasEntry && i < (_correctness?.length ?? 0) && _correctness![i];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _positionBadge(context, i),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
                color: isCorrect ? Colors.green.withValues(alpha: 0.1) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entered.isEmpty ? '—' : entered,
                          style: TextStyle(
                            color: entered.isEmpty ? Colors.grey : null,
                          ),
                        ),
                      ),
                      Icon(
                        isCorrect
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 18,
                        color: isCorrect
                            ? Colors.green.shade600
                            : Theme.of(context).colorScheme.error,
                      ),
                    ],
                  ),
                  if (!isCorrect && correctItem != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.sortingCorrectAnswer(correctItem),
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
