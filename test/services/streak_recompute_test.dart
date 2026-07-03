import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:leerlus/services/streak_service.dart';

/// Tests for [StreakService.recomputeFromHistory] / [reconcileOnOpen] — the
/// resolver that rebuilds the streak from the combined set of studied days plus
/// the weekly freeze budget (2 per Mon–Sun week), with a trailing-gap lapse.
void main() {
  late Directory tempDir;

  // Anchor cases to a real Monday so Mon..Sun day offsets stay in one week.
  final monday = () {
    final b = DateTime(2026, 6, 1);
    return b.subtract(Duration(days: b.weekday - 1));
  }();
  DateTime day(int offsetFromMonday) => monday.add(Duration(days: offsetFromMonday));

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('streak_test');
    Hive.init(tempDir.path);
    await StreakService().init();
  });

  setUp(() async {
    await Hive.box('streak').clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  final streak = StreakService();

  test('empty history clears the streak', () async {
    await streak.recomputeFromHistory({}, now: day(0));
    expect(streak.currentStreak, 0);
    expect(streak.lastActivityDate, isNull);
    expect(streak.freezeDates, isEmpty);
  });

  test('contiguous days count fully with no freezes', () async {
    await streak.recomputeFromHistory({day(0), day(1), day(2)}, now: day(2));
    expect(streak.currentStreak, 3);
    expect(streak.freezeDates, isEmpty);
  });

  test('single-day gap within budget is bridged by a freeze', () async {
    await streak.recomputeFromHistory({day(0), day(2)}, now: day(2)); // miss Tue
    expect(streak.currentStreak, 2);
    expect(streak.freezeDaySet(), contains(day(1)));
  });

  test('two missed days in one week are bridged (budget = 2)', () async {
    await streak.recomputeFromHistory({day(0), day(3)}, now: day(3)); // miss Tue,Wed
    expect(streak.currentStreak, 2);
    expect(streak.freezeDaySet(), containsAll([day(1), day(2)]));
  });

  test('more than two missed days in one week breaks the streak', () async {
    // Mon, Fri → miss Tue,Wed,Thu (3 in one week) exceeds the 2/week budget.
    await streak.recomputeFromHistory({day(0), day(4)}, now: day(4));
    expect(streak.currentStreak, 1); // run is just the latest day (Fri)
    expect(streak.freezeDates, isEmpty);
  });

  test('redeem: combining the peer study day closes the gap', () async {
    // Device A studied Mon+Wed, device B studied Tue; merged set is contiguous.
    await streak.recomputeFromHistory({day(0), day(1), day(2)}, now: day(2));
    expect(streak.currentStreak, 3);
    expect(streak.freezeDates, isEmpty); // no freeze needed — study wins
  });

  test('highest streak is monotonic (never lowered by recompute)', () async {
    await streak.recomputeFromHistory({day(0), day(1), day(2)}, now: day(2));
    expect(streak.highestStreak, 3);
    await streak.recomputeFromHistory({day(2)}, now: day(2)); // shorter run
    expect(streak.currentStreak, 1);
    expect(streak.highestStreak, 3); // preserved
  });

  test('trailing gap the budget cannot bridge lapses the streak to 0', () async {
    // Studied Mon+Tue, but "today" is the next Monday: Wed..Sun (5 missed) blows
    // through the 2 freezes for that week, so the live streak is 0.
    await streak.recomputeFromHistory({day(0), day(1)}, now: day(7));
    expect(streak.currentStreak, 0);
    expect(streak.highestStreak, 2); // the achieved run is still the all-time best
  });

  test('reconcileOnOpen flags a one-time lapse notice then stays quiet', () async {
    streak.pendingLapseNotice = null;
    await streak.reconcileOnOpen({day(0), day(1)}, now: day(7));
    expect(streak.currentStreak, 0);
    expect(streak.pendingLapseNotice, 2); // ended run length

    // Second open on the same lapse must not re-notify.
    streak.pendingLapseNotice = null;
    await streak.reconcileOnOpen({day(0), day(1)}, now: day(7));
    expect(streak.pendingLapseNotice, isNull);
  });

  test('a still-bridgeable trailing gap keeps the streak alive', () async {
    // Studied Mon+Tue, today is Thu: only Wed is missed (1, within budget), so
    // the streak is alive and the user can still practise today.
    await streak.recomputeFromHistory({day(0), day(1)}, now: day(3));
    expect(streak.currentStreak, 2);
  });
}
