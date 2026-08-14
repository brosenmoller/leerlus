import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/services/lus_archive_service.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/settings_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Delay before showing the progress dialog. Quick transfers finish first and
/// never show a dialog (avoids a flash); anything slower shows it promptly.
const _progressDelay = Duration(milliseconds: 500);

/// Awaits [result] while showing a debounced, cancellable progress dialog: the
/// dialog only appears if the work outlasts [_progressDelay], and pressing
/// Cancel invokes [onCancel] (which should hard-cancel the underlying work).
///
/// Returns the result, or rethrows whatever [result] fails with (including
/// [LusEncodeCancelled] when the work was cancelled). The dialog is always
/// closed and the debounce timer cancelled before returning.
Future<T> _awaitWithProgress<T>(
  BuildContext context, {
  required Future<T> result,
  required VoidCallback onCancel,
  required String progressLabel,
  required String cancelLabel,
}) async {
  var dialogOpen = false;

  final timer = Timer(_progressDelay, () {
    if (!context.mounted) return;
    dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(progressLabel),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
        ],
      ),
    );
  });

  try {
    return await result;
  } finally {
    timer.cancel();
    if (dialogOpen && context.mounted) Navigator.of(context).pop();
  }
}

/// Runs a `.lus` export end-to-end with a save-location dialog (desktop), a
/// debounced cancellable progress dialog, and the right delivery per platform
/// (write-to-chosen-path + snackbar on desktop, share sheet on mobile).
///
/// [startEncode] gathers the content and starts a background ZIP encode. It is
/// invoked once the destination is known (so the desktop save dialog appears
/// *before* any heavy work begins).
Future<void> runLusExport(
  BuildContext context, {
  required String defaultFileName,
  required Future<CancellableLusEncode> Function() startEncode,
  required String shareSubject,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  // 1. Resolve the destination path.
  String destPath;
  if (isDesktop) {
    final chosen = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportSaveDialogTitle,
      fileName: defaultFileName,
      initialDirectory: SettingsService().lastExportDirectory,
      type: FileType.custom,
      allowedExtensions: ['lus'],
    );
    if (chosen == null) return; // user cancelled the save dialog
    destPath = chosen.toLowerCase().endsWith('.lus') ? chosen : '$chosen.lus';
    await SettingsService().setLastExportDirectory(p.dirname(destPath));
  } else {
    final dir = await getApplicationDocumentsDirectory();
    destPath = p.join(dir.path, defaultFileName);
  }

  try {
    // 2. Start the cancellable background encode and await it behind a
    //    debounced progress dialog.
    final encode = await startEncode();
    var cancelled = false;

    Uint8List bytes;
    try {
      bytes = await _awaitWithProgress<Uint8List>(
        context,
        result: encode.result,
        onCancel: () {
          cancelled = true;
          encode.cancel();
        },
        progressLabel: l10n.exportInProgress,
        cancelLabel: l10n.cancel,
      );
    } on LusEncodeCancelled {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportCancelled)));
      return;
    }
    if (cancelled) return; // raced: cancel pressed just as encode finished

    // 3. Deliver the result.
    final file = File(destPath);
    await file.writeAsBytes(bytes);

    if (isDesktop) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportedTo(file.path))),
      );
    } else {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/zip')],
        subject: shareSubject,
      );
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed(e))));
  }
}

/// Asks whether items already in the library should be overwritten by the ones
/// in the file being imported. Returns the choice, or `null` if the user backed
/// out of the import entirely.
///
/// Defaults to off, so confirming without touching the checkbox keeps the
/// long-standing "skip what's already there" behaviour.
Future<bool?> askImportOptions(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      var updateExisting = false;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.importOptionsTitle),
          contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
          content: CheckboxListTile(
            value: updateExisting,
            onChanged: (v) => setState(() => updateExisting = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.importUpdateExisting),
            subtitle: Text(l10n.importUpdateExistingSubtitle),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(updateExisting),
              child: Text(l10n.contentPacksImport),
            ),
          ],
        ),
      );
    },
  );
}

/// Snackbar text for a finished import, reporting inserts and updates
/// separately — a bare "0 new items" after an update-mode import reads as
/// "already up to date" when it is anything but.
String importSummary(AppLocalizations l10n, ImportResult result) {
  if (result.isEmpty) return l10n.contentPacksAlreadyUpToDate;
  if (result.updated == 0) return l10n.contentPacksImportedCount(result.inserted);
  if (result.inserted == 0) return l10n.importUpdatedCount(result.updated);
  return l10n.importInsertedAndUpdatedCount(result.inserted, result.updated);
}

/// Runs a `.lus` import end-to-end with the import-options dialog and a
/// debounced cancellable progress dialog (mirroring [runLusExport]). The heavy
/// ZIP decode runs in a background isolate so the progress bar stays animated.
///
/// [loadBytes] provides the archive bytes (e.g. from a file picker or a bundled
/// asset); returning `null` aborts silently (nothing selected). [startImport]
/// begins the cancellable background decode + DB import and completes with the
/// insert/update counts, which are reported in the success snackbar.
Future<void> runLusImport(
  BuildContext context, {
  required Future<Uint8List?> Function() loadBytes,
  required Future<CancellableLusImport> Function(
    Uint8List bytes, {
    required bool updateExisting,
  }) startImport,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  try {
    final bytes = await loadBytes();
    if (bytes == null) return; // nothing selected

    if (!context.mounted) return;
    final updateExisting = await askImportOptions(context);
    if (updateExisting == null) return; // backed out
    if (!context.mounted) return;

    final import = await startImport(bytes, updateExisting: updateExisting);
    var cancelled = false;

    ImportResult result;
    try {
      result = await _awaitWithProgress<ImportResult>(
        context,
        result: import.result,
        onCancel: () {
          cancelled = true;
          import.cancel();
        },
        progressLabel: l10n.importInProgress,
        cancelLabel: l10n.cancel,
      );
    } on LusEncodeCancelled {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importCancelled)));
      return;
    }
    if (cancelled) return; // raced: cancel pressed just as decode finished

    await QuestionService().refresh();
    messenger.showSnackBar(SnackBar(content: Text(importSummary(l10n, result))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.importFailed(e))));
  }
}
