import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/screens/quiz_session_screen.dart';
import 'package:leerlus/screens/srs_session_screen.dart';
import 'package:leerlus/screens/srs_overview/srs_folder_card.dart';
import 'package:leerlus/screens/srs_overview/srs_folder_screen.dart';
import 'package:leerlus/screens/srs_overview/srs_overview_data.dart';
import 'package:leerlus/screens/srs_overview/srs_quiz_card.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/widgets/collapsible_app_bar_title.dart';

enum SrsViewMode { list, folder }

class SrsOverviewScreen extends StatefulWidget {
  const SrsOverviewScreen({super.key});

  @override
  State<SrsOverviewScreen> createState() => _SrsOverviewScreenState();
}

class _SrsOverviewScreenState extends State<SrsOverviewScreen> {
  final QuestionService questionService = QuestionService();
  final SrsService srsService = SrsService();
  SrsViewMode _viewMode = SrsViewMode.folder;
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

    final entries = computeSrsEntries(questionService, srsService);

    // Order is randomized by SrsSessionScreen (see scrambleQuestions), which
    // also keeps chained flashcards apart, so no shuffle is needed here.
    final allDueQuestions = entries.expand((e) => e.dueQuestions).toList();

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
      body: Stack(
        children: [
          CustomScrollView(
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
          else if (_viewMode == SrsViewMode.list)
            _buildListSliver(entries)
          else
            _buildFolderSliver(entries),
        ],
          ),

          // View-mode toggle, floating bottom-left (mirrors the FAB).
          Positioned(
            left: 16,
            bottom: 16,
            child: SafeArea(
              child: _buildViewToggle(colorScheme, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(ColorScheme colorScheme, AppLocalizations l10n) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(28),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.srsViewFolderView,
              isSelected: _viewMode == SrsViewMode.folder,
              onPressed: () => setState(() => _viewMode = SrsViewMode.folder),
              icon: Icon(
                Icons.account_tree_rounded,
                color: _viewMode == SrsViewMode.folder
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              tooltip: l10n.srsViewListView,
              isSelected: _viewMode == SrsViewMode.list,
              onPressed: () => setState(() => _viewMode = SrsViewMode.list),
              icon: Icon(
                Icons.view_list_rounded,
                color: _viewMode == SrsViewMode.list
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSliver(List<SrsQuizEntry> entries) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) => _centered(
          child: SrsQuizCard(
            entry: entries[index],
            onStart: _start,
            onStartNormal: _startNormal,
            onRemoveSrs: _removeSrs,
          ),
        ),
      ),
    );
  }

  Widget _buildFolderSliver(List<SrsQuizEntry> entries) {
    final entryByQuizId = {for (final e in entries) e.quiz.id: e};

    // Root level: only folders containing an SRS quiz somewhere below them.
    final nodes = <SrsFolderNode>[];
    for (final folder in questionService.getRootFolders()) {
      final node = buildSrsFolderNode(questionService, folder, entryByQuizId);
      if (node != null) nodes.add(node);
    }

    // Quizzes not assigned to any folder show as loose cards below the folders.
    final looseEntries =
        entries.where((e) => e.quiz.parentFolderId == null).toList();

    final itemCount = nodes.length + looseEntries.length;

    return SliverPadding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      sliver: SliverList.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index < nodes.length) {
            return _centered(
              child: SrsFolderCard(
                node: nodes[index],
                onTap: () => _openFolder(context, nodes[index]),
                onReview: () => _start(context, nodes[index].allDueRecursive,
                    nodes[index].folder.title),
              ),
            );
          }
          final entry = looseEntries[index - nodes.length];
          return _centered(
            child: SrsQuizCard(
              entry: entry,
              onStart: _start,
              onStartNormal: _startNormal,
              onRemoveSrs: _removeSrs,
              showFolderTag: false,
            ),
          );
        },
      ),
    );
  }

  Widget _centered({required Widget child}) => Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: child,
          ),
        ),
      );

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
