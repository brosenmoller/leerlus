import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/screens/srs_session_screen.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/services/streak_service.dart';
import 'package:leerlus/widgets/streak_banner.dart';

class SrsCompletionScreen extends StatelessWidget {
  final String completedQuizTitle;
  final int reviewedCount;
  final StreakEvent? streakEvent;

  const SrsCompletionScreen({
    super.key,
    required this.completedQuizTitle,
    required this.reviewedCount,
    this.streakEvent,
  });

  /// Quizzes that still have due questions right now.
  List<({QuizData quiz, List<QuestionData> due})> _dueQuizzes() {
    final qs = QuestionService();
    final srs = SrsService();
    final result = <({QuizData quiz, List<QuestionData> due})>[];

    for (final quiz in qs.getAllQuizzes()) {
      final due = quiz.questionIds
          .map((id) => qs.getQuestion(id))
          .whereType<QuestionData>()
          .where((q) =>
              srs.getUserData(q).spacedRepetitionEnabled &&
              srs.getUserData(q).isDue)
          .toList();
      if (due.isNotEmpty) result.add((quiz: quiz, due: due));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final due = _dueQuizzes();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.srsSessionComplete),
        centerTitle: true,
      ),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Summary ──────────────────────────────────────────────
                const Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  completedQuizTitle,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.srsQuestionsReviewed(reviewedCount),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (streakEvent != null) StreakBanner(event: streakEvent!),
                const SizedBox(height: 16),

                // ── Due quizzes / all-caught-up ───────────────────────────
                if (due.isEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        l10n.srsAllCaughtUp,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.srsNoMoreDue,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    l10n.srsStillDue,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ...due.map((entry) => _DueQuizTile(
                        quizTitle: entry.quiz.title,
                        dueCount: entry.due.length,
                        onStart: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SrsSessionScreen(
                              questions: entry.due,
                              sessionTitle: entry.quiz.title,
                            ),
                          ),
                        ),
                      )),
                ],

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.srsBackToSpacedRepetition),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _DueQuizTile extends StatelessWidget {
  final String quizTitle;
  final int dueCount;
  final VoidCallback onStart;

  const _DueQuizTile({
    required this.quizTitle,
    required this.dueCount,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(quizTitle),
        subtitle: Text(l10n.srsQuestionsDue(dueCount)),
        trailing: FilledButton(
          onPressed: onStart,
          child: Text(l10n.start),
        ),
      ),
    );
  }
}
