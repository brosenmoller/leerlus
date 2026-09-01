import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/utils/image_storage.dart';

/// Moves user media into the app-scoped content folder, once.
///
/// Before this, release builds wrote into `<documents>/images` — on Windows that
/// is the bare `C:\Users\<name>\Documents`, with no app subfolder, so the app was
/// dropping an unscoped `images/` folder into the user's own Documents. Debug
/// builds additionally wrote into the repo's `assets/images` and stored Flutter
/// *asset keys*, which only resolve for files present when the bundle was built —
/// so a freshly added image rendered blank until the next restart.
///
/// Both are replaced by [contentDir], and the database now stores bare
/// filenames resolved against it.
///
/// Deliberately **copies rather than moves**: the old library stays intact as a
/// backup until the user deletes it themselves. Everything here is idempotent —
/// files already present are skipped and re-basenaming is a no-op — so a run
/// interrupted halfway simply finishes on the next launch.
class MediaMigration {
  /// Written once the migration has completed. Kept inside the content folder
  /// rather than in settings so it describes the folder it guards: wipe the
  /// folder and the migration correctly runs again.
  static const _markerName = '.migrated_v1';

  /// Returns the number of files copied and rows rewritten, or null if the
  /// migration had already run.
  static Future<({int filesCopied, int rowsRewritten})?> run(
      AppDatabase db) async {
    final marker = File(p.join(contentDir.path, _markerName));
    if (marker.existsSync()) return null;

    final filesCopied = await _copyLegacyFiles();
    final rowsRewritten = await db.normalizeMediaPathsToBasenames();

    marker.writeAsStringSync(DateTime.now().toIso8601String());
    debugPrint('[media] migrated $filesCopied file(s), '
        '$rowsRewritten row(s) into ${contentDir.path}');
    return (filesCopied: filesCopied, rowsRewritten: rowsRewritten);
  }

  /// Every folder media used to live in, newest scheme first.
  ///
  /// Both are checked in both build modes, deliberately. Release only ever wrote
  /// to `<documents>/images`, but *debug* wrote to two places over time: the repo
  /// for anything added after the asset-key scheme landed, and `<documents>/images`
  /// for everything before it — which is the bulk of the library. Checking only
  /// the repo would leave a debug database pointing at files that were never
  /// copied across.
  ///
  /// A release build simply finds no repo folder and skips it.
  static Future<List<Directory>> _legacyDirs() async {
    final docs = await getApplicationDocumentsDirectory();
    return [
      Directory(p.join(docs.path, 'images')),
      Directory(p.join(Directory.current.path, 'assets', 'images')),
    ];
  }

  static Future<int> _copyLegacyFiles() async {
    var copied = 0;
    for (final legacy in await _legacyDirs()) {
      if (!legacy.existsSync()) continue;
      // Guards a future configurable location from copying a folder onto itself.
      if (p.equals(legacy.path, contentDir.path)) continue;

      for (final entity in legacy.listSync()) {
        if (entity is! File) continue;
        if (!isMediaPath(entity.path)) continue;
        // Names are preserved verbatim. They are what the database references,
        // and older files predate the content-hash scheme — re-hashing here
        // would rename them out from under every question pointing at them.
        final dest = File(p.join(contentDir.path, p.basename(entity.path)));
        if (dest.existsSync()) continue;
        try {
          entity.copySync(dest.path);
          copied++;
        } catch (e) {
          debugPrint('[media] could not copy ${entity.path}: $e');
        }
      }
    }
    return copied;
  }
}
