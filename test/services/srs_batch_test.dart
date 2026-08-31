import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:leerlus/models/answer_type.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/user_question_data.dart';
import 'package:leerlus/services/srs_service.dart';

/// Tests for [SrsService.takeMostOverdue], the selection behind bite-size quick
/// review sessions. The behaviour that matters: a batch must take the *most
/// overdue* cards, so each one measurably shrinks the backlog rather than
/// sampling randomly and leaving the oldest cards to rot.
void main() {
  late Directory tempDir;
  final srs = SrsService();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('srs_batch_test');
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

  QuestionData question(String id) => QuestionData(
        id: id,
        questionVariants: const ['q'],
        answerType: AnswerType.flashcard,
      );

  /// Enrolls [id] with a [nextReview] of now minus [overdueDays].
  Future<QuestionData> due(String id, int overdueDays) async {
    final q = question(id);
    await srs.updateUserData(UserQuestionData(
      questionId: id,
      spacedRepetitionEnabled: true,
      nextReview: DateTime.now().subtract(Duration(days: overdueDays)),
    ));
    return q;
  }

  test('takes the most overdue first, regardless of input order', () async {
    final questions = [
      await due('a', 1),
      await due('b', 30),
      await due('c', 5),
      await due('d', 12),
    ];

    final batch = srs.takeMostOverdue(questions, 2);

    expect(batch.map((q) => q.id), ['b', 'd']);
  });

  test('a limit at or above the length returns everything', () async {
    final questions = [await due('a', 1), await due('b', 2)];

    expect(srs.takeMostOverdue(questions, 2).length, 2);
    expect(srs.takeMostOverdue(questions, 99).length, 2);
  });

  test('a limit of 0 means unlimited, not empty', () async {
    final questions = [await due('a', 1), await due('b', 2)];

    // 0 is the "quick review off" sentinel; it must never blank a session.
    expect(srs.takeMostOverdue(questions, 0).map((q) => q.id), ['b', 'a']);
    expect(srs.takeMostOverdue(questions, -1).length, 2);
  });

  test('does not mutate the caller list', () async {
    final questions = [await due('a', 1), await due('b', 30)];
    final original = [...questions];

    srs.takeMostOverdue(questions, 1);

    expect(questions, original);
  });

  test('a lapsed card sorts ahead of one due further out', () async {
    // A card answered Again is rescheduled a short way out; once it comes due
    // it must outrank cards with longer intervals in the next batch.
    final questions = [await due('long', 2), await due('lapsed', 9)];

    expect(srs.takeMostOverdue(questions, 1).single.id, 'lapsed');
  });
}
