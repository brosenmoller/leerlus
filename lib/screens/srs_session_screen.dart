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

  const SrsSessionScreen({
    super.key,
    required this.questions,
    required this.sessionTitle,
  });

  @override
  State<SrsSessionScreen> createState() => _SrsSessionScreenState();
}

class _SrsSessionScreenState extends State<SrsSessionScreen> {
  final SrsService _srsService = SrsService();

  late final List<QuestionData> _questions;
  int currentIndex = 0;
  int correctAnswers = 0;

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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SrsCompletionScreen(
            completedQuizTitle: widget.sessionTitle,
            reviewedCount: _questions.length,
            streakEvent: streakEvent,
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
      onContinue: (wasCorrect, quality) async {
        if (quality != null) {
          await StatisticsService().recordSrsQuality(quality);
          await _srsService.updateAfterAnswer(question, quality);
        } else if (!wasCorrect) {
          await StatisticsService().recordSrsQuality(SrsQuality.again);
          await _srsService.updateAfterAnswer(question, SrsQuality.again);
        }
        _nextQuestion(wasCorrect);
      },
    );
  }
}
