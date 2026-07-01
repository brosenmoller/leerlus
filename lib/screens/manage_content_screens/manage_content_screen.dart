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
      // Reuse the folder contents view — null folder = root level
      body: _query.trim().isEmpty
          ? FolderContentsBody(db: db, folder: null)
          : _buildSearchResults(l10n),
    );
  }

  // ── Folder & quiz search results ────────────────────────────────

  /// Flat, case-insensitive search across every folder and quiz in the app.
  /// Tapping a folder opens its management screen; tapping a quiz opens its
  /// question management screen.
  Widget _buildSearchResults(AppLocalizations l10n) {
    final query = _query.toLowerCase().trim();
    return StreamBuilder<List<Folder>>(
      stream: db.watchAllFolders(),
      builder: (context, folderSnap) {
        return StreamBuilder<List<Quiz>>(
          stream: db.watchAllQuizzes(),
          builder: (context, quizSnap) {
            if (!folderSnap.hasData || !quizSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final folders = folderSnap.data!
                .where((f) => f.title.toLowerCase().contains(query))
                .toList()
              ..sort((a, b) => a.title.compareTo(b.title));
            final quizzes = quizSnap.data!
                .where((q) => q.title.toLowerCase().contains(query))
                .toList()
              ..sort((a, b) => a.title.compareTo(b.title));

            if (folders.isEmpty && quizzes.isEmpty) {
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
                                builder: (_) =>
                                    ManageQuestionsScreen(db: db, quiz: quiz),
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
