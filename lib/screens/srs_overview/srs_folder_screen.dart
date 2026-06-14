import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/screens/quiz_session_screen.dart';
import 'package:leerlus/screens/srs_session_screen.dart';
import 'package:leerlus/screens/srs_overview/srs_folder_card.dart';
import 'package:leerlus/screens/srs_overview/srs_overview_data.dart';
import 'package:leerlus/screens/srs_overview/srs_quiz_card.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';

/// Shows the SRS contents of a single folder: its subfolders (as tappable
/// cards that drill in further) and its quizzes. A back button returns to the
/// parent level.
class SrsFolderScreen extends StatefulWidget {
  final String folderId;

  const SrsFolderScreen({super.key, required this.folderId});

  @override
  State<SrsFolderScreen> createState() => _SrsFolderScreenState();
}

class _SrsFolderScreenState extends State<SrsFolderScreen> {
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
    final colorScheme = Theme.of(context).colorScheme;

    final folder = questionService.getFolder(widget.folderId);
    final entries = computeSrsEntries(questionService, srsService);
    final entryByQuizId = {for (final e in entries) e.quiz.id: e};
    final node = folder == null
        ? null
        : buildSrsFolderNode(questionService, folder, entryByQuizId);

    final title = folder?.title ?? '';
    final due = node?.allDueRecursive ?? const <QuestionData>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
      ),
      floatingActionButton: due.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _start(context, due, title),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.srsReviewAll),
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            )
          : null,
      body: node == null
          ? Center(child: Text(l10n.srsNoQuestions))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (final sub in node.subfolders)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: SrsFolderCard(
                        node: sub,
                        onTap: () => _openFolder(context, sub),
                        onReview: () =>
                            _start(context, sub.allDueRecursive, sub.folder.title),
                      ),
                    ),
                  ),
                for (final entry in node.quizEntries)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: SrsQuizCard(
                        entry: entry,
                        onStart: _start,
                        onStartNormal: _startNormal,
                        onRemoveSrs: _removeSrs,
                        showFolderTag: false,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _openFolder(BuildContext context, SrsFolderNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SrsFolderScreen(folderId: node.folder.id),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _start(BuildContext context, List<QuestionData> questions, String title) {
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
