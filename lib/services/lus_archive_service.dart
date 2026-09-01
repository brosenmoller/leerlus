import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'package:leerlus/utils/image_storage.dart';

class LusArchiveException implements Exception {
  final String message;
  const LusArchiveException(this.message);
  @override
  String toString() => 'LusArchiveException: $message';
}

/// Thrown by [CancellableLusEncode.result] when the encode was cancelled.
class LusEncodeCancelled implements Exception {
  const LusEncodeCancelled();
  @override
  String toString() => 'LusEncodeCancelled';
}

/// A ZIP encode running in a background isolate that can be hard-cancelled.
///
/// [result] completes with the encoded `.lus` bytes, or throws
/// [LusEncodeCancelled] if [cancel] was called, or the underlying error if
/// encoding failed.
class CancellableLusEncode {
  final Isolate _isolate;
  final ReceivePort _port;
  final Completer<Uint8List> _completer = Completer<Uint8List>();
  bool _done = false;

  CancellableLusEncode._(this._isolate, this._port) {
    _port.listen((message) {
      if (_done) return;
      _done = true;
      _port.close();
      _isolate.kill(priority: Isolate.immediate);
      if (message is Uint8List) {
        _completer.complete(message);
      } else if (message is List && message.length == 2 && message[0] == '_e') {
        _completer.completeError(LusArchiveException(message[1].toString()));
      } else {
        _completer.completeError(
          const LusArchiveException('Unexpected encode result'),
        );
      }
    });
  }

  Future<Uint8List> get result => _completer.future;

  /// Immediately kills the background isolate and fails [result] with
  /// [LusEncodeCancelled]. No-op once the encode has already finished.
  void cancel() {
    if (_done) return;
    _done = true;
    _port.close();
    _isolate.kill(priority: Isolate.immediate);
    _completer.completeError(const LusEncodeCancelled());
  }

  /// Spawns a background isolate that ZIP-encodes the given archive [entries]
  /// (path → bytes) and returns a handle to await or cancel the work.
  static Future<CancellableLusEncode> start(
    Map<String, Uint8List> entries,
  ) async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(
      _encodeIsolateEntry,
      [port.sendPort, entries],
    );
    return CancellableLusEncode._(isolate, port);
  }
}

/// Isolate entry point: builds the archive from [path → bytes] entries and
/// encodes it, sending the resulting [Uint8List] (or an error marker) back.
void _encodeIsolateEntry(List<dynamic> args) {
  final SendPort sendPort = args[0] as SendPort;
  final entries = args[1] as Map<String, Uint8List>;
  try {
    final archive = Archive();
    entries.forEach((name, bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      sendPort.send(['_e', 'Failed to encode archive']);
      return;
    }
    sendPort.send(Uint8List.fromList(encoded));
  } catch (e) {
    sendPort.send(['_e', e.toString()]);
  }
}

/// A ZIP decode + image extraction running in a background isolate that can be
/// hard-cancelled.
///
/// [result] completes with the localized `content.json` map (image paths
/// rewritten to on-disk paths), or throws [LusEncodeCancelled] if [cancel] was
/// called, or the underlying error if decoding failed.
class CancellableLusDecode {
  final Isolate _isolate;
  final ReceivePort _port;
  final Completer<Map<String, dynamic>> _completer =
      Completer<Map<String, dynamic>>();
  bool _done = false;

  CancellableLusDecode._(this._isolate, this._port) {
    _port.listen((message) {
      if (_done) return;
      _done = true;
      _port.close();
      _isolate.kill(priority: Isolate.immediate);
      if (message is List && message.length == 2 && message[0] == '_e') {
        _completer.completeError(LusArchiveException(message[1].toString()));
      } else if (message is Map) {
        _completer.complete(Map<String, dynamic>.from(message));
      } else {
        _completer.completeError(
          const LusArchiveException('Unexpected decode result'),
        );
      }
    });
  }

  Future<Map<String, dynamic>> get result => _completer.future;

  /// Immediately kills the background isolate and fails [result] with
  /// [LusEncodeCancelled]. No-op once the decode has already finished.
  void cancel() {
    if (_done) return;
    _done = true;
    _port.close();
    _isolate.kill(priority: Isolate.immediate);
    _completer.completeError(const LusEncodeCancelled());
  }

  /// Spawns a background isolate that ZIP-decodes [lusBytes], extracts its
  /// images into the app images directory, and returns a handle to await or
  /// cancel the work. The images directory is resolved on the calling isolate
  /// (plugin access must stay on the main isolate) and passed in.
  static Future<CancellableLusDecode> start(Uint8List lusBytes) async {
    final imgDir = contentDir.path;
    final port = ReceivePort();
    final isolate = await Isolate.spawn(
      _decodeIsolateEntry,
      [port.sendPort, lusBytes, imgDir],
    );
    return CancellableLusDecode._(isolate, port);
  }
}

/// Isolate entry point: decodes the `.lus` [lusBytes], extracts its images into
/// the given images dir, and sends the localized content map back (or an error
/// marker).
void _decodeIsolateEntry(List<dynamic> args) {
  final SendPort sendPort = args[0] as SendPort;
  final lusBytes = args[1] as Uint8List;
  final imgDir = args[2] as String;
  try {
    sendPort.send(LusArchiveService.decodeAndLocalize(lusBytes, imgDir));
  } on LusArchiveException catch (e) {
    sendPort.send(['_e', e.message]);
  } catch (e) {
    sendPort.send(['_e', e.toString()]);
  }
}

/// Handles packing/unpacking the .lus ZIP archive format.
///
/// A .lus file is a ZIP containing:
///   content.json   — the standard export JSON with image paths as basenames
///   images/        — all referenced user image files
///
/// Asset paths (starting with "assets/") are bundled in the app and are
/// left unchanged in content.json; their files are not included in the ZIP.
class LusArchiveService {
  static Future<Uint8List> packToLus(Map<String, dynamic> contentJson) async {
    final entries = await gatherEntries(contentJson);
    final encode = await CancellableLusEncode.start(entries);
    return encode.result;
  }

  /// Gathers all archive entries (path → bytes) on the calling isolate: the
  /// `content.json` blob plus every referenced user image file. The heavy ZIP
  /// encoding is done separately (see [CancellableLusEncode]) so it can run in
  /// a background isolate and be cancelled.
  static Future<Map<String, Uint8List>> gatherEntries(
    Map<String, dynamic> contentJson,
  ) async {
    final normalized = _normalizeImagePaths(contentJson);
    final basenames = _collectImageBasenames(contentJson);
    final imgDir = contentDir.path;

    final entries = <String, Uint8List>{};
    entries['content.json'] = Uint8List.fromList(
      const Utf8Encoder().convert(
        const JsonEncoder.withIndent('  ').convert(normalized),
      ),
    );

    for (final name in basenames) {
      final file = File(p.join(imgDir, name));
      if (!await file.exists()) continue;
      entries['images/$name'] = await file.readAsBytes();
    }

    return entries;
  }

  static Future<Map<String, dynamic>> unpackFromLus(Uint8List lusBytes) async {
    final imgDir = contentDir.path;
    return decodeAndLocalize(lusBytes, imgDir);
  }

  /// Decodes [lusBytes], extracts its images into [imgDir] (skipping images
  /// that already exist), and returns the localized `content.json` map (image
  /// paths rewritten to on-disk paths). Uses synchronous file I/O so it can run
  /// unchanged inside a background isolate (see [CancellableLusDecode]).
  static Map<String, dynamic> decodeAndLocalize(
    Uint8List lusBytes,
    String imgDir,
  ) {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(lusBytes);
    } catch (_) {
      throw const LusArchiveException('Not a valid .lus archive');
    }

    final contentEntry = archive.findFile('content.json');
    if (contentEntry == null) {
      throw const LusArchiveException('Archive is missing content.json');
    }

    final contentJson = jsonDecode(
      const Utf8Decoder().convert(contentEntry.content as List<int>),
    ) as Map<String, dynamic>;

    for (final entry in archive) {
      if (!entry.name.startsWith('images/')) continue;
      final safeName = p.basename(entry.name);
      if (safeName.isEmpty) continue;
      final localFile = File(p.join(imgDir, safeName));
      if (localFile.existsSync()) continue;
      localFile.writeAsBytesSync(entry.content as List<int>);
    }

    // Both directions reduce to a basename now that the database stores
    // filenames. Older archives may carry absolute paths, so import still has
    // to normalize rather than trust what it is given.
    return _normalizeImagePaths(contentJson);
  }

  // ── Path helpers ─────────────────────────────────────────────────────────

  static bool _isUserPath(String? path) => path != null && path.isNotEmpty;

  static String? _normalizePath(String? path) =>
      _isUserPath(path) ? p.basename(path!) : path;

  // ── Collect image basenames from original (un-normalized) JSON ───────────

  static Set<String> _collectImageBasenames(Map<String, dynamic> json) {
    final names = <String>{};

    void add(String? path) {
      if (_isUserPath(path)) names.add(p.basename(path!));
    }

    for (final f in (json['folders'] as List? ?? [])) {
      add((f as Map)['imagePath'] as String?);
    }
    for (final q in (json['quizzes'] as List? ?? [])) {
      add((q as Map)['imagePath'] as String?);
    }
    for (final q in (json['questions'] as List? ?? [])) {
      final qm = q as Map;
      add(qm['imagePath'] as String?);
      for (final v in (qm['imagePathVariants'] as List? ?? [])) {
        add(v as String?);
      }
      final fc = qm['flashcardConfig'] as Map?;
      if (fc != null) {
        add(fc['frontImagePath'] as String?);
        add(fc['backImagePath'] as String?);
      }
    }

    return names;
  }

  // ── Normalize: full paths → basenames ────────────────────────────────────

  static Map<String, dynamic> _normalizeImagePaths(Map<String, dynamic> json) {
    return {
      ...json,
      'folders': (json['folders'] as List? ?? []).map((f) {
        final m = Map<String, dynamic>.from(f as Map);
        m['imagePath'] = _normalizePath(m['imagePath'] as String?);
        return m;
      }).toList(),
      'quizzes': (json['quizzes'] as List? ?? []).map((q) {
        final m = Map<String, dynamic>.from(q as Map);
        m['imagePath'] = _normalizePath(m['imagePath'] as String?);
        return m;
      }).toList(),
      'questions': (json['questions'] as List? ?? []).map((q) {
        final m = Map<String, dynamic>.from(q as Map);
        m['imagePath'] = _normalizePath(m['imagePath'] as String?);
        m['imagePathVariants'] = (m['imagePathVariants'] as List?)
            ?.map((v) => _normalizePath(v as String?))
            .toList();
        final fc = m['flashcardConfig'] as Map?;
        if (fc != null) {
          final fc2 = Map<String, dynamic>.from(fc);
          fc2['frontImagePath'] =
              _normalizePath(fc2['frontImagePath'] as String?);
          fc2['backImagePath'] =
              _normalizePath(fc2['backImagePath'] as String?);
          m['flashcardConfig'] = fc2;
        }
        return m;
      }).toList(),
    };
  }

}
