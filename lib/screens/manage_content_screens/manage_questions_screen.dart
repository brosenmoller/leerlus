import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/screens/manage_content_screens/edit_question_screen.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';

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
  String? _highlightId;
  bool _pendingScrollToEnd = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _fabFocusNode.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.questionsSubtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
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

          // Scroll to the end once the newly added question appears in the list.
          if (_pendingScrollToEnd &&
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
                itemCount: questions.length,
                itemBuilder: (context, i) {
                  final question = questions[i];
                  final isHighlighted = question.id == _highlightId;
                  return ListTile(
                    tileColor: isHighlighted
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.45)
                        : null,
                    leading: _answerTypeIcon(question.answerType),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: l10n.edit,
                          onPressed: () => _openEditScreen(question),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          tooltip: l10n.delete,
                          onPressed: () => _confirmDelete(context, question),
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
