import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leerlus/utils/image_storage.dart';
import 'package:path/path.dart' as p;

/// Guards the two rules that keep image files from stepping on each other.
///
///  - The stored name carries the file's content, so replacing a picture and
///    picking it again under the same original name produces a *different*
///    file instead of overwriting the old one (and every question pointing at
///    it silently changing image).
///  - Only files already stored in the content folder may be deleted. A picked
///    file is not copied until save, so it is still an absolute path pointing at
///    the user's own file — deleting that would destroy something we never
///    owned.
void main() {
  group('hashedImageName', () {
    test('is stable for identical bytes and differs for different bytes', () {
      final a = hashedImageName([1, 2, 3], 'photo.png');
      final b = hashedImageName([1, 2, 3], 'photo.png');
      final c = hashedImageName([1, 2, 4], 'photo.png');

      expect(a, b);
      expect(a, isNot(c));
      expect(a, startsWith('photo_'));
      expect(p.extension(a), '.png');
    });

    test('re-storing an already-hashed name is idempotent', () {
      final once = hashedImageName([9, 9, 9], 'scan.jpg');
      final twice = hashedImageName([9, 9, 9], once);

      expect(twice, once);
    });

    test('a changed picture under a hashed name gets a new name', () {
      final old = hashedImageName([1], 'chart.png');
      final updated = hashedImageName([2], old);

      expect(updated, isNot(old));
      expect(updated, startsWith('chart_'));
    });
  });

  group('isStoredMedia', () {
    test('a bare filename is stored, an absolute path is not', () {
      expect(isStoredMedia('photo_1a2b3c4d.png'), isTrue);
      expect(isStoredMedia('clip_00ff11ee.mp4'), isTrue);
    });

    test('a freshly picked file is rejected', () {
      // Still pointing at the user's own file until save copies it in.
      expect(
        isStoredMedia(p.join(Directory.systemTemp.path, 'downloads', 'a.png')),
        isFalse,
      );
      expect(isStoredMedia(p.absolute('a.png')), isFalse);
    });

    test('empty and null are rejected', () {
      expect(isStoredMedia(''), isFalse);
      expect(isStoredMedia(null), isFalse);
    });
  });
}
