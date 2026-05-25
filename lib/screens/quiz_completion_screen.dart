import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/screens/home_screen.dart';
import 'package:leerlus/screens/quiz_session_screen.dart';
import 'package:leerlus/services/streak_service.dart';
import 'package:leerlus/widgets/streak_banner.dart';

class QuizCompletionScreen extends StatelessWidget {
  final String quizName;
  final int correctAnswers;
  final int totalQuestions;
  /// Passed so the Retry button can restart the same quiz.
  final QuizData? quizData;
  final StreakEvent? streakEvent;

  const QuizCompletionScreen({
    super.key,
    required this.quizName,
    required this.correctAnswers,
    required this.totalQuestions,
    this.quizData,
    this.streakEvent,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percentage =
        ((correctAnswers / totalQuestions) * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.quizCompleted),
        centerTitle: true,
      ),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            Navigator.pop(context);
          }
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  if (streakEvent != null) StreakBanner(event: streakEvent!),
                  Text(
                    quizName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '$correctAnswers / $totalQuestions',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$percentage%',
                    style: const TextStyle(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (quizData != null)
                    FilledButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QuizSessionScreen(quizData: quizData!),
                        ),
                      ),
                      icon: const Icon(Icons.replay),
                      label: Text(l10n.retry),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.back),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) =>
                            HomeScreen(db: AppDatabase.instance),
                      ),
                      (r) => false,
                    ),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(l10n.home),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
