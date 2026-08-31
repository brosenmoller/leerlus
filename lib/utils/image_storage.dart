import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:leerlus/models/media_kind.dart';

/// Single home for reading, writing and forgetting user image files.
///
/// The debug/release split used to be copy-pasted into every screen that
/// touched an image, which is how the two halves of the re-upload bug slipped
/// in: same-named files silently overwrote each other, and nothing ever evicted
/// the decoded bitmap Flutter had already cached under that path.

/// Where user images live. Debug builds write into the repo's `assets/images/`
/// and store the *asset key*, so the running app reads them through the
/// compiled bundle; release builds use `<documents>/images` and store absolute
/// paths.
Future<Directory> appImagesDir({bool create = false}) async {
  final dir = kDebugMode
      ? Directory(p.join(Directory.current.path, 'assets', 'images'))
      : Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'images'));
  if (create && !dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// The provider [AppImage] renders a path with. Eviction has to build the same
/// provider — and therefore the same cache key — as the widget, so both go
/// through here.
ImageProvider imageProviderFor(String path) => path.startsWith('assets/')
    ? AssetImage(path)
    : FileImage(File(path));

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

/// Copies [sourcePath] into app storage and returns the stored path (the asset
/// key in debug, an absolute path in release), or null if the copy failed.
Future<String?> copyImageIntoStorage(String sourcePath) async {
  try {
    final bytes = await File(sourcePath).readAsBytes();
    final dir = await appImagesDir(create: true);
    final name = hashedImageName(bytes, p.basename(sourcePath));
    final dest = File(p.join(dir.path, name));
    // Same name ⇒ same content, so an existing file already *is* this image.
    if (!dest.existsSync() || dest.lengthSync() != bytes.length) {
      await dest.writeAsBytes(bytes, flush: true);
    }
    final stored = kDebugMode ? 'assets/images/$name' : dest.path;
    await evictImageCache(stored);
    return stored;
  } catch (_) {
    return null;
  }
}

/// Drops any decoded bitmap cached for [path].
///
/// Flutter keys `FileImage`/`AssetImage` on the path string alone — mtime and
/// size are not part of the key — so a file replaced at the same path keeps
/// serving the old decode forever. Call this whenever a path starts pointing at
/// different bytes: on pick, on copy, on delete.
Future<void> evictImageCache(String? path) async {
  if (path == null || path.isEmpty) return;
  // Audio and video never enter Flutter's image cache, and building an
  // ImageProvider for a .mp4 would only decode-fail. Nothing to forget.
  if (!mediaKindOf(path).isImage) return;
  try {
    await imageProviderFor(path).evict();
  } catch (_) {}
}

/// Whether [path] is a file this app owns and may therefore delete. A picked
/// image is not copied until save, so its path still points at the user's own
/// file (their Downloads folder, a USB stick) — deleting that would be
/// destructive.
Future<bool> isInAppImageStorage(String path) async {
  if (path.isEmpty) return false;
  final dir = await appImagesDir();
  return p.isWithin(dir.path, p.absolute(path));
}

/// Deletes an image from app storage and forgets its cached decode. Silent if
/// the file is already gone.
Future<void> deleteAppImageFile(String path) async {
  try {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  } catch (_) {}
  await evictImageCache(path);
}

/// Copies any attachment — image, audio or video — into app storage and returns
/// the stored path, or null if the copy failed.
///
/// Images keep [copyImageIntoStorage]'s behaviour exactly, including the debug
/// build storing an `assets/images/...` asset key. Audio and video always get
/// the **absolute** path instead: media_kit plays a real file, and a file
/// written into the repo at runtime is not in the compiled asset bundle, so an
/// asset key would simply fail to open in debug.
Future<String?> copyMediaIntoStorage(String sourcePath) async {
  if (mediaKindOf(sourcePath).isImage) return copyImageIntoStorage(sourcePath);
  try {
    final bytes = await File(sourcePath).readAsBytes();
    final dir = await appImagesDir(create: true);
    final name = hashedImageName(bytes, p.basename(sourcePath));
    final dest = File(p.join(dir.path, name));
    // Same name ⇒ same content, so an existing file already *is* this clip.
    if (!dest.existsSync() || dest.lengthSync() != bytes.length) {
      await dest.writeAsBytes(bytes, flush: true);
    }
    return dest.path;
  } catch (_) {
    return null;
  }
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
