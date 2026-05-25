import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/screens/content_packs_screen.dart';
import 'package:leerlus/screens/manage_content_screens/edit_folder_screen.dart';
import 'package:leerlus/screens/manage_content_screens/edit_quiz_screen.dart';
import 'package:leerlus/screens/manage_content_screens/manage_folder_screen.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Root management screen. Handles import/export and renders the
/// root folder contents via [ManageFolderScreen].
class ManageContentScreen extends StatelessWidget {
  final AppDatabase db;

  const ManageContentScreen({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageContentTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: l10n.contentPacksTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ContentPacksScreen(db: db)),
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
      floatingActionButton: Column(
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
      body: FolderContentsBody(db: db, folder: null),
    );
  }

  // ── JSON export ─────────────────────────────────────────────────

  Future<void> _exportJson(BuildContext context) async {
    try {
      final data = await db.exportToJsonMap();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'med_brew_export.json'));
      await file.writeAsString(jsonString);

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to ${file.path}')),
          );
        }
      } else {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Leerlus export',
        );
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

  // ── JSON import ─────────────────────────────────────────────────

  Future<void> _importJson(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      await db.importFromJson(data);
      await QuestionService().refresh();

      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importSuccess)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailed(e))),
        );
      }
    }
  }
}
