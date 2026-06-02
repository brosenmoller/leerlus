import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/screens/quiz_session_screen.dart';
import 'package:leerlus/screens/srs_session_screen.dart';
import 'package:leerlus/screens/srs_overview/srs_quiz_card.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/widgets/collapsible_app_bar_title.dart';

class SrsOverviewScreen extends StatefulWidget {
  const SrsOverviewScreen({super.key});

  @override
  State<SrsOverviewScreen> createState() => _SrsOverviewScreenState();
}

class _SrsOverviewScreenState extends State<SrsOverviewScreen> {
  final QuestionService questionService = QuestionService();
  final SrsService srsService = SrsService();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = <SrsQuizEntry>[];

    for (final quiz in questionService.getAllQuizzes()) {
      final questions = quiz.questionIds
          .map((id) => questionService.getQuestion(id))
          .whereType<QuestionData>()
          .where((q) => srsService.getUserData(q).spacedRepetitionEnabled)
          .toList();

      if (questions.isEmpty) continue;

      final dueQuestions =
          questions.where((q) => srsService.getUserData(q).isDue).toList();

      final dueDates =
          dueQuestions.map((q) => srsService.getUserData(q).nextReview);

      final DateTime? oldestDue = dueQuestions.isEmpty
          ? null
          : dueDates.reduce((a, b) => a.isBefore(b) ? a : b);

      final upcomingDates =
          questions.map((q) => srsService.getUserData(q).nextReview);
      final DateTime nextUpcoming =
          upcomingDates.reduce((a, b) => a.isBefore(b) ? a : b);

      final folderTitle = quiz.parentFolderId != null
          ? questionService.getFolder(quiz.parentFolderId!)?.title
          : null;

      entries.add(SrsQuizEntry(
        quiz: quiz,
        quizTitle: quiz.title,
        folderTitle: folderTitle,
        dueQuestions: dueQuestions,
        allQuestions: questions,
        oldestDue: oldestDue,
        nextUpcoming: nextUpcoming,
      ));
    }

    // Due entries first (most overdue at top), then upcoming (soonest first).
    entries.sort((a, b) {
      final aDue = a.oldestDue != null;
      final bDue = b.oldestDue != null;
      if (aDue && bDue) return a.oldestDue!.compareTo(b.oldestDue!);
      if (aDue) return -1;
      if (bDue) return 1;
      return a.nextUpcoming.compareTo(b.nextUpcoming);
    });

    final colorScheme = Theme.of(context).colorScheme;

    final allDueQuestions = entries
        .expand((e) => e.dueQuestions)
        .toList()
      ..shuffle();

    return Scaffold(
      floatingActionButton: allDueQuestions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _start(context, allDueQuestions, l10n.srsAllDueTitle),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.srsReviewAll),
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: colorScheme.error,
            iconTheme: IconThemeData(color: colorScheme.onError),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(0, 0, 20, 16),
              title: CollapsibleAppBarTitle(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.srsTitle,
                    style: TextStyle(
                      color: colorScheme.onError,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.error,
                      colorScheme.tertiary,
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24, bottom: 24),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 80,
                      color: colorScheme.onError.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (entries.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text(l10n.srsNoQuestions)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) => Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: SrsQuizCard(
                        entry: entries[index],
                        onStart: _start,
                        onStartNormal: _startNormal,
                        onRemoveSrs: _removeSrs,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _start(BuildContext context, List<QuestionData> questions,
      String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SrsSessionScreen(questions: questions, sessionTitle: title),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _startNormal(BuildContext context, QuizData quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSessionScreen(quizData: quiz),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _removeSrs(BuildContext context, SrsQuizEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.srsRemoveDialogTitle),
        content: Text(l10n.srsRemoveDialogContent(entry.quizTitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      for (final q in entry.allQuestions) {
        await srsService.setQuestionSrs(q, false);
      }
      setState(() {});
    }
  }
}
