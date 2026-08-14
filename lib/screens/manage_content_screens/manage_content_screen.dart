import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/screens/content_packs_screen.dart';
import 'package:leerlus/screens/manage_content_screens/content_search_view.dart';
import 'package:leerlus/screens/manage_content_screens/edit_folder_screen.dart';
import 'package:leerlus/screens/manage_content_screens/edit_quiz_screen.dart';
import 'package:leerlus/screens/manage_content_screens/manage_folder_screen.dart';
import 'package:leerlus/utils/lus_export_flow.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';
import 'package:leerlus/widgets/screen_shortcuts.dart';

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
  final _searchFocusNode = FocusNode();
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
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Ctrl+F and the search action. Pressing it again with the bar already open
  /// puts the caret back in the field instead of doing nothing.
  void _startSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
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

  void _newFolder() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditFolderScreen(db: db)),
      );

  void _newQuiz() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditQuizScreen(db: db)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScreenShortcuts(
      onSearch: _startSearch,
      // The create shortcuts mirror the FABs, which are hidden while searching.
      onNew: _searching ? null : _newQuiz,
      onNewFolder: _searching ? null : _newFolder,
      // Escape / back closes the search bar before leaving the screen.
      onEscape: _searching ? _stopSearch : null,
      child: _buildScaffold(l10n),
    );
  }

  Widget _buildScaffold(AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
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
                  onPressed: _startSearch,
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
                  onPressed: _newFolder,
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'root_add_quiz',
                  icon: const Icon(Icons.quiz_outlined),
                  label: Text(l10n.addQuiz),
                  onPressed: _newQuiz,
                ),
              ],
            ),
      // While searching, the search view shows its filter chips immediately
      // (even before any text is typed); below them the root folder view or
      // the live results. Reuse the folder contents view — null = root level.
      body: _searching
          ? ContentSearchView(
              db: db,
              query: _query,
              scopeFolderId: null,
              emptyQueryChild: FolderContentsBody(db: db, folder: null),
            )
          : FolderContentsBody(db: db, folder: null),
    );
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
    );
  }
}
