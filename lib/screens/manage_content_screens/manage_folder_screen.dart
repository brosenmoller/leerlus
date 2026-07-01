import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/screens/manage_content_screens/edit_folder_screen.dart';
import 'package:leerlus/screens/manage_content_screens/edit_quiz_screen.dart';
import 'package:leerlus/screens/manage_content_screens/manage_questions_screen.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/utils/lus_export_flow.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:path/path.dart' as p;

/// Shows the contents (subfolders + quizzes) of a folder, or the root if
/// [folder] is null. Navigating into a subfolder pushes another instance.
class ManageFolderScreen extends StatelessWidget {
  final AppDatabase db;
  /// null = root level
  final Folder? folder;

  const ManageFolderScreen({super.key, required this.db, this.folder});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(folder?.title ?? l10n.manageContentTitle),
        bottom: folder != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l10n.folderContents,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              )
            : null,
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_folder_${folder?.id}',
            icon: const Icon(Icons.create_new_folder_outlined),
            label: Text(l10n.addFolder),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EditFolderScreen(db: db, parentFolderId: folder?.id),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_quiz_${folder?.id}',
            icon: const Icon(Icons.quiz_outlined),
            label: Text(l10n.addQuiz),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditQuizScreen(db: db, folderId: folder?.id),
              ),
            ),
          ),
        ],
      ),
      body: FolderContentsBody(db: db, folder: folder),
    );
  }
}

/// Exported so ManageContentScreen can embed the root-level view directly.
class FolderContentsBody extends StatelessWidget {
  final AppDatabase db;
  final Folder? folder;

  const FolderContentsBody({super.key, required this.db, this.folder});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<Folder>>(
      stream: db.watchSubfolders(folder?.id),
      builder: (context, subSnap) {
        return StreamBuilder<List<Quiz>>(
          stream: db.watchQuizzesInFolder(folder?.id),
          builder: (context, quizSnap) {
            if (!subSnap.hasData || !quizSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final subfolders = subSnap.data!;
            final quizzes = quizSnap.data!;

            if (subfolders.isEmpty && quizzes.isEmpty) {
              return Center(child: Text(l10n.emptyFolderManage));
            }

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    if (subfolders.isNotEmpty) ...[
                      _SectionHeader(label: l10n.foldersSection),
                      ...subfolders.map((f) => _FolderTile(db: db, f: f)),
                      const Divider(height: 17),
                    ],
                    if (quizzes.isNotEmpty) ...[
                      _SectionHeader(label: l10n.quizzesSection),
                      ...quizzes.map((q) => _QuizTile(db: db, q: q)),
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
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

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

// ── Folder tile ────────────────────────────────────────────────────────────────

class _FolderTile extends StatefulWidget {
  final AppDatabase db;
  final Folder f;
  const _FolderTile({required this.db, required this.f});

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> {
  bool _inManifest = false;

  AppDatabase get db => widget.db;
  Folder get f => widget.f;

  String get _fileName =>
      'folder_${f.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}.lus';

  @override
  void initState() {
    super.initState();
    if (kDebugMode) _checkManifest();
  }

  Future<void> _checkManifest() async {
    final result = await _isPackInManifest(f.id, _fileName);
    if (mounted) setState(() => _inManifest = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: f.imagePath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AppImage(
                path: f.imagePath,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          : const CircleAvatar(child: Icon(Icons.folder_outlined)),
      title: Text(f.title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.only(left: 16),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.edit,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditFolderScreen(db: db, existing: f),
              ),
            ),
          ),
          PopupMenuButton<Object?>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                onTap: () async {
                  final excludeIds = await db.getFolderSubtreeIds(f.id);
                  if (context.mounted) {
                    await _showMoveToFolderDialog(
                      context: context,
                      db: db,
                      excludeIds: excludeIds,
                      onMove: (targetId) =>
                          db.moveFolderToParent(f.id, targetId),
                    );
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.drive_file_move_outlined),
                    const SizedBox(width: 12),
                    Text(l10n.moveTooltip),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => _exportFolder(context),
                child: Row(
                  children: [
                    const Icon(Icons.upload_outlined),
                    const SizedBox(width: 12),
                    Text(l10n.exportFolderTooltip),
                  ],
                ),
              ),
              if (kDebugMode)
                PopupMenuItem(
                  onTap: () => _addToManifest(context),
                  child: Row(
                    children: [
                      _inManifest
                          ? const Icon(Icons.library_add, color: Colors.orange)
                          : const Icon(Icons.library_add_outlined),
                      const SizedBox(width: 12),
                      Text(_inManifest
                          ? 'Update in content packs'
                          : 'Add to content packs'),
                    ],
                  ),
                ),
              PopupMenuItem(
                onTap: () => _confirmDeleteFolder(context),
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(l10n.delete,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManageFolderScreen(db: db, folder: f),
        ),
      ),
    );
  }

  Future<void> _addToManifest(BuildContext context) async {
    final data = await db.exportFolderToJsonMap(f.id);
    final ok = await _writePackToManifest(
      context,
      data: data,
      fileName: _fileName,
      title: f.title,
      syncId: f.id,
      wasInManifest: _inManifest,
    );
    if (ok && mounted) setState(() => _inManifest = true);
  }

  Future<void> _exportFolder(BuildContext context) => runLusExport(
        context,
        defaultFileName: _fileName,
        startEncode: () => db.startExportFolderToLus(f.id),
        shareSubject: 'Leerlus folder export',
      );

  Future<void> _confirmDeleteFolder(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    final folderSubtreeIds = await db.getFolderSubtreeIds(f.id);
    final folderQuizIds = await db.getFolderQuizIds(f.id);
    final ownPaths = (await db.getImagePathsForFolders(folderSubtreeIds))
        .union(await db.getImagePathsForQuizzes(folderQuizIds));
    final otherPaths = await db.getAllReferencedUserImagePaths(
      excludeQuizIds: folderQuizIds,
      excludeFolderIds: folderSubtreeIds,
    );
    final orphans = ownPaths.difference(otherPaths).toList();

    if (!context.mounted) return;

    bool deleteOrphans = orphans.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: Text(l10n.deleteFolderTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.deleteFolderContent(f.title)),
              if (orphans.isNotEmpty) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    l10n.deleteOrphanImages(orphans.length),
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: deleteOrphans,
                  onChanged: (v) => setStateDlg(() => deleteOrphans = v ?? false),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    await db.deleteFolder(f.id);
    if (deleteOrphans) {
      for (final path in orphans) {
        try { await File(path).delete(); } catch (_) {}
      }
    }
    await QuestionService().refresh();
  }
}

// ── Quiz tile ──────────────────────────────────────────────────────────────────

class _QuizTile extends StatefulWidget {
  final AppDatabase db;
  final Quiz q;
  const _QuizTile({required this.db, required this.q});

  @override
  State<_QuizTile> createState() => _QuizTileState();
}

class _QuizTileState extends State<_QuizTile> {
  bool _inManifest = false;

  AppDatabase get db => widget.db;
  Quiz get q => widget.q;

  String get _fileName =>
      'quiz_${q.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}.lus';

  @override
  void initState() {
    super.initState();
    if (kDebugMode) _checkManifest();
  }

  Future<void> _checkManifest() async {
    final result = await _isPackInManifest(q.id, _fileName);
    if (mounted) setState(() => _inManifest = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: q.imagePath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AppImage(
                path: q.imagePath,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          : const CircleAvatar(child: Icon(Icons.quiz_outlined)),
      title: Text(q.title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.only(left: 16),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.edit,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditQuizScreen(
                  db: db,
                  folderId: q.folderId,
                  existing: q,
                ),
              ),
            ),
          ),
          PopupMenuButton<Object?>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                onTap: () => _showMoveToFolderDialog(
                  context: context,
                  db: db,
                  onMove: (targetId) => db.moveQuizToFolder(q.id, targetId),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.drive_file_move_outlined),
                    const SizedBox(width: 12),
                    Text(l10n.moveTooltip),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => _exportQuiz(context),
                child: Row(
                  children: [
                    const Icon(Icons.upload_outlined),
                    const SizedBox(width: 12),
                    Text(l10n.exportQuizTooltip),
                  ],
                ),
              ),
              if (kDebugMode)
                PopupMenuItem(
                  onTap: () => _addToManifest(context),
                  child: Row(
                    children: [
                      _inManifest
                          ? const Icon(Icons.library_add, color: Colors.orange)
                          : const Icon(Icons.library_add_outlined),
                      const SizedBox(width: 12),
                      Text(_inManifest
                          ? 'Update in content packs'
                          : 'Add to content packs'),
                    ],
                  ),
                ),
              PopupMenuItem(
                onTap: () => _confirmDeleteQuiz(context),
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(l10n.delete,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManageQuestionsScreen(db: db, quiz: q),
        ),
      ),
    );
  }

  Future<void> _addToManifest(BuildContext context) async {
    final data = await db.exportQuizToJsonMap(q.id);
    final ok = await _writePackToManifest(
      context,
      data: data,
      fileName: _fileName,
      title: q.title,
      syncId: q.id,
      wasInManifest: _inManifest,
    );
    if (ok && mounted) setState(() => _inManifest = true);
  }

  Future<void> _exportQuiz(BuildContext context) => runLusExport(
        context,
        defaultFileName: _fileName,
        startEncode: () => db.startExportQuizToLus(q.id),
        shareSubject: 'Leerlus quiz export',
      );

  Future<void> _confirmDeleteQuiz(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    final ownPaths = await db.getImagePathsForQuizzes({q.id});
    final otherPaths = await db.getAllReferencedUserImagePaths(
      excludeQuizIds: {q.id},
    );
    final orphans = ownPaths.difference(otherPaths).toList();

    if (!context.mounted) return;

    bool deleteOrphans = orphans.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: Text(l10n.deleteQuizTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.deleteQuizContent(q.title)),
              if (orphans.isNotEmpty) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    l10n.deleteOrphanImages(orphans.length),
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: deleteOrphans,
                  onChanged: (v) => setStateDlg(() => deleteOrphans = v ?? false),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    await db.deleteQuiz(q.id);
    if (deleteOrphans) {
      for (final path in orphans) {
        try { await File(path).delete(); } catch (_) {}
      }
    }
    await QuestionService().refresh();
  }
}

// ── Move-to-folder dialog ──────────────────────────────────────────────────────

Future<void> _showMoveToFolderDialog({
  required BuildContext context,
  required AppDatabase db,
  Set<String>? excludeIds,
  required Future<void> Function(String? targetFolderId) onMove,
}) async {
  final l10n = AppLocalizations.of(context);
  final allFolders = await db.getAllFolders();
  final available = excludeIds == null
      ? allFolders
      : allFolders.where((f) => !excludeIds.contains(f.id)).toList();

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.moveToFolderTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(l10n.moveToRootOption),
              onTap: () async {
                Navigator.pop(ctx);
                await onMove(null);
                await QuestionService().refresh();
              },
            ),
            const Divider(height: 1),
            ...available.map(
              (f) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.title),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onMove(f.id);
                  await QuestionService().refresh();
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}

// ── Shared manifest helpers ────────────────────────────────────────────────────

/// Returns true if [syncId] or [fileName] already appears in index.json.
Future<bool> _isPackInManifest(String? syncId, String fileName) async {
  try {
    final manifestFile = File(
        p.join(Directory.current.path, 'assets', 'content_packs', 'index.json'));
    if (!await manifestFile.exists()) return false;
    final manifest = jsonDecode(await manifestFile.readAsString()) as List;
    return manifest.any((e) {
      final entry = e as Map<String, dynamic>;
      if (syncId != null && entry['id'] == syncId) return true;
      return entry['file'] == fileName;
    });
  } catch (_) {
    return false;
  }
}

/// Writes [data] to `assets/content_packs/[fileName]` and upserts the entry
/// in `assets/content_packs/index.json`. Deduplicates by [syncId] then [fileName].
/// Returns true on success, false on error (error is shown as a snackbar).
Future<bool> _writePackToManifest(
  BuildContext context, {
  required Map<String, dynamic> data,
  required String fileName,
  required String title,
  required String? syncId,
  required bool wasInManifest,
}) async {
  try {
    final packDir = p.join(Directory.current.path, 'assets', 'content_packs');

    await File(p.join(packDir, fileName))
        .writeAsString(const JsonEncoder.withIndent('  ').convert(data));

    final manifestFile = File(p.join(packDir, 'index.json'));
    List<dynamic> manifest = [];
    if (await manifestFile.exists()) {
      manifest = jsonDecode(await manifestFile.readAsString()) as List;
    }

    final newEntry = <String, dynamic>{
      'file': fileName,
      'title': title,
      if (syncId != null) 'id': syncId,
    };

    final idx = manifest.indexWhere((e) {
      final entry = e as Map<String, dynamic>;
      if (syncId != null && entry['id'] == syncId) return true;
      return entry['file'] == fileName;
    });
    if (idx >= 0) {
      manifest[idx] = newEntry;
    } else {
      manifest.add(newEntry);
    }

    await manifestFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));

    if (context.mounted) {
      final verb = wasInManifest ? 'Updated' : 'Added';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$verb "$title" in content packs')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to write to content packs: $e')),
      );
    }
    return false;
  }
}
