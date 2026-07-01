import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/screens/manage_content_screens/edit_question_screen.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';

class ManageQuestionsScreen extends StatefulWidget {
  final AppDatabase db;
  final Quiz quiz;

  const ManageQuestionsScreen({
    super.key,
    required this.db,
    required this.quiz,
  });

  @override
  State<ManageQuestionsScreen> createState() => _ManageQuestionsScreenState();
}

class _ManageQuestionsScreenState extends State<ManageQuestionsScreen> {
  final _scrollController = ScrollController();
  final _fabFocusNode = FocusNode();
  final _searchController = TextEditingController();
  String? _highlightId;
  bool _pendingScrollToEnd = false;
  bool _searching = false;
  String _query = '';
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  List<Question> _visibleQuestions = const [];

  @override
  void dispose() {
    _scrollController.dispose();
    _fabFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _stopSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
  }

  void _enterSelection(String id) {
    _selectionMode = true;
    _selectedIds.add(id);
  }

  void _toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    if (_selectedIds.isEmpty) _selectionMode = false;
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<Question> filtered) {
    setState(() {
      final ids = filtered.map((q) => q.id).toSet();
      final allSelected = ids.every(_selectedIds.contains);
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  Future<void> _openAddScreen() async {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditQuestionScreen(
          quizId: widget.quiz.id,
          db: widget.db,
        ),
      ),
    );
    _handleSaveResult(result);
  }

  Future<void> _openEditScreen(Question question) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditQuestionScreen(
          quizId: widget.quiz.id,
          db: widget.db,
          question: question,
        ),
      ),
    );
    _handleSaveResult(result);
  }

  void _handleSaveResult(Map<String, dynamic>? result) {
    if (result == null || !mounted) return;
    final id = result['id'] as String;
    final isNew = result['isNew'] as bool;
    setState(() {
      _highlightId = id;
      _pendingScrollToEnd = isNew;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlightId = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fabFocusNode.requestFocus();
    });
  }

  AppBar _buildAppBar(AppLocalizations l10n) {
    return AppBar(
      title: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              onTap: collapseSelectionOnTap(_searchController),
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: l10n.searchQuestionsHint,
                border: InputBorder.none,
              ),
            )
          : Text(widget.quiz.title),
      actions: _searching
          ? [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.searchTooltip,
                onPressed: _stopSearch,
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: l10n.selectItems,
                onPressed: () => setState(() => _selectionMode = true),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: l10n.searchTooltip,
                onPressed: () => setState(() => _searching = true),
              ),
            ],
      bottom: _searching
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(20),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.questionsSubtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
    );
  }

  AppBar _buildSelectionAppBar(AppLocalizations l10n) {
    final hasSelection = _selectedIds.isNotEmpty;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.cancel,
        onPressed: _exitSelection,
      ),
      title: Text(l10n.nSelected(_selectedIds.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: l10n.selectAll,
          onPressed: () => _selectAll(_visibleQuestions),
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move_outline),
          tooltip: l10n.moveToQuizMenu,
          onPressed: hasSelection ? _bulkMove : null,
        ),
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: l10n.duplicate,
          onPressed: hasSelection ? _bulkDuplicate : null,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline,
              color: hasSelection ? Colors.red : null),
          tooltip: l10n.delete,
          onPressed: hasSelection ? _bulkDelete : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: _selectionMode ? _buildSelectionAppBar(l10n) : _buildAppBar(l10n),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              focusNode: _fabFocusNode,
              icon: const Icon(Icons.add),
              label: Text(l10n.addQuestion),
              onPressed: _openAddScreen,
            ),
      body: StreamBuilder<List<Question>>(
        stream: widget.db.watchQuestionsForQuiz(widget.quiz.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final questions = snapshot.data!;
          if (questions.isEmpty) {
            return Center(child: Text(l10n.noQuestionsYet));
          }

          final query = _query.toLowerCase().trim();
          final filtered = query.isEmpty
              ? questions
              : questions
                  .where(
                      (q) => q.questionText.toLowerCase().contains(query))
                  .toList();

          if (filtered.isEmpty) {
            return Center(child: Text(l10n.searchNoResults));
          }

          // Keep the visible list available for the "select all" action, and
          // drop any selected ids that are no longer present (e.g. after a
          // delete or move updates the stream).
          _visibleQuestions = filtered;
          if (_selectionMode) {
            final visibleIds = questions.map((q) => q.id).toSet();
            _selectedIds.removeWhere((id) => !visibleIds.contains(id));
          }

          // Scroll to the end once the newly added question appears in the list.
          if (query.isEmpty &&
              _pendingScrollToEnd &&
              questions.any((q) => q.id == _highlightId)) {
            _pendingScrollToEnd = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                );
              }
            });
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final question = filtered[i];
                  final isHighlighted = question.id == _highlightId;
                  final isSelected = _selectedIds.contains(question.id);
                  return ListTile(
                    tileColor: isHighlighted || isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.45)
                        : null,
                    onTap: _selectionMode
                        ? () => setState(() => _toggleSelection(question.id))
                        : () => _openEditScreen(question),
                    onLongPress: _selectionMode
                        ? null
                        : () =>
                            setState(() => _enterSelection(question.id)),
                    leading: _selectionMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (_) => setState(
                                () => _toggleSelection(question.id)),
                          )
                        : _answerTypeIcon(question.answerType),
                    title: Text(
                      question.questionText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        _answerTypeChip(question.answerType, l10n),
                      ],
                    ),
                    trailing: _selectionMode
                        ? null
                        : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 'delete':
                            _confirmDelete(context, question);
                          case 'duplicate':
                            _duplicateQuestion(question);
                          case 'move':
                            _moveQuestionToQuiz(question);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              const Icon(Icons.copy_outlined),
                              const SizedBox(width: 12),
                              Text(l10n.duplicate),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'move',
                          child: Row(
                            children: [
                              const Icon(Icons.drive_file_move_outline),
                              const SizedBox(width: 12),
                              Text(l10n.moveToQuizMenu),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              const SizedBox(width: 12),
                              Text(l10n.delete,
                                  style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _answerTypeIcon(String type) {
    return switch (type) {
      'multipleChoice' => const CircleAvatar(
          child: Icon(Icons.list, size: 18),
        ),
      'typed' => const CircleAvatar(
          child: Icon(Icons.keyboard, size: 18),
        ),
      'imageClick' => const CircleAvatar(
          child: Icon(Icons.touch_app, size: 18),
        ),
      'sorting' => const CircleAvatar(
          child: Icon(Icons.sort, size: 18),
        ),
      _ => const CircleAvatar(child: Icon(Icons.help, size: 18)),
    };
  }

  Widget _answerTypeChip(String type, AppLocalizations l10n) {
    final label = switch (type) {
      'multipleChoice' => l10n.answerTypeMultipleChoiceChip,
      'typed'          => l10n.answerTypeTypedChip,
      'imageClick'     => l10n.answerTypeImageClickChip,
      'sorting'        => l10n.answerTypeSortingChip,
      'set'            => l10n.answerTypeSetChip,
      _                => type,
    };
    return _Chip(label: label, color: Colors.blue);
  }

  Future<void> _duplicateQuestion(Question q) async {
    // Copy every field except the id so insertQuestion mints a fresh UUID,
    // making the copy a fully independent question.
    final newId = await widget.db.insertQuestionIntoQuiz(
      quizId: widget.quiz.id,
      question: QuestionsCompanion(
        questionText: Value(q.questionText),
        questionVariants: Value(q.questionVariants),
        answerType: Value(q.answerType),
        answerConfig: Value(q.answerConfig),
        explanation: Value(q.explanation),
        imagePath: Value(q.imagePath),
        imagePathVariants: Value(q.imagePathVariants),
        occlusionConfig: Value(q.occlusionConfig),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await QuestionService().refresh();
    await SrsService().enrollIfQuizEnabled(widget.quiz.id, newId);
    _handleSaveResult({'id': newId, 'isNew': true});
  }

  Future<void> _moveQuestionToQuiz(Question q) async {
    final l10n = AppLocalizations.of(context);
    final targetId = await _showMoveToQuizDialog(
      context: context,
      db: widget.db,
      excludeQuizId: widget.quiz.id,
    );
    if (targetId == null || !mounted) return;
    await widget.db.moveQuestionToQuiz(
      questionId: q.id,
      fromQuizId: widget.quiz.id,
      toQuizId: targetId,
    );
    await QuestionService().refresh();
    // SRS data is keyed by questionId and travels with the card; enroll it if the
    // target quiz already has SRS on. Never delete its progress.
    await SrsService().enrollIfQuizEnabled(targetId, q.id);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.moveQuestionDone)));
    }
  }

  void _confirmDelete(BuildContext context, Question q) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteQuestionTitle),
        content: Text('"${q.questionText}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await widget.db.deleteQuestion(q.id);
              await SrsService().deleteUserData(q.id);
              await QuestionService().refresh();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  // ── Bulk actions (selection mode) ────────────────────────────────────────

  Future<void> _bulkDelete() async {
    final l10n = AppLocalizations.of(context);
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteNQuestionsTitle(ids.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in ids) {
      await widget.db.deleteQuestion(id);
      await SrsService().deleteUserData(id);
    }
    await QuestionService().refresh();
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteNQuestionsDone(ids.length))));
  }

  Future<void> _bulkMove() async {
    final l10n = AppLocalizations.of(context);
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final targetId = await _showMoveToQuizDialog(
      context: context,
      db: widget.db,
      excludeQuizId: widget.quiz.id,
    );
    if (targetId == null || !mounted) return;
    for (final id in ids) {
      await widget.db.moveQuestionToQuiz(
        questionId: id,
        fromQuizId: widget.quiz.id,
        toQuizId: targetId,
      );
      // SRS data travels with the card; enroll it if the target quiz has SRS on.
      await SrsService().enrollIfQuizEnabled(targetId, id);
    }
    await QuestionService().refresh();
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.moveNQuestionsDone(ids.length))));
  }

  Future<void> _bulkDuplicate() async {
    final l10n = AppLocalizations.of(context);
    final ids = _selectedIds.toSet();
    if (ids.isEmpty) return;
    final all = await widget.db.getQuestionsForQuiz(widget.quiz.id);
    final toCopy = all.where((q) => ids.contains(q.id)).toList();
    for (final q in toCopy) {
      // Copy every field except the id so a fresh UUID is minted per copy.
      final newId = await widget.db.insertQuestionIntoQuiz(
        quizId: widget.quiz.id,
        question: QuestionsCompanion(
          questionText: Value(q.questionText),
          questionVariants: Value(q.questionVariants),
          answerType: Value(q.answerType),
          answerConfig: Value(q.answerConfig),
          explanation: Value(q.explanation),
          imagePath: Value(q.imagePath),
          imagePathVariants: Value(q.imagePathVariants),
          occlusionConfig: Value(q.occlusionConfig),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await SrsService().enrollIfQuizEnabled(widget.quiz.id, newId);
    }
    await QuestionService().refresh();
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.duplicateNQuestionsDone(toCopy.length))));
  }
}

// ── Move-to-quiz picker dialog ─────────────────────────────────────────────────

/// Shows a searchable flat list of quizzes (excluding [excludeQuizId]), each with
/// its folder name as a subtitle. Returns the chosen quiz id, or null on cancel.
Future<String?> _showMoveToQuizDialog({
  required BuildContext context,
  required AppDatabase db,
  required String excludeQuizId,
}) async {
  final l10n = AppLocalizations.of(context);
  final allQuizzes = await db.getAllQuizzes();
  final available =
      allQuizzes.where((q) => q.id != excludeQuizId).toList();

  if (!context.mounted) return null;

  if (available.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.moveToQuizTitle),
        content: Text(l10n.moveNoOtherQuizzes),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    return null;
  }

  final folders = await db.getAllFolders();
  if (!context.mounted) return null;
  final folderTitles = {for (final f in folders) f.id: f.title};

  final searchController = TextEditingController();
  var query = '';
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.moveToQuizTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (ctx, setDialogState) {
              final q = query.toLowerCase().trim();
              final filtered = q.isEmpty
                  ? available
                  : available
                      .where((quiz) => quiz.title.toLowerCase().contains(q))
                      .toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    onTap: collapseSelectionOnTap(searchController),
                    onChanged: (value) =>
                        setDialogState(() => query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.moveToQuizSearchHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(l10n.searchNoResults),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: filtered.map((quiz) {
                              final folderTitle = quiz.folderId == null
                                  ? l10n.moveToQuizNoFolder
                                  : folderTitles[quiz.folderId] ??
                                      l10n.moveToQuizNoFolder;
                              return ListTile(
                                leading: const Icon(Icons.quiz_outlined),
                                title: Text(quiz.title),
                                subtitle: Text(folderTitle),
                                onTap: () => Navigator.pop(ctx, quiz.id),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  } finally {
    searchController.dispose();
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9))),
    );
  }
}
