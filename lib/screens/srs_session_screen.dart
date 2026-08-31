import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/user_question_data.dart' show SrsQuality;
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/services/statistics_service.dart';
import 'package:leerlus/services/streak_service.dart';
import 'package:leerlus/screens/question_display/question_display_screen.dart';
import 'package:leerlus/screens/srs_completion_screen.dart';
import 'package:leerlus/utils/question_scramble.dart';

class SrsSessionScreen extends StatefulWidget {
  final List<QuestionData> questions;
  final String sessionTitle;

  /// The full due set [questions] was drawn from, so the completion screen can
  /// offer another batch from the same scope after a capped quick session.
  /// Null means [questions] was already the whole scope.
  final List<QuestionData>? scopePool;

  const SrsSessionScreen({
    super.key,
    required this.questions,
    required this.sessionTitle,
    this.scopePool,
  });

  @override
  State<SrsSessionScreen> createState() => _SrsSessionScreenState();
}

class _SrsSessionScreenState extends State<SrsSessionScreen> {
  final SrsService _srsService = SrsService();

  late final List<QuestionData> _questions;
  int currentIndex = 0;
  int correctAnswers = 0;

  /// Questions answered "Again" this session. They are force-carried into the
  /// continue pool: [SrsService.updateAfterAnswer] applies `lapseMultiplier` to
  /// the current interval, so a lapsed card is rescheduled hours-to-days out
  /// and `getDueQuestions` would otherwise drop it right back out.
  final Set<String> _againIds = {};

  @override
  void initState() {
    super.initState();
    // Present the questions in a random order each session, while keeping
    // chained flashcards (one card's answer being the next card's prompt)
    // from landing back-to-back.
    _questions = scrambleQuestions(widget.questions);
  }

  void _nextQuestion(bool wasCorrect) async {
    if (wasCorrect) correctAnswers++;

    if (currentIndex < _questions.length - 1) {
      setState(() => currentIndex++);
    } else {
      final streakEvent = await StreakService().recordActivity();
      await StatisticsService().recordSessionComplete(true);
      if (correctAnswers == _questions.length) {
        await StatisticsService().recordPerfectSession();
      }
      if (!mounted) return;

      // Lapses first, then whatever else in this scope is still due. Ordering
      // here is only for the pool — takeMostOverdue re-sorts by nextReview.
      final pool = widget.scopePool ?? widget.questions;
      final lapsed =
          _questions.where((q) => _againIds.contains(q.id)).toList();
      final stillDue = _srsService
          .getDueQuestions(pool)
          .where((q) => !_againIds.contains(q.id));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SrsCompletionScreen(
            completedQuizTitle: widget.sessionTitle,
            reviewedCount: _questions.length,
            streakEvent: streakEvent,
            continuePool: [...lapsed, ...stillDue],
            continueScope: pool,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(widget.sessionTitle)),
        body: Center(child: Text(l10n.srsNoQuestionsDue)),
      );
    }

    final question = _questions[currentIndex];

    return QuestionDisplayScreen(
      key: ValueKey(currentIndex),
      question: question,
      spacedRepetitionMode: true,
      questionNumber: currentIndex + 1,
      totalQuestions: _questions.length,
      onContinue: (wasCorrect, quality) async {
        final effective =
            quality ?? (wasCorrect ? null : SrsQuality.again);
        if (effective != null) {
          if (effective == SrsQuality.again) _againIds.add(question.id);
          await StatisticsService().recordSrsQuality(effective);
          await _srsService.updateAfterAnswer(question, effective);
        }
        _nextQuestion(wasCorrect);
      },
    );
  }
}
