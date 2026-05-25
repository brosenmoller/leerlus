import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/screens/manage_content_screens/edit_question_screen.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';

class ManageQuestionsScreen extends StatelessWidget {
  final AppDatabase db;
  final Quiz quiz;

  const ManageQuestionsScreen({
    super.key,
    required this.db,
    required this.quiz,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.title),
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
        icon: const Icon(Icons.add),
        label: Text(l10n.addQuestion),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditQuestionScreen(
              quizId: quiz.id,
              db: db,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Question>>(
        stream: db.watchQuestionsForQuiz(quiz.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final questions = snapshot.data!;
          if (questions.isEmpty) {
            return Center(child: Text(l10n.noQuestionsYet));
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: questions.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              await db.reorderQuestion(
                  quizId: quiz.id,
                  questionId: questions[oldIndex].id,
                  newIndex: newIndex);
            },
            itemBuilder: (context, i) {
              final question = questions[i];
              return ListTile(
                key: ValueKey(question.id),
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
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditQuestionScreen(
                            quizId: quiz.id,
                            db: db,
                            question: question,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: l10n.delete,
                      onPressed: () => _confirmDelete(context, question),
                    ),
                    const Icon(Icons.drag_handle),
                  ],
                ),
              );
            },
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
              await db.deleteQuestion(q.id);
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
