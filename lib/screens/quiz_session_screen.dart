import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/statistics_service.dart';
import 'package:leerlus/services/streak_service.dart';
import 'package:leerlus/screens/question_display/question_display_screen.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/screens/quiz_completion_screen.dart';

class QuizSessionScreen extends StatefulWidget {
  final QuizData? quizData;
  final List<QuestionData>? overrideQuestions;
  final String? sessionTitle;
  final bool shuffle;

  const QuizSessionScreen({
    super.key,
    this.quizData,
    this.overrideQuestions,
    this.sessionTitle,
    this.shuffle = true,
  }) : assert(quizData != null || overrideQuestions != null,
            'Provide either quizData or overrideQuestions');

  @override
  State<QuizSessionScreen> createState() =>
      _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  final QuestionService service = QuestionService();

  late List<QuestionData> questions = [];
  int currentIndex = 0;
  int correctAnswers = 0;
  int totalQuestions = 0;

  @override
  void initState() {
    super.initState();

    questions = widget.overrideQuestions != null
        ? List.of(widget.overrideQuestions!)
        : service.getQuestionsForQuiz(widget.quizData!.id);
    totalQuestions = questions.length;

    if (widget.shuffle) {
      questions.shuffle();
    }
  }

  void _nextQuestion(bool wasCorrect) async {
    if (wasCorrect) {
      correctAnswers++;
    }

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
      });
    } else {
      final streakEvent = await StreakService().recordActivity();
      await StatisticsService().recordSessionComplete(false);
      if (correctAnswers == totalQuestions) {
        await StatisticsService().recordPerfectSession();
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizCompletionScreen(
            quizName: widget.quizData?.title ?? widget.sessionTitle ?? '',
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            quizData: widget.quizData,
            streakEvent: streakEvent,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noQuestions)),
      );
    }

    return QuestionDisplayScreen(
      key: ValueKey(currentIndex),
      question: questions[currentIndex],
      spacedRepetitionMode: false,
      onContinue: (wasCorrect, _) {
        _nextQuestion(wasCorrect);
      },
    );
  }
}
