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
import 'package:leerlus/widgets/app_image.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
      'folder_${f.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}.json';

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

  Future<void> _exportFolder(BuildContext context) async {
    try {
      final data = await db.exportFolderToJsonMap(f.id);
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _fileName));
      await file.writeAsString(jsonString);

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to ${file.path}')),
          );
        }
      } else {
        await Share.shareXFiles([XFile(file.path)], subject: 'Leerlus folder export');
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e))),
        );
      }
    }
  }

  void _confirmDeleteFolder(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteFolderTitle),
        content: Text(l10n.deleteFolderContent(f.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await db.deleteFolder(f.id);
              await QuestionService().refresh();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
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
      'quiz_${q.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}.json';

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

  Future<void> _exportQuiz(BuildContext context) async {
    try {
      final data = await db.exportQuizToJsonMap(q.id);
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _fileName));
      await file.writeAsString(jsonString);

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to ${file.path}')),
          );
        }
      } else {
        await Share.shareXFiles([XFile(file.path)], subject: 'Leerlus quiz export');
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e))),
        );
      }
    }
  }

  void _confirmDeleteQuiz(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteQuizTitle),
        content: Text(l10n.deleteQuizContent(q.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await db.deleteQuiz(q.id);
              await QuestionService().refresh();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
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
