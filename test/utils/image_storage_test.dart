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
///  - Only files inside app storage may be deleted. A picked image is not
///    copied until save, so its path still points at the user's own file.
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

  group('isInAppImageStorage', () {
    test('accepts a file in the images dir, rejects one outside it', () async {
      final dir = await appImagesDir();

      expect(await isInAppImageStorage(p.join(dir.path, 'a.png')), isTrue);
      expect(
        await isInAppImageStorage(
            p.join(Directory.systemTemp.path, 'downloads', 'a.png')),
        isFalse,
      );
      expect(await isInAppImageStorage(''), isFalse);
    });
  });
}
