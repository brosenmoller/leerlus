import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:leerlus/models/user_question_data.dart' show SrsQuality;
import 'package:leerlus/services/statistics_service.dart';

/// Tests for [StatisticsService.mergeFromSync]. The regression that motivated
/// the per-origin counters: merging with `max` meant 5 answers here + 7 there
/// showed up as 7, silently discarding the smaller device's work.
///
/// Both "devices" share one Hive box; a device switch is `_resetAs`, which
/// clears the box and swaps the recording origin.
void main() {
  late Directory tempDir;
  late Box box;
  final svc = StatisticsService();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('statistics_merge_test');
    Hive.init(tempDir.path);
    await svc.init();
    box = Hive.box(StatisticsService.boxName);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  Future<void> resetAs(String origin) async {
    await box.clear();
    await svc.debugUseOrigin(origin);
  }

  setUp(() => resetAs('device-a'));

  /// Payloads cross the wire as JSON, so round-trip them — this also proves the
  /// nested counter maps survive encoding.
  Map<String, dynamic> wire(Map<String, dynamic> payload) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(payload)) as Map);

  void answer(int times, {bool correct = true, bool srs = false}) {
    for (var i = 0; i < times; i++) {
      svc.recordAnswer('typed', correct, srs);
    }
  }

  String todayKey() {
    final n = DateTime.now();
    return 'stats_day_${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  test('same-day counts from two devices add up instead of taking the max',
      () async {
    answer(5); // device A: 5 correct
    final fromA = wire(svc.exportForSync());

    await resetAs('device-b');
    answer(7, correct: false); // device B: 7 wrong
    expect(await svc.mergeFromSync(fromA), isTrue);

    expect(svc.getTotalAnswered(), 12);
    expect(svc.getTotalCorrect(), 5);
    expect(svc.getTodayData()!['answered'], 12);
    expect(svc.getAnswerTypeCounts()['typed'],
        {'answered': 12, 'correct': 5});
  });

  test('merging the same payload twice does not inflate totals', () async {
    answer(5);
    final fromA = wire(svc.exportForSync());

    await resetAs('device-b');
    answer(7, correct: false);
    await svc.mergeFromSync(fromA);

    expect(await svc.mergeFromSync(fromA), isFalse);
    expect(svc.getTotalAnswered(), 12);
  });

  test('a round trip back to the originating device does not double count',
      () async {
    answer(5);
    final fromA = wire(svc.exportForSync());

    await resetAs('device-b');
    answer(7, correct: false);
    await svc.mergeFromSync(fromA);
    final fromB = wire(svc.exportForSync()); // already contains A's counts

    await resetAs('device-a');
    answer(5); // A's own history again
    expect(await svc.mergeFromSync(fromB), isTrue);
    expect(svc.getTotalAnswered(), 12); // not 17
  });

  test('three devices converge on the true total in any merge order',
      () async {
    answer(5);
    final fromA = wire(svc.exportForSync());

    await resetAs('device-b');
    answer(7);
    final fromB = wire(svc.exportForSync());

    await resetAs('device-c');
    answer(3);
    await svc.mergeFromSync(fromB);
    await svc.mergeFromSync(fromA);
    expect(svc.getTotalAnswered(), 15);

    // Same inputs, opposite order.
    await resetAs('device-c');
    answer(3);
    await svc.mergeFromSync(fromA);
    await svc.mergeFromSync(fromB);
    expect(svc.getTotalAnswered(), 15);
  });

  test('sessions, srs revisions, srs quality and perfect sessions all add up',
      () async {
    answer(2, srs: true);
    await svc.recordSessionComplete(true);
    await svc.recordPerfectSession();
    await svc.recordSrsQuality(SrsQuality.good);
    final fromA = wire(svc.exportForSync());

    await resetAs('device-b');
    answer(3, srs: true);
    await svc.recordSessionComplete(true);
    await svc.recordPerfectSession();
    await svc.recordSrsQuality(SrsQuality.good);
    await svc.recordSrsQuality(SrsQuality.again);
    await svc.mergeFromSync(fromA);

    expect(svc.getTotalSrsRevisions(), 5);
    expect(svc.getTotalSessions(), 2);
    expect(svc.getTotalPerfectSessions(), 2);
    expect(svc.getSrsQuality()['good'], 2);
    expect(svc.getSrsQuality()['again'], 1);
  });

  test('pre-existing flat counts read correctly and still max-merge', () async {
    // Data written before per-device counters: bare ints, already max-merged on
    // both devices, so the true split is unknowable.
    await box.put(todayKey(), {'answered': 40, 'correct': 30});
    await box.put('stats_answer_type_counts', {
      'typed': {'answered': 40, 'correct': 30}
    });
    await box.put('stats_srs_quality', {'good': 12});
    await box.put('stats_total_perfect_sessions', 4);

    expect(svc.getTotalAnswered(), 40);
    expect(svc.getSrsQuality()['good'], 12);
    expect(svc.getTotalPerfectSessions(), 4);

    // A peer's legacy bucket is the same shared origin — max, never a sum.
    await svc.mergeFromSync(wire({
      'dailyDataV2': {
        todayKey(): {
          'answered': {'legacy': 45},
          'correct': {'legacy': 30},
        }
      },
      'totalPerfectSessionsV2': {'legacy': 3},
    }));
    expect(svc.getTotalAnswered(), 45); // not 85
    expect(svc.getTotalPerfectSessions(), 4); // ours was higher

    // New activity on top of legacy data is exact.
    answer(1);
    expect(svc.getTotalAnswered(), 46);
  });

  test('a payload from an old peer (no V2 keys) merges without throwing',
      () async {
    answer(5);
    expect(
        await svc.mergeFromSync(wire({
          'dailyData': {
            todayKey(): {'answered': 9, 'correct': 4}
          },
          'answerTypeCounts': {
            'typed': {'answered': 9, 'correct': 4}
          },
          'srsQuality': {'good': 2},
          'totalPerfectSessions': 1,
        })),
        isTrue);

    // Old-style totals land in the shared legacy bucket: added to our own
    // origin's counts, and max-merged against any other legacy counts.
    expect(svc.getTotalAnswered(), 14);
    expect(svc.getSrsQuality()['good'], 2);
    expect(svc.getTotalPerfectSessions(), 1);
  });

  test('exportForSync still carries flat totals for old peers', () {
    answer(5);
    final payload = svc.exportForSync();
    expect((payload['dailyData'] as Map)[todayKey()],
        {'answered': 5, 'correct': 5});
    expect(payload['answerTypeCounts'],
        {'typed': {'answered': 5, 'correct': 5}});
    expect((payload['dailyDataV2'] as Map)[todayKey()], {
      'answered': {'device-a': 5},
      'correct': {'device-a': 5},
    });
  });

  test('hard sync mirrors the peer exactly and keeps our origin id', () async {
    answer(5);
    await resetAs('device-b');
    answer(7);

    await svc.replaceFromSync(wire({
      'dailyDataV2': {
        todayKey(): {
          'answered': {'device-a': 3}
        }
      },
    }));

    expect(svc.getTotalAnswered(), 3); // mirrored, local counts discarded
    expect(box.get('stats_origin_id'), 'device-b');

    // Recording afterwards still goes under our own origin, so a later merge
    // with device A stays additive.
    answer(1);
    expect(svc.getTotalAnswered(), 4);
    expect((svc.exportForSync()['dailyDataV2'] as Map)[todayKey()]['answered'],
        {'device-a': 3, 'device-b': 1});
  });

  test('getActiveDays returns the union of both devices studied days',
      () async {
    // The streak is derived entirely from this set (StreakService
    // .recomputeFromHistory), so a merge must never drop a day.
    await box.put('stats_day_2026-08-10', {
      'answered': {'device-a': 4}
    });
    await svc.mergeFromSync(wire({
      'dailyDataV2': {
        'stats_day_2026-08-11': {
          'answered': {'device-b': 7}
        },
        'stats_day_2026-08-10': {
          'answered': {'device-b': 2}
        },
      }
    }));

    expect(svc.getActiveDays(), {
      DateTime(2026, 8, 10),
      DateTime(2026, 8, 11),
    });
    expect(svc.getBestDayCount(), 7);
    expect(svc.getBestDayKey(), 'stats_day_2026-08-11');
    expect(svc.getTotalAnswered(), 13); // (4 + 2) + 7
  });
}
