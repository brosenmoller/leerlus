import 'package:flutter_test/flutter_test.dart';
import 'package:leerlus/models/answer_configs.dart';

/// Tests for [SortingConfig]'s new alternatives + manualAddItems support and its
/// normalized typed-mode matching, including backward compatibility with configs
/// stored before these fields existed.
void main() {
  group('SortingConfig', () {
    test('legacy config (items + showPreFilled only) round-trips', () {
      final legacy = {
        'items': ['a', 'b', 'c'],
        'showPreFilled': false,
      };
      final config = SortingConfig.fromJson(legacy);

      expect(config.items, ['a', 'b', 'c']);
      expect(config.showPreFilled, false);
      expect(config.manualAddItems, false);
      // alternatives are sized to match items even when absent.
      expect(config.alternatives, [[], [], []]);

      // toJson stays compact: no alternatives / manualAddItems keys emitted.
      final json = config.toJson();
      expect(json.containsKey('alternatives'), false);
      expect(json.containsKey('manualAddItems'), false);
      expect(json['items'], ['a', 'b', 'c']);
      expect(json['showPreFilled'], false);
    });

    test('alternatives and manualAddItems round-trip', () {
      final config = SortingConfig(
        items: ['Mitochondrion', 'Nucleus'],
        alternatives: [
          ['mitochondria'],
          [],
        ],
        showPreFilled: false,
        manualAddItems: true,
      );

      final restored = SortingConfig.fromJson(config.toJson());
      expect(restored.items, ['Mitochondrion', 'Nucleus']);
      expect(restored.alternatives, [
        ['mitochondria'],
        [],
      ]);
      expect(restored.manualAddItems, true);
      expect(restored.showPreFilled, false);
    });

    test('_sizeAlternatives pads/truncates to match items length', () {
      final config = SortingConfig(
        items: ['a', 'b', 'c'],
        alternatives: [
          ['x'],
        ], // fewer than items -> padded
      );
      expect(config.alternatives.length, 3);
      expect(config.alternatives[0], ['x']);
      expect(config.alternatives[1], []);
      expect(config.alternatives[2], []);
    });

    test('matchesAt is normalized (case/punctuation-insensitive) and honors alternatives', () {
      final config = SortingConfig(
        items: ['Mitochondrion', 'Golgi apparatus'],
        alternatives: [
          ['mitochondria'],
          [],
        ],
        showPreFilled: false,
      );

      // Canonical, case-insensitive.
      expect(config.matchesAt(0, 'mitochondrion'), true);
      // Alternative accepted.
      expect(config.matchesAt(0, 'Mitochondria'), true);
      // Punctuation/whitespace ignored.
      expect(config.matchesAt(1, 'golgi-apparatus'), true);
      // Wrong slot / wrong answer rejected.
      expect(config.matchesAt(0, 'Nucleus'), false);
      expect(config.matchesAt(1, 'mitochondria'), false);
    });
  });
}
