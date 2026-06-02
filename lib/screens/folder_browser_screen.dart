import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/folder_data.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/screens/global_search_screen.dart';
import 'package:leerlus/screens/quiz_session_screen.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/widgets/collapsible_app_bar_title.dart';
import 'package:leerlus/widgets/folder_tile.dart';
import 'package:leerlus/widgets/quiz_tile.dart';

/// Browsable folder/quiz screen. Pass [folder] = null to show the root level.
class FolderBrowserScreen extends StatelessWidget {
  final FolderData? folder;

  FolderBrowserScreen({super.key, this.folder});

  final QuestionService _service = QuestionService();

  List<QuestionData> _collectAllQuestions(String folderId) {
    final result = <QuestionData>[];
    for (final quiz in _service.getQuizzesInFolder(folderId)) {
      result.addAll(_service.getQuestionsForQuiz(quiz.id));
    }
    for (final sub in _service.getSubfolders(folderId)) {
      result.addAll(_collectAllQuestions(sub.id));
    }
    return result;
  }

  void _playAll(BuildContext context, FolderData sub, String title) {
    final questions = _collectAllQuestions(sub.id);
    if (questions.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSessionScreen(
          overrideQuestions: questions,
          sessionTitle: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final subfolders = folder == null
        ? _service.getRootFolders()
        : _service.getSubfolders(folder!.id);

    final quizzes = _service.getQuizzesInFolder(folder?.id);

    final isEmpty = subfolders.isEmpty && quizzes.isEmpty;

    const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 250,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double hPad = constraints.maxWidth > 900
              ? (constraints.maxWidth - 900) / 2 + 16
              : 16;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                backgroundColor: colorScheme.primary,
                iconTheme: IconThemeData(color: colorScheme.onPrimary),
                actions: [
                  IconButton(
                    tooltip: l10n.searchTooltip,
                    icon: Icon(Icons.search, color: colorScheme.onPrimary),
                    onPressed: () => showSearch(
                      context: context,
                      delegate: GlobalSearchDelegate(hint: l10n.searchHint),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.fromLTRB(0, 0, 20, 16),
                  title: CollapsibleAppBarTitle(
                    child: Text(
                      folder?.title ?? l10n.navBrowse,
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.tertiary,
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24, bottom: 16),
                        child: Icon(
                          folder == null
                              ? Icons.folder_open_rounded
                              : Icons.folder_rounded,
                          size: 80,
                          color: colorScheme.onPrimary.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (isEmpty)
                SliverFillRemaining(
                  child: Center(child: Text(l10n.emptyFolder)),
                )
              else ...[
                if (subfolders.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 8),
                      child: Text(
                        l10n.foldersSection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final sub = subfolders[index];
                          return FolderTile(
                            folder: sub,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FolderBrowserScreen(folder: sub),
                              ),
                            ),
                            onPlayAll: () => _playAll(context, sub, sub.title),
                          );
                        },
                        childCount: subfolders.length,
                      ),
                      gridDelegate: gridDelegate,
                    ),
                  ),
                ],

                if (quizzes.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 8),
                      child: Text(
                        l10n.quizzesSection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final quiz = quizzes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: QuizTile(
                              horizontal: true,
                              quiz: quiz,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      QuizSessionScreen(quizData: quiz),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: quizzes.length,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
