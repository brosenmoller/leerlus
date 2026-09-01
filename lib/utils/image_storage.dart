import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/utils/app_storage.dart';

/// Single home for reading, writing and forgetting user media files.
///
/// The debug/release split used to be copy-pasted into every screen that
/// touched an image, which is how the two halves of the re-upload bug slipped
/// in: same-named files silently overwrote each other, and nothing ever evicted
/// the decoded bitmap Flutter had already cached under that path.
///
/// Stored values are **bare filenames**, not paths. The content hash in the
/// name (see [hashedImageName]) already makes them unique, and sync and `.lus`
/// archives have always transmitted basenames because an absolute path is
/// meaningless on another device. Keeping the database in that same form means
/// the content folder can be renamed, moved or made configurable without ever
/// rewriting stored data again.

Directory? _contentDir;

/// Resolves the content folder. Must be awaited in `main()` before any widget
/// renders, because [imageProviderFor] is synchronous.
///
/// Lives inside [getAppStorageDir] alongside `leerlus.db` and the Hive boxes,
/// so it inherits that helper's `debug/` subdirectory: a debug build can never
/// read, overwrite or delete the real library.
Future<Directory> initContentDir() async {
  final existing = _contentDir;
  if (existing != null) return existing;
  final base = await getAppStorageDir();
  final dir = Directory(p.join(base.path, 'content'));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return _contentDir = dir;
}

/// The content folder. Throws if [initContentDir] has not completed.
Directory get contentDir {
  final dir = _contentDir;
  if (dir == null) {
    throw StateError('initContentDir() must be awaited before use');
  }
  return dir;
}

/// Resolves a stored filename to a file on disk.
///
/// An absolute path passes through untouched: between picking a file and
/// saving, a slot still holds the user's own path (their Downloads folder, a
/// USB stick) so the editors can preview it before anything is copied.
File mediaFileFor(String name) =>
    p.isAbsolute(name) ? File(name) : File(p.join(contentDir.path, name));

/// The provider [AppImage] renders a name with. Eviction has to build the same
/// provider — and therefore the same cache key — as the widget, so both go
/// through here.
ImageProvider imageProviderFor(String name) => FileImage(mediaFileFor(name));

final _hashSuffix = RegExp(r'_[0-9a-f]{8}$');

/// `photo.png` → `photo_1a2b3c4d.png`, keyed on the file's content.
///
/// Storing under the original basename meant a *different* picture picked from
/// a file that happened to reuse a name replaced the old one on disk, and every
/// question already pointing at that name silently changed image. Content in
/// the name makes those two different files. It is still a plain basename, so
/// sync (`/sync/image` resolves by [p.basename]) and `.lus` archives keep
/// working unchanged.
///
/// An existing hash suffix is replaced rather than appended to, so re-storing
/// an already-stored image is idempotent.
String hashedImageName(List<int> bytes, String originalName) {
  final ext = p.extension(originalName);
  final base = p
      .basenameWithoutExtension(originalName)
      .replaceFirst(_hashSuffix, '');
  final digest = md5.convert(bytes).toString().substring(0, 8);
  return '${base}_$digest$ext';
}

/// Copies any attachment — image, audio or video — into the content folder and
/// returns its stored **filename**, or null if the copy failed.
Future<String?> copyMediaIntoStorage(String sourcePath) async {
  try {
    final bytes = await File(sourcePath).readAsBytes();
    final name = hashedImageName(bytes, p.basename(sourcePath));
    final dest = File(p.join(contentDir.path, name));
    // Same name ⇒ same content, so an existing file already *is* this media.
    if (!dest.existsSync() || dest.lengthSync() != bytes.length) {
      await dest.writeAsBytes(bytes, flush: true);
    }
    await evictImageCache(name);
    return name;
  } catch (_) {
    return null;
  }
}

/// Image-only alias, kept for the cover-art picker which never handles clips.
Future<String?> copyImageIntoStorage(String sourcePath) =>
    copyMediaIntoStorage(sourcePath);

/// Drops any decoded bitmap cached for [name].
///
/// Flutter keys `FileImage` on the path string alone — mtime and size are not
/// part of the key — so a file replaced at the same path keeps serving the old
/// decode forever. Call this whenever a name starts pointing at different
/// bytes: on pick, on copy, on delete.
Future<void> evictImageCache(String? name) async {
  if (name == null || name.isEmpty) return;
  // Audio and video never enter Flutter's image cache, and building an
  // ImageProvider for a .mp4 would only decode-fail. Nothing to forget.
  if (!mediaKindOf(name).isImage) return;
  try {
    await imageProviderFor(name).evict();
  } catch (_) {}
}

/// Whether [name] is already stored in the content folder, and therefore needs
/// no copy and is safe to delete.
///
/// A freshly picked file is not copied until save, so its value is still an
/// absolute path pointing at the user's own file — deleting that would be
/// destructive.
bool isStoredMedia(String? name) =>
    name != null && name.isNotEmpty && !p.isAbsolute(name);

/// Deletes a file from the content folder and forgets its cached decode.
/// Silent if the file is already gone.
Future<void> deleteAppImageFile(String name) async {
  try {
    final file = mediaFileFor(name);
    if (file.existsSync()) await file.delete();
  } catch (_) {}
  await evictImageCache(name);
}

/// Size of the file at [sourcePath] in bytes, or null if it can't be read.
Future<int?> mediaFileSize(String sourcePath) async {
  try {
    return await File(sourcePath).length();
  } catch (_) {
    return null;
  }
}

/// Attachments above this size make sync slow and bloat `.lus` exports, so the
/// picker warns once before accepting one. It is a warning, never a block.
const largeMediaWarningBytes = 25 * 1024 * 1024;
