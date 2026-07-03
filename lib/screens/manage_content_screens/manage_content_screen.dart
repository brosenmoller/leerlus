import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/screens/content_packs_screen.dart';
import 'package:leerlus/screens/manage_content_screens/edit_folder_screen.dart';
import 'package:leerlus/screens/manage_content_screens/edit_quiz_screen.dart';
import 'package:leerlus/screens/manage_content_screens/manage_folder_screen.dart';
import 'package:leerlus/screens/manage_content_screens/manage_questions_screen.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/utils/lus_export_flow.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';

/// Root management screen. Handles import/export and renders the
/// root folder contents via [ManageFolderScreen].
class ManageContentScreen extends StatefulWidget {
  final AppDatabase db;

  const ManageContentScreen({super.key, required this.db});

  @override
  State<ManageContentScreen> createState() => _ManageContentScreenState();
}

class _ManageContentScreenState extends State<ManageContentScreen> {
  AppDatabase get db => widget.db;

  /// Whether any content packs are listed in the asset index. Null while loading.
  bool? _hasPacks;

  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  // Which result sections the global search shows. Questions is off by default
  // so results stay uncluttered until the user opts in.
  bool _showFolders = true;
  bool _showQuizzes = true;
  bool _showQuestions = false;

  @override
  void initState() {
    super.initState();
    _loadHasPacks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _stopSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
      _showFolders = true;
      _showQuizzes = true;
      _showQuestions = false;
    });
  }

  Future<void> _loadHasPacks() async {
    bool has = false;
    try {
      final raw = await rootBundle.loadString('assets/content_packs/index.json');
      has = (jsonDecode(raw) as List).isNotEmpty;
    } catch (_) {
      has = false;
    }
    if (mounted) setState(() => _hasPacks = has);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onTap: collapseSelectionOnTap(_searchController),
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  border: InputBorder.none,
                ),
              )
            : Text(l10n.manageContentTitle),
        actions: _searching
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.searchTooltip,
                  onPressed: _stopSearch,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.searchTooltip,
                  onPressed: () => setState(() => _searching = true),
                ),
                if (_hasPacks == true)
                  IconButton(
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    tooltip: l10n.contentPacksTooltip,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ContentPacksScreen(db: db)),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  tooltip: l10n.importJsonTooltip,
                  onPressed: () => _importJson(context),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: l10n.exportJsonTooltip,
                  onPressed: () => _exportJson(context),
                ),
              ],
      ),
      floatingActionButton: _searching
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'root_add_folder',
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(l10n.addFolder),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditFolderScreen(db: db)),
                  ),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'root_add_quiz',
                  icon: const Icon(Icons.quiz_outlined),
                  label: Text(l10n.addQuiz),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditQuizScreen(db: db)),
                  ),
                ),
              ],
            ),
      // While searching, show the filter chips immediately (even before any
      // text is typed); below them the root folder view or the live results.
      // Reuse the folder contents view — null folder = root level.
      body: _searching
          ? Column(
              children: [
                _buildFilterChips(l10n),
                Expanded(
                  child: _query.trim().isEmpty
                      ? FolderContentsBody(db: db, folder: null)
                      : _buildResultsList(l10n),
                ),
              ],
            )
          : FolderContentsBody(db: db, folder: null),
    );
  }

  // ── Folder, quiz & question search results ──────────────────────

  /// Flat, case-insensitive search across every folder, quiz and question in
  /// the app. The three [FilterChip]s pick which sections are shown. Tapping a
  /// folder opens its management screen; tapping a quiz or question opens the
  /// question management screen (questions are scrolled to and highlighted).
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

  Widget _buildResultsList(AppLocalizations l10n) {
    final query = _query.toLowerCase().trim();
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

                final folders = _showFolders
                    ? (folderSnap.data!
                        .where((f) => f.title.toLowerCase().contains(query))
                        .toList()
                      ..sort((a, b) => a.title.compareTo(b.title)))
                    : const <Folder>[];
                final quizzes = _showQuizzes
                    ? (quizSnap.data!
                        .where((q) => q.title.toLowerCase().contains(query))
                        .toList()
                      ..sort((a, b) => a.title.compareTo(b.title)))
                    : const <Quiz>[];

                // Resolve each matching question to the quiz it lives in so the
                // tile knows where to navigate; skip orphans with no owner.
                final quizById = {for (final q in quizSnap.data!) q.id: q};
                final questions = <_QuestionHit>[];
                if (_showQuestions) {
                  for (final q in questionSnap.data!) {
                    if (!q.questionText.toLowerCase().contains(query)) continue;
                    final quizId =
                        QuestionService().getQuizIdForQuestion(q.id);
                    final quiz = quizId == null ? null : quizById[quizId];
                    if (quiz == null) continue;
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

  // ── .lus export ─────────────────────────────────────────────────

  Future<void> _exportJson(BuildContext context) => runLusExport(
        context,
        defaultFileName: 'leerlus_export.lus',
        startEncode: db.startExportToLus,
        shareSubject: 'Leerlus export',
      );

  // ── Import (.lus) ────────────────────────────────────────────────

  Future<void> _importJson(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return runLusImport(
      context,
      loadBytes: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['lus'],
        );
        final path = result?.files.single.path;
        if (path == null) return null;
        return File(path).readAsBytes();
      },
      startImport: db.startImportFromLus,
      successMessage: (_) => l10n.importSuccess,
    );
  }
}

/// A question search hit paired with the quiz it belongs to (for navigation).
class _QuestionHit {
  final Question question;
  final Quiz quiz;
  const _QuestionHit(this.question, this.quiz);
}

/// Section header used in the folder/quiz search results list.
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
