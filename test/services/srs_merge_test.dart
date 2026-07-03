import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:leerlus/models/user_question_data.dart';
import 'package:leerlus/services/srs_service.dart';

/// Tests for [SrsService.upsertUserData] / the enrollment-vs-progress merge it
/// runs during sync. The key regression: disabling SRS (which never advances
/// lastReviewed) must still propagate, because enrollment is now resolved by its
/// own [UserQuestionData.enrollmentChangedAt] timestamp.
void main() {
  late Directory tempDir;
  final srs = SrsService();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('srs_merge_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserQuestionDataAdapter());
    }
    await srs.init();
  });

  setUp(() async {
    await Hive.box<UserQuestionData>(SrsService.boxName).clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  final t0 = DateTime(2026, 6, 1, 12);

  UserQuestionData stored(String id) =>
      Hive.box<UserQuestionData>(SrsService.boxName).get(id)!;

  test('incoming disable with newer enrollmentChangedAt wins over equal '
      'lastReviewed', () async {
    // Local: enrolled, reviewed at t0, enrollment last changed at t0.
    await srs.upsertUserData(UserQuestionData(
      questionId: 'q1',
      streak: 3,
      intervalSeconds: 600,
      spacedRepetitionEnabled: true,
      enrollmentChangedAt: t0,
      lastReviewed: t0,
      nextReview: t0.add(const Duration(minutes: 10)),
    ));

    // Incoming from peer: same review history (equal lastReviewed) but SRS was
    // removed later — only enrollmentChangedAt advanced.
    final changed = await srs.upsertUserData(UserQuestionData(
      questionId: 'q1',
      streak: 3,
      intervalSeconds: 600,
      spacedRepetitionEnabled: false,
      enrollmentChangedAt: t0.add(const Duration(minutes: 5)),
      lastReviewed: t0,
      nextReview: t0.add(const Duration(minutes: 10)),
    ));

    expect(changed, isTrue);
    expect(stored('q1').spacedRepetitionEnabled, isFalse,
        reason: 'a later disable must propagate even with equal lastReviewed');
  });

  test('older incoming enrollmentChangedAt does not override a newer local '
      'toggle', () async {
    await srs.upsertUserData(UserQuestionData(
      questionId: 'q2',
      spacedRepetitionEnabled: true,
      enrollmentChangedAt: t0.add(const Duration(minutes: 5)),
      lastReviewed: t0,
    ));

    await srs.upsertUserData(UserQuestionData(
      questionId: 'q2',
      spacedRepetitionEnabled: false,
      enrollmentChangedAt: t0, // older toggle
      lastReviewed: t0,
    ));

    expect(stored('q2').spacedRepetitionEnabled, isTrue);
  });

  test('legacy entries (no enrollmentChangedAt) fall back to lastReviewed',
      () async {
    await srs.upsertUserData(UserQuestionData(
      questionId: 'q3',
      spacedRepetitionEnabled: true,
      lastReviewed: t0,
    ));

    // Newer lastReviewed, still no enrollmentChangedAt → last-write-wins.
    await srs.upsertUserData(UserQuestionData(
      questionId: 'q3',
      spacedRepetitionEnabled: false,
      lastReviewed: t0.add(const Duration(minutes: 5)),
    ));

    expect(stored('q3').spacedRepetitionEnabled, isFalse);
  });

  test('an entry that carries enrollmentChangedAt beats a legacy one that '
      'does not', () async {
    // Legacy local entry, enrolled, no enrollment timestamp.
    await srs.upsertUserData(UserQuestionData(
      questionId: 'q4',
      spacedRepetitionEnabled: true,
      lastReviewed: t0.add(const Duration(minutes: 10)),
    ));

    // Incoming explicit disable (has a timestamp) even with older lastReviewed.
    await srs.upsertUserData(UserQuestionData(
      questionId: 'q4',
      spacedRepetitionEnabled: false,
      enrollmentChangedAt: t0,
      lastReviewed: t0,
    ));

    expect(stored('q4').spacedRepetitionEnabled, isFalse,
        reason: 'an explicit toggle should beat a legacy write with no marker');
  });
}
