import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leerlus/data/database/app_database.dart';

/// Regression tests for the folder/quiz deletion-propagation fixes.
///
/// The building blocks exercised here are what `_applyIncomingTombstones`
/// relies on:
///  - Fix 1: `deleteQuestion(touchQuizzes: false)` must NOT bump the parent
///    quiz's `updatedAt`. During tombstone apply, questions are deleted before
///    their quizzes; if deleting a question touched the quiz, the quiz would
///    look newer than its own incoming tombstone and wrongly survive.
///  - Fix 2: `folderHasContentNewerThan` detects peer content added/changed
///    after a deletion (so the folder deletion is cancelled to preserve it),
///    and `touchFolder` revives the folder so it wins last-write-wins.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  QuestionsCompanion question(String text) => QuestionsCompanion(
        questionText: Value(text),
        answerType: const Value('typed'),
        answerConfig: const Value('{}'),
      );

  group('Fix 1 — deleteQuestion touchQuizzes flag', () {
    test('touchQuizzes:false leaves the parent quiz updatedAt untouched',
        () async {
      final fId = await db.insertFolder(const FoldersCompanion(title: Value('F')));
      final qzId = await db.insertQuiz(
          QuizzesCompanion(title: const Value('Q'), folderId: Value(fId)));
      final qId =
          await db.insertQuestionIntoQuiz(question: question('a'), quizId: qzId);

      final before = (await db.getQuizById(qzId))!.updatedAt;

      // Mirrors the tombstone-apply path.
      await db.deleteQuestion(qId, tombstone: false, touchQuizzes: false);

      expect((await db.getQuizById(qzId))!.updatedAt, before,
          reason: 'apply-path delete must not bump the quiz updatedAt');
      expect(await db.getQuestionById(qId), isNull);
    });

    test('default delete (touchQuizzes:true) still bumps the quiz', () async {
      final qzId =
          await db.insertQuiz(const QuizzesCompanion(title: Value('Q')));
      final qId =
          await db.insertQuestionIntoQuiz(question: question('a'), quizId: qzId);

      final before = (await db.getQuizById(qzId))!.updatedAt;
      // Drift stores DateTime as whole unix seconds, so wait past a second
      // boundary to observe the bump.
      await Future.delayed(const Duration(milliseconds: 1100));
      await db.deleteQuestion(qId); // normal UI delete

      expect((await db.getQuizById(qzId))!.updatedAt.isAfter(before), isTrue,
          reason: 'a membership change must still propagate via updatedAt');
    });
  });

  group('Fix 2 — folderHasContentNewerThan / touchFolder', () {
    final when = DateTime(2026, 6, 1, 12);
    final older = when.subtract(const Duration(hours: 1));
    final newer = when.add(const Duration(minutes: 5));

    Future<String> folder(String title, DateTime updatedAt,
            {String? parent}) =>
        db.insertFolder(FoldersCompanion(
          title: Value(title),
          parentFolderId: Value(parent),
          updatedAt: Value(updatedAt),
        ));

    Future<String> quiz(String title, DateTime updatedAt, {String? folderId}) =>
        db.insertQuiz(QuizzesCompanion(
          title: Value(title),
          folderId: Value(folderId),
          updatedAt: Value(updatedAt),
        ));

    test('true when a directly-contained quiz is newer', () async {
      final f = await folder('F', older);
      await quiz('newQ', newer, folderId: f);
      expect(await db.folderHasContentNewerThan(f, when), isTrue);
    });

    test('true when a directly-contained subfolder is newer', () async {
      final f = await folder('F', older);
      await folder('S', newer, parent: f);
      expect(await db.folderHasContentNewerThan(f, when), isTrue);
    });

    test('true recursively when a quiz inside a subfolder is newer', () async {
      final f = await folder('F', older);
      final s = await folder('S', older, parent: f);
      await quiz('deepNewQ', newer, folderId: s);
      expect(await db.folderHasContentNewerThan(f, when), isTrue);
    });

    test('false when everything in the subtree is older', () async {
      final f = await folder('F', older);
      final s = await folder('S', older, parent: f);
      await quiz('oldQ', older, folderId: f);
      await quiz('deepOldQ', older, folderId: s);
      expect(await db.folderHasContentNewerThan(f, when), isFalse);
    });

    test('touchFolder advances updatedAt so a revived folder wins', () async {
      final f = await folder('F', older);
      await db.touchFolder(f);
      expect((await db.getFolderById(f))!.updatedAt.isAfter(older), isTrue);
    });
  });
}
