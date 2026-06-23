import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/screens/srs_overview/srs_folder_card.dart';
import 'package:leerlus/screens/srs_overview/srs_folder_screen.dart';
import 'package:leerlus/screens/srs_overview/srs_overview_data.dart';
import 'package:leerlus/screens/srs_overview/srs_quiz_card.dart';
import 'package:leerlus/screens/srs_session_screen.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/services/streak_service.dart';
import 'package:leerlus/widgets/streak_banner.dart';

enum _SrsCompletionView { list, folder }

class SrsCompletionScreen extends StatefulWidget {
  final String completedQuizTitle;
  final int reviewedCount;
  final StreakEvent? streakEvent;

  const SrsCompletionScreen({
    super.key,
    required this.completedQuizTitle,
    required this.reviewedCount,
    this.streakEvent,
  });

  @override
  State<SrsCompletionScreen> createState() => _SrsCompletionScreenState();
}

class _SrsCompletionScreenState extends State<SrsCompletionScreen> {
  final QuestionService questionService = QuestionService();
  final SrsService srsService = SrsService();
  _SrsCompletionView _viewMode = _SrsCompletionView.folder;

  /// SRS entries that still have due questions right now. The folder view is
  /// built from these, so folders without any due question never appear.
  List<SrsQuizEntry> _dueEntries() => computeSrsEntries(questionService, srsService)
      .where((e) => e.dueQuestions.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final dueEntries = _dueEntries();

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
                widget.completedQuizTitle,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.srsQuestionsReviewed(widget.reviewedCount),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (widget.streakEvent != null)
                StreakBanner(event: widget.streakEvent!),
              const SizedBox(height: 16),

              // ── Due quizzes / all-caught-up ───────────────────────────
              if (dueEntries.isEmpty) ...[
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.srsStillDue,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ),
                    _buildViewToggle(colorScheme, l10n),
                  ],
                ),
                const SizedBox(height: 8),
                if (_viewMode == _SrsCompletionView.list)
                  ..._buildListView(dueEntries)
                else
                  ..._buildFolderView(dueEntries),
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

  Widget _buildViewToggle(ColorScheme colorScheme, AppLocalizations l10n) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(28),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.srsViewFolderView,
              isSelected: _viewMode == _SrsCompletionView.folder,
              onPressed: () =>
                  setState(() => _viewMode = _SrsCompletionView.folder),
              icon: Icon(
                Icons.account_tree_rounded,
                color: _viewMode == _SrsCompletionView.folder
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              tooltip: l10n.srsViewListView,
              isSelected: _viewMode == _SrsCompletionView.list,
              onPressed: () =>
                  setState(() => _viewMode = _SrsCompletionView.list),
              icon: Icon(
                Icons.view_list_rounded,
                color: _viewMode == _SrsCompletionView.list
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildListView(List<SrsQuizEntry> dueEntries) {
    return [
      for (final entry in dueEntries)
        _DueQuizTile(
          quizTitle: entry.quizTitle,
          dueCount: entry.dueQuestions.length,
          onStart: () => _startSession(entry.dueQuestions, entry.quizTitle),
        ),
    ];
  }

  List<Widget> _buildFolderView(List<SrsQuizEntry> dueEntries) {
    final entryByQuizId = {for (final e in dueEntries) e.quiz.id: e};

    // Root level: only folders containing a due quiz somewhere below them.
    final nodes = <SrsFolderNode>[];
    for (final folder in questionService.getRootFolders()) {
      final node = buildSrsFolderNode(questionService, folder, entryByQuizId);
      if (node != null) nodes.add(node);
    }

    // Due quizzes not assigned to any folder show as loose tiles below.
    final looseEntries =
        dueEntries.where((e) => e.quiz.parentFolderId == null).toList();

    return [
      for (final node in nodes)
        SrsFolderCard(
          node: node,
          onTap: () => _openFolder(node),
          onReview: () => _startSession(node.allDueRecursive, node.folder.title),
        ),
      for (final entry in looseEntries)
        _DueQuizTile(
          quizTitle: entry.quizTitle,
          dueCount: entry.dueQuestions.length,
          onStart: () => _startSession(entry.dueQuestions, entry.quizTitle),
        ),
    ];
  }

  void _startSession(List<QuestionData> questions, String title) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SrsSessionScreen(questions: questions, sessionTitle: title),
      ),
    );
  }

  void _openFolder(SrsFolderNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SrsFolderScreen(folderId: node.folder.id),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
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
