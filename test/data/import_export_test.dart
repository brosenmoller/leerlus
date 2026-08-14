import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/models/answer_configs.dart';

/// Round-trip tests for `exportToJsonMap` / `importFromJson`.
///
///  - Every answer type must survive the trip. `set` and `sorting` used to be
///    dropped by both switches: the config was never written on export and was
///    replaced by `{}` on import, so the questions came back unanswerable.
///  - `updateExisting` is how a corrected pack is delivered: ids stay the same
///    (so SRS history keyed by question id survives) while the content is
///    overwritten, and the counts distinguish inserts from updates.
void main() {
  late AppDatabase source;
  late AppDatabase target;

  // Two independent in-memory databases (an "export from" and an "import into")
  // are the point here, so the multiple-instance warning is just noise.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  QuestionsCompanion question(
    String id,
    String text,
    String answerType,
    Map<String, dynamic> config,
  ) =>
      QuestionsCompanion(
        id: Value(id),
        questionText: Value(text),
        answerType: Value(answerType),
        answerConfig: Value(jsonEncode(config)),
      );

  Future<String> seedQuiz(AppDatabase db, {String id = 'quiz-1'}) async {
    final folderId = await db.insertFolder(
        const FoldersCompanion(id: Value('folder-1'), title: Value('F')));
    return db.insertQuiz(QuizzesCompanion(
      id: Value(id),
      title: const Value('Quiz'),
      folderId: Value(folderId),
    ));
  }

  group('answer config round trip', () {
    test('set and sorting configs survive export → import', () async {
      final quizId = await seedQuiz(source);
      final setConfig = SetConfig(
        answers: ['heart', 'lung'],
        alternatives: [
          ['cor'],
          [],
        ],
      );
      final sortingConfig = SortingConfig(
        items: ['first', 'second', 'third'],
        showPreFilled: false,
      );
      await source.insertQuestionIntoQuiz(
        question: question('q-set', 'Name them', 'set', setConfig.toJson()),
        quizId: quizId,
      );
      await source.insertQuestionIntoQuiz(
        question:
            question('q-sort', 'Order them', 'sorting', sortingConfig.toJson()),
        quizId: quizId,
      );

      final exported = await source.exportToJsonMap();

      // The configs must actually be in the export — losing them there is
      // unrecoverable no matter what the importer does.
      final exportedQuestions =
          (exported['questions'] as List).cast<Map<String, dynamic>>();
      expect(
        exportedQuestions.firstWhere((q) => q['id'] == 'q-set')['setConfig'],
        isNotNull,
      );
      expect(
        exportedQuestions
            .firstWhere((q) => q['id'] == 'q-sort')['sortingConfig'],
        isNotNull,
      );

      await target.importFromJson(exported);

      final importedSet = SetConfig.fromJson(jsonDecode(
          (await target.getQuestionById('q-set'))!.answerConfig)
          as Map<String, dynamic>);
      expect(importedSet.answers, ['heart', 'lung']);
      expect(importedSet.alternatives.first, ['cor']);

      final importedSorting = SortingConfig.fromJson(jsonDecode(
          (await target.getQuestionById('q-sort'))!.answerConfig)
          as Map<String, dynamic>);
      expect(importedSorting.items, ['first', 'second', 'third']);
      expect(importedSorting.showPreFilled, isFalse);
    });

    test('multiple choice still round trips', () async {
      final quizId = await seedQuiz(source);
      await source.insertQuestionIntoQuiz(
        question: question(
          'q-mc',
          'Pick one',
          'multipleChoice',
          MultipleChoiceConfig(options: ['a', 'b'], correctIndices: [1])
              .toJson(),
        ),
        quizId: quizId,
      );

      await target.importFromJson(await source.exportToJsonMap());

      final config = MultipleChoiceConfig.fromJson(jsonDecode(
          (await target.getQuestionById('q-mc'))!.answerConfig)
          as Map<String, dynamic>);
      expect(config.options, ['a', 'b']);
      expect(config.correctIndices, [1]);
    });
  });

  group('importFromJson update mode', () {
    test('default import stays idempotent and reports nothing new', () async {
      final quizId = await seedQuiz(source);
      await source.insertQuestionIntoQuiz(
        question: question('q-1', 'Original', 'typed',
            TypedAnswerConfig(acceptedAnswers: ['x']).toJson()),
        quizId: quizId,
      );
      final exported = await source.exportToJsonMap();

      final first = await target.importFromJson(exported);
      expect(first.inserted, 3); // folder + quiz + question
      expect(first.updated, 0);

      // Correct the question, then re-import without the update flag.
      await source.updateQuestion(QuestionsCompanion(
        id: const Value('q-1'),
        questionText: const Value('Corrected'),
        answerType: const Value('typed'),
        answerConfig:
            Value(jsonEncode(TypedAnswerConfig(acceptedAnswers: ['y']).toJson())),
      ));
      final second =
          await target.importFromJson(await source.exportToJsonMap());

      expect(second.inserted, 0);
      expect(second.updated, 0);
      expect((await target.getQuestionById('q-1'))!.questionText, 'Original');
    });

    test('updateExisting overwrites in place, keeping the id', () async {
      final quizId = await seedQuiz(source);
      await source.insertQuestionIntoQuiz(
        question: question('q-1', 'Original', 'typed',
            TypedAnswerConfig(acceptedAnswers: ['x']).toJson()),
        quizId: quizId,
      );
      await target.importFromJson(await source.exportToJsonMap());

      await source.updateQuestion(QuestionsCompanion(
        id: const Value('q-1'),
        questionText: const Value('Corrected'),
        answerType: const Value('typed'),
        answerConfig:
            Value(jsonEncode(TypedAnswerConfig(acceptedAnswers: ['y']).toJson())),
        explanation: const Value('Because.'),
      ));
      await source.updateQuiz(QuizzesCompanion(
        id: Value(quizId),
        title: const Value('Renamed quiz'),
        folderId: const Value('folder-1'),
      ));

      final result = await target
          .importFromJson(await source.exportToJsonMap(), updateExisting: true);

      expect(result.inserted, 0);
      expect(result.updated, 3); // folder + quiz + question

      final updated = (await target.getQuestionById('q-1'))!;
      expect(updated.id, 'q-1', reason: 'id is what keeps SRS history attached');
      expect(updated.questionText, 'Corrected');
      expect(updated.explanation, 'Because.');
      expect(
        TypedAnswerConfig.fromJson(
                jsonDecode(updated.answerConfig) as Map<String, dynamic>)
            .acceptedAnswers,
        ['y'],
      );
      expect((await target.getQuizById(quizId))!.title, 'Renamed quiz');
    });

    test('updateExisting clears fields the new version dropped', () async {
      final quizId = await seedQuiz(source);
      await source.insertQuestionIntoQuiz(
        question: QuestionsCompanion(
          id: const Value('q-1'),
          questionText: const Value('Q'),
          answerType: const Value('typed'),
          answerConfig: Value(
              jsonEncode(TypedAnswerConfig(acceptedAnswers: ['x']).toJson())),
          explanation: const Value('Old explanation'),
        ),
        quizId: quizId,
      );
      await target.importFromJson(await source.exportToJsonMap());

      await source.updateQuestion(QuestionsCompanion(
        id: const Value('q-1'),
        questionText: const Value('Q'),
        answerType: const Value('typed'),
        answerConfig: Value(
            jsonEncode(TypedAnswerConfig(acceptedAnswers: ['x']).toJson())),
        explanation: const Value(null),
      ));

      await target.importFromJson(await source.exportToJsonMap(),
          updateExisting: true);

      expect((await target.getQuestionById('q-1'))!.explanation, isNull);
    });

    test('updateExisting links questions added to an existing quiz', () async {
      final quizId = await seedQuiz(source);
      await source.insertQuestionIntoQuiz(
        question: question('q-1', 'First', 'typed',
            TypedAnswerConfig(acceptedAnswers: ['x']).toJson()),
        quizId: quizId,
      );
      await target.importFromJson(await source.exportToJsonMap());

      await source.insertQuestionIntoQuiz(
        question: question('q-2', 'Second', 'typed',
            TypedAnswerConfig(acceptedAnswers: ['y']).toJson()),
        quizId: quizId,
      );

      final result = await target
          .importFromJson(await source.exportToJsonMap(), updateExisting: true);

      expect(result.inserted, 1); // the new question
      final linked = await target.getQuestionsForQuiz(quizId);
      expect(linked.map((q) => q.id), ['q-1', 'q-2'],
          reason: 'a new pack question must not land in the DB unreachable');
    });
  });
}
