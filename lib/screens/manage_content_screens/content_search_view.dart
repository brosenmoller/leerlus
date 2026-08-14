import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/screens/manage_content_screens/manage_folder_screen.dart';
import 'package:leerlus/screens/manage_content_screens/manage_questions_screen.dart';
import 'package:leerlus/services/question_service.dart';

/// Live search over folders, quizzes and questions, with [FilterChip]s picking
/// which sections are shown. Shared by the root manage screen and the folder
/// management screen.
///
/// Tapping a folder opens its management screen; tapping a quiz or a question
/// opens the question management screen (questions are scrolled to and
/// highlighted there).
class ContentSearchView extends StatefulWidget {
  final AppDatabase db;

  /// The current search text. Empty means [emptyQueryChild] is shown instead of
  /// results — the chips stay visible either way.
  final String query;

  /// Limits results to this folder's subtree; null searches the whole app.
  final String? scopeFolderId;

  /// Shown below the chips while [query] is empty (normally the folder's
  /// regular contents list).
  final Widget emptyQueryChild;

  const ContentSearchView({
    super.key,
    required this.db,
    required this.query,
    required this.scopeFolderId,
    required this.emptyQueryChild,
  });

  @override
  State<ContentSearchView> createState() => _ContentSearchViewState();
}

class _ContentSearchViewState extends State<ContentSearchView> {
  // Which result sections are shown. All three default to on: hunting for a
  // specific card is the common case, so questions being opt-in only meant
  // re-enabling the chip on every search. State lives here, so leaving search
  // (which disposes this widget) restores the defaults.
  bool _showFolders = true;
  bool _showQuizzes = true;
  bool _showQuestions = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _buildFilterChips(l10n),
        Expanded(
          child: widget.query.trim().isEmpty
              ? widget.emptyQueryChild
              : _buildResultsList(l10n),
        ),
      ],
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.foldersSection),
                selected: _showFolders,
                onSelected: (v) => setState(() => _showFolders = v),
              ),
              FilterChip(
                label: Text(l10n.quizzesSection),
                selected: _showQuizzes,
                onSelected: (v) => setState(() => _showQuizzes = v),
              ),
              FilterChip(
                label: Text(l10n.questionsSection),
                selected: _showQuestions,
                onSelected: (v) => setState(() => _showQuestions = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ids of [rootId] and every folder below it. Walked from the folder list the
  /// stream already delivered rather than through `db.getFolderSubtreeIds`,
  /// which is async and would mean a round trip per keystroke.
  Set<String> _subtreeIds(List<Folder> allFolders, String rootId) {
    final childrenOf = <String, List<String>>{};
    for (final f in allFolders) {
      if (f.parentFolderId != null) {
        childrenOf.putIfAbsent(f.parentFolderId!, () => []).add(f.id);
      }
    }
    final ids = <String>{rootId};
    final queue = <String>[rootId];
    while (queue.isNotEmpty) {
      for (final child in childrenOf[queue.removeLast()] ?? const <String>[]) {
        if (ids.add(child)) queue.add(child);
      }
    }
    return ids;
  }

  Widget _buildResultsList(AppLocalizations l10n) {
    final db = widget.db;
    final query = widget.query.toLowerCase().trim();
    return StreamBuilder<List<Folder>>(
      stream: db.watchAllFolders(),
      builder: (context, folderSnap) {
        return StreamBuilder<List<Quiz>>(
          stream: db.watchAllQuizzes(),
          builder: (context, quizSnap) {
            return StreamBuilder<List<Question>>(
              stream: db.watchAllQuestions(),
              builder: (context, questionSnap) {
                if (!folderSnap.hasData ||
                    !quizSnap.hasData ||
                    !questionSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // null = unscoped. The scope folder itself is a valid home for
                // quizzes but is never listed as a result of searching inside
                // itself.
                final scope = widget.scopeFolderId == null
                    ? null
                    : _subtreeIds(folderSnap.data!, widget.scopeFolderId!);

                final folders = _showFolders
                    ? (folderSnap.data!
                        .where((f) =>
                            f.title.toLowerCase().contains(query) &&
                            (scope == null ||
                                (f.id != widget.scopeFolderId &&
                                    scope.contains(f.id))))
                        .toList()
                      ..sort((a, b) => a.title.compareTo(b.title)))
                    : const <Folder>[];

                bool quizInScope(Quiz q) =>
                    scope == null ||
                    (q.folderId != null && scope.contains(q.folderId!));

                final quizzes = _showQuizzes
                    ? (quizSnap.data!
                        .where((q) =>
                            q.title.toLowerCase().contains(query) &&
                            quizInScope(q))
                        .toList()
                      ..sort((a, b) => a.title.compareTo(b.title)))
                    : const <Quiz>[];

                // Resolve each matching question to the quiz it lives in so the
                // tile knows where to navigate; skip orphans with no owner.
                // The reverse map is built once — a per-question lookup would
                // rescan every quiz's question list.
                final quizById = {for (final q in quizSnap.data!) q.id: q};
                final questions = <_QuestionHit>[];
                if (_showQuestions) {
                  final quizIdByQuestion = <String, String>{
                    for (final quiz in QuestionService().getAllQuizzes())
                      for (final questionId in quiz.questionIds)
                        questionId: quiz.id,
                  };
                  for (final q in questionSnap.data!) {
                    if (!q.questionText.toLowerCase().contains(query)) continue;
                    final quiz = quizById[quizIdByQuestion[q.id]];
                    if (quiz == null || !quizInScope(quiz)) continue;
                    questions.add(_QuestionHit(q, quiz));
                  }
                  questions.sort((a, b) => a.question.questionText
                      .toLowerCase()
                      .compareTo(b.question.questionText.toLowerCase()));
                }

                if (folders.isEmpty && quizzes.isEmpty && questions.isEmpty) {
                  return Center(child: Text(l10n.searchNoResults));
                }

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        if (folders.isNotEmpty) ...[
                          _SearchSectionHeader(label: l10n.foldersSection),
                          ...folders.map((f) => ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.folder_outlined)),
                                title: Text(f.title),
                                subtitle: _parentSubtitle(f.parentFolderId),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ManageFolderScreen(db: db, folder: f),
                                  ),
                                ),
                              )),
                        ],
                        if (quizzes.isNotEmpty) ...[
                          _SearchSectionHeader(label: l10n.quizzesSection),
                          ...quizzes.map((quiz) => ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.quiz_outlined)),
                                title: Text(quiz.title),
                                subtitle: _parentSubtitle(quiz.folderId),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ManageQuestionsScreen(
                                        db: db, quiz: quiz),
                                  ),
                                ),
                              )),
                        ],
                        if (questions.isNotEmpty) ...[
                          _SearchSectionHeader(label: l10n.questionsSection),
                          ...questions.map((hit) => ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.help_outline)),
                                title: Text(
                                  hit.question.questionText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(hit.quiz.title),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ManageQuestionsScreen(
                                      db: db,
                                      quiz: hit.quiz,
                                      highlightQuestionId: hit.question.id,
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Subtitle showing the parent folder's title, or null at the root.
  Widget? _parentSubtitle(String? parentFolderId) {
    if (parentFolderId == null) return null;
    final title = QuestionService().getFolder(parentFolderId)?.title;
    return title != null ? Text(title) : null;
  }
}

/// A question search hit paired with the quiz it belongs to (for navigation).
class _QuestionHit {
  final Question question;
  final Quiz quiz;
  const _QuestionHit(this.question, this.quiz);
}

/// Section header used in the search results list.
class _SearchSectionHeader extends StatelessWidget {
  final String label;
  const _SearchSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Colors.grey, letterSpacing: 1),
      ),
    );
  }
}
