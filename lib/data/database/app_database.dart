import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path_dart;
import 'package:uuid/uuid.dart';
import 'package:leerlus/utils/app_storage.dart';
import 'package:leerlus/services/lus_archive_service.dart';
import 'package:leerlus/services/srs_service.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Wraps a background [CancellableLusDecode] with the main-isolate DB import
/// that follows it. [result] completes with the number of new items inserted;
/// [cancel] aborts the (heavy, cancellable) decode before any DB write happens.
class CancellableLusImport {
  final CancellableLusDecode _decode;
  final Future<int> Function(Map<String, dynamic>) _import;

  CancellableLusImport._(this._decode, this._import);

  Future<int> get result async => _import(await _decode.result);

  void cancel() => _decode.cancel();
}

@DriftDatabase(tables: [Folders, Quizzes, Questions, QuizQuestions, Tombstones])
class AppDatabase extends _$AppDatabase {
  /// The single live instance, set once in main.dart via [AppDatabase()].
  static late final AppDatabase instance;

  AppDatabase() : super(_openConnection()) {
    instance = this;
  }

  /// Test-only constructor with an injectable executor (e.g. an in-memory
  /// database). Does not register the static [instance].
  AppDatabase.forTesting(super.e);

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getAppStorageDir();
      final file = File(path_dart.join(dir.path, 'leerlus.db'));
      return NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA foreign_keys = ON');
        },
      );
    });
  }

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 8) {
        // Schema pre-dates UUID primary keys and the current table layout.
        // The old migration chain was deleted, so the only safe path is to
        // drop everything and recreate from scratch (same as a fresh install).
        await customStatement('DROP TABLE IF EXISTS quiz_questions');
        await customStatement('DROP TABLE IF EXISTS questions');
        await customStatement('DROP TABLE IF EXISTS quizzes');
        await customStatement('DROP TABLE IF EXISTS folders');
        await customStatement('DROP TABLE IF EXISTS categories');
        await m.createAll();
      } else if (from < 9) {
        await m.addColumn(questions, questions.occlusionConfig);
      }
      if (from >= 8 && from < 10) {
        // updatedAt for last-write-wins sync. SQLite's ALTER TABLE ADD COLUMN
        // forbids an expression default (strftime), so add the column with a
        // constant default and backfill existing rows from created_at. New rows
        // get their timestamp from the column's clientDefault at insert time.
        // Guarded by a column-existence check so the migration is idempotent
        // (safe to re-run after an earlier interrupted/failed upgrade attempt).
        for (final table in const ['folders', 'quizzes', 'questions']) {
          final cols = await customSelect('PRAGMA table_info($table)').get();
          final hasUpdatedAt =
              cols.any((row) => row.data['name'] == 'updated_at');
          if (!hasUpdatedAt) {
            await customStatement(
                'ALTER TABLE $table ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
            await customStatement('UPDATE $table SET updated_at = created_at');
          }
        }
      }
      if (from >= 8 && from < 11) {
        // Tombstones table for deletion propagation during sync. Guarded by an
        // existence check so it's idempotent and safe upgrading from 8/9/10
        // (the from<8 path already recreated everything via createAll).
        final existing = await customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='tombstones'")
            .get();
        if (existing.isEmpty) {
          await m.createTable(tombstones);
        }
      }
    },
  );

  // ─── Tombstones (deletion propagation) ────────────────────────

  /// Records a deletion, keeping the latest [deletedAt] if one already exists.
  Future<void> recordTombstone(String entityId, String entityType,
      [DateTime? when]) async {
    final ts = when ?? DateTime.now();
    final existing = await (select(tombstones)
          ..where((t) =>
              t.entityId.equals(entityId) & t.entityType.equals(entityType)))
        .getSingleOrNull();
    if (existing != null && !ts.isAfter(existing.deletedAt)) return;
    await into(tombstones).insert(
      TombstonesCompanion.insert(
        entityId: entityId,
        entityType: entityType,
        deletedAt: ts,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<Tombstone>> getAllTombstones() => select(tombstones).get();

  /// Removes a tombstone — used when an entity is resurrected (a newer remote
  /// edit / re-create supersedes a stale deletion).
  Future<void> clearTombstone(String entityId, String entityType) =>
      (delete(tombstones)
            ..where((t) =>
                t.entityId.equals(entityId) & t.entityType.equals(entityType)))
          .go();

  // ─── Export ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> exportToJsonMap() async {
    final allFolders = await getAllFolders();
    final allQuizzes = await getAllQuizzes();

    final foldersJson = allFolders.map((f) => {
      'id': f.id,
      'parentFolderId': f.parentFolderId,
      'title': f.title,
      'imagePath': f.imagePath,
    }).toList();

    final quizzesAndQuestions = await _buildJsonForQuizzes(allQuizzes);

    return {
      'folders': foldersJson,
      'quizzes': quizzesAndQuestions['quizzes'],
      'questions': quizzesAndQuestions['questions'],
    };
  }

  Future<Map<String, dynamic>> exportFolderToJsonMap(String folderId) async {
    final folderIds = await _collectFolderSubtree(folderId);
    final folderList = <Folder>[];
    for (final id in folderIds) {
      final f = await (select(folders)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (f != null) folderList.add(f);
    }
    final folderIdsList = folderIds.toList();
    final quizList = await (select(quizzes)
      ..where((t) => t.folderId.isIn(folderIdsList))).get();

    final foldersJson = folderList.map((f) => {
      'id': f.id,
      'parentFolderId': f.parentFolderId,
      'title': f.title,
      'imagePath': f.imagePath,
    }).toList();

    final quizzesAndQuestions = await _buildJsonForQuizzes(quizList);

    return {
      'folders': foldersJson,
      'quizzes': quizzesAndQuestions['quizzes'],
      'questions': quizzesAndQuestions['questions'],
    };
  }

  Future<Map<String, dynamic>> exportQuizToJsonMap(String quizId) async {
    final quiz = await (select(quizzes)..where((t) => t.id.equals(quizId))).getSingleOrNull();
    if (quiz == null) return {'folders': [], 'quizzes': [], 'questions': []};
    final quizzesAndQuestions = await _buildJsonForQuizzes([quiz]);
    return {
      'folders': <Map<String, dynamic>>[],
      'quizzes': quizzesAndQuestions['quizzes'],
      'questions': quizzesAndQuestions['questions'],
    };
  }

  // ─── .lus (ZIP) export ────────────────────────────────────────

  Future<Uint8List> exportToLus() async =>
      LusArchiveService.packToLus(await exportToJsonMap());

  Future<Uint8List> exportFolderToLus(String folderId) async =>
      LusArchiveService.packToLus(await exportFolderToJsonMap(folderId));

  Future<Uint8List> exportQuizToLus(String quizId) async =>
      LusArchiveService.packToLus(await exportQuizToJsonMap(quizId));

  /// Gathers the export content and starts a cancellable background ZIP encode.
  /// The DB queries and image reads happen here (async, non-blocking); only the
  /// CPU-heavy encoding runs in the spawned isolate.
  Future<CancellableLusEncode> startExportToLus() async =>
      CancellableLusEncode.start(
          await LusArchiveService.gatherEntries(await exportToJsonMap()));

  Future<CancellableLusEncode> startExportFolderToLus(String folderId) async =>
      CancellableLusEncode.start(await LusArchiveService.gatherEntries(
          await exportFolderToJsonMap(folderId)));

  Future<CancellableLusEncode> startExportQuizToLus(String quizId) async =>
      CancellableLusEncode.start(await LusArchiveService.gatherEntries(
          await exportQuizToJsonMap(quizId)));

  Future<int> importFromLus(Uint8List lusBytes) async =>
      importFromJson(await LusArchiveService.unpackFromLus(lusBytes));

  /// Starts a cancellable background decode of [bytes] and returns a handle
  /// whose [CancellableLusImport.result] runs the DB import (on this isolate)
  /// and completes with the number of new items inserted.
  Future<CancellableLusImport> startImportFromLus(Uint8List bytes) async {
    final decode = await CancellableLusDecode.start(bytes);
    return CancellableLusImport._(decode, importFromJson);
  }

  // ─── Internal helpers ─────────────────────────────────────────

  /// Collects the given folder and all its descendants, returning their IDs.
  Future<Set<String>> _collectFolderSubtree(String folderId) async {
    final result = <String>{folderId};
    final children = await (select(folders)
      ..where((t) => t.parentFolderId.equals(folderId))).get();
    for (final child in children) {
      result.addAll(await _collectFolderSubtree(child.id));
    }
    return result;
  }

  /// Builds the quizzes + questions JSON for the given list of quizzes.
  Future<Map<String, List<Map<String, dynamic>>>> _buildJsonForQuizzes(
      List<Quiz> quizList) async {
    final seenQuestionIds = <String>{};
    final quizzesJson = <Map<String, dynamic>>[];
    final questionsJson = <Map<String, dynamic>>[];

    for (final quiz in quizList) {
      final questionList = await getQuestionsForQuiz(quiz.id);
      quizzesJson.add({
        'id': quiz.id,
        'folderId': quiz.folderId,
        'title': quiz.title,
        'imagePath': quiz.imagePath,
        'languageCode': quiz.languageCode,
        'questionIds': questionList.map((q) => q.id).toList(),
      });

      for (final question in questionList) {
        if (seenQuestionIds.contains(question.id)) continue;
        seenQuestionIds.add(question.id);

        final Map<String, dynamic> config;
        try {
          config = jsonDecode(question.answerConfig) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final questionJson = <String, dynamic>{
          'id': question.id,
          'questionVariants': question.questionVariants != null
              ? jsonDecode(question.questionVariants!)
              : [question.questionText],
          'answerType': question.answerType,
          'imagePath': question.imagePath,
          'imagePathVariants': question.imagePathVariants != null
              ? jsonDecode(question.imagePathVariants!)
              : null,
          'explanation': question.explanation,
          if (question.occlusionConfig != null)
            'occlusionConfig': jsonDecode(question.occlusionConfig!),
        };

        switch (question.answerType) {
          case 'multipleChoice':
            questionJson['multipleChoiceConfig'] = config;
          case 'typed':
            questionJson['typedAnswerConfig'] = config;
          case 'imageClick':
            questionJson['imageClickConfig'] = config;
          case 'flashcard':
            questionJson['flashcardConfig'] = config;
        }

        questionsJson.add(questionJson);
      }
    }

    return {'quizzes': quizzesJson, 'questions': questionsJson};
  }

  // ─── Import ───────────────────────────────────────────────────

  /// Imports content from a JSON map.
  /// Returns the number of new items inserted.
  /// Items whose id is already present in the DB are skipped (idempotent).
  Future<int> importFromJson(Map<String, dynamic> data) async {
    int inserted = 0;

    await transaction(() async {
      final questionsRaw = data['questions'] as List;
      final quizzesRaw = data['quizzes'] as List;

      final Map<String, String> questionIdMap = {};
      final Map<String, String> folderIdMap = {};

      // 1 — Questions (no dependencies)
      for (final q in questionsRaw) {
        final importedId = q['id'] as String;

        final existing = await getQuestionById(importedId);
        if (existing != null) {
          questionIdMap[importedId] = existing.id;
          continue;
        }

        final answerType = q['answerType'] as String;
        final String answerConfig = switch (answerType) {
          'multipleChoice' => jsonEncode(q['multipleChoiceConfig']),
          'typed'          => jsonEncode(q['typedAnswerConfig']),
          'imageClick'     => jsonEncode(q['imageClickConfig']),
          'flashcard'      => jsonEncode(q['flashcardConfig']),
          _                => '{}',
        };

        final variants = (q['questionVariants'] as List?)?.cast<String>();
        final questionText = variants?.first ?? '';

        final importedVariants = q['imagePathVariants'] as List?;
        final newId = await insertQuestion(QuestionsCompanion(
          id: Value(importedId),
          questionText: Value(questionText),
          questionVariants: variants != null && variants.length > 1
              ? Value(jsonEncode(variants))
              : const Value.absent(),
          answerType: Value(answerType),
          answerConfig: Value(answerConfig),
          explanation: Value(q['explanation'] as String?),
          imagePath: Value(q['imagePath'] as String?),
          imagePathVariants: importedVariants != null
              ? Value(jsonEncode(importedVariants.cast<String>()))
              : const Value.absent(),
          occlusionConfig: q['occlusionConfig'] != null
              ? Value(jsonEncode(q['occlusionConfig']))
              : const Value.absent(),
        ));
        questionIdMap[importedId] = newId;
        await clearTombstone(importedId, 'question');
        inserted++;
      }

      // 2 — Folders
      if (data.containsKey('folders')) {
        final foldersRaw = data['folders'] as List;
        // First pass: insert all folders without parent
        for (final f in foldersRaw) {
          final importedId = f['id'] as String;

          final existing = await getFolderById(importedId);
          if (existing != null) {
            folderIdMap[importedId] = existing.id;
            continue;
          }

          final newId = await insertFolder(FoldersCompanion(
            id: Value(importedId),
            title: Value(f['title'] as String),
            imagePath: Value(f['imagePath'] as String?),
          ));
          folderIdMap[importedId] = newId;
          await clearTombstone(importedId, 'folder');
          inserted++;
        }
        // Second pass: set parent_folder_id
        for (final f in foldersRaw) {
          final parentIdStr = f['parentFolderId'] as String?;
          if (parentIdStr != null) {
            final newId = folderIdMap[f['id'] as String]!;
            final newParentId = folderIdMap[parentIdStr];
            if (newParentId != null) {
              await (update(folders)..where((t) => t.id.equals(newId)))
                  .write(FoldersCompanion(parentFolderId: Value(newParentId)));
            }
          }
        }
      } else if (data.containsKey('categories')) {
        // Legacy format — import categories as root folders
        final categoriesRaw = data['categories'] as List;
        for (final c in categoriesRaw) {
          final newId = await insertFolder(FoldersCompanion(
            title: Value(c['title'] as String),
            imagePath: Value(c['imagePath'] as String?),
          ));
          folderIdMap[c['id'] as String] = newId;
          inserted++;
        }
      }

      // 3 — Quizzes + junction rows
      for (final quiz in quizzesRaw) {
        final importedId = quiz['id'] as String;

        final existing = await getQuizById(importedId);
        if (existing != null) {
          // Quiz already exists — skip entirely (junction rows already set)
          continue;
        }

        String? targetFolderId;
        if (quiz.containsKey('folderId') && quiz['folderId'] != null) {
          targetFolderId = folderIdMap[quiz['folderId'] as String];
        } else if (data.containsKey('categories')) {
          final categoriesRaw = data['categories'] as List;
          final owner = categoriesRaw
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (c) => (c['quizIds'] as List).contains(quiz['id']),
                orElse: () => <String, dynamic>{},
              );
          final ownerCatId = owner['id'] as String?;
          if (ownerCatId != null) {
            targetFolderId = folderIdMap[ownerCatId];
          }
        }

        final newQuizId = await insertQuiz(QuizzesCompanion(
          id: Value(importedId),
          folderId: Value(targetFolderId),
          title: Value(quiz['title'] as String),
          imagePath: Value(quiz['imagePath'] as String?),
          languageCode: Value(quiz['languageCode'] as String?),
        ));
        await clearTombstone(importedId, 'quiz');
        inserted++;

        // Support both new 'questionIds' and legacy 'questionSyncIds'
        final questionIdList = (quiz['questionIds'] ?? quiz['questionSyncIds']) as List? ?? [];
        int order = 0;
        for (final qStringId in questionIdList) {
          final qId = questionIdMap[qStringId as String];
          if (qId == null) continue;
          await into(quizQuestions).insert(QuizQuestionsCompanion.insert(
            quizId: newQuizId,
            questionId: qId,
            sortOrder: Value(order++),
          ));
        }
      }
    });

    return inserted;
  }

  // ─── Folders ──────────────────────────────────────────────────

  Future<List<Folder>> getAllFolders() => select(folders).get();

  Stream<List<Folder>> watchAllFolders() => select(folders).watch();

  Stream<List<Folder>> watchSubfolders(String? parentId) {
    if (parentId == null) {
      return (select(folders)..where((t) => t.parentFolderId.isNull())).watch();
    }
    return (select(folders)..where((t) => t.parentFolderId.equals(parentId))).watch();
  }

  Future<String> insertFolder(FoldersCompanion entry) async {
    final id = entry.id.present ? entry.id.value : const Uuid().v4();
    await into(folders).insert(entry.copyWith(id: Value(id)));
    return id;
  }

  Future<bool> updateFolder(FoldersCompanion entry) =>
      update(folders).replace(entry);

  Future<void> deleteFolder(String id) =>
      transaction(() => _deleteFolderRecursive(id));

  /// Deletes only the folder row — no recursion. Used by the hard-sync handler
  /// which already deletes quizzes and questions as separate steps.
  /// Pass [tombstone] false from the sync-apply path (it records the peer's
  /// exact deletedAt itself).
  Future<void> deleteFolderRow(String id, {bool tombstone = true}) async {
    await (delete(folders)..where((t) => t.id.equals(id))).go();
    if (tombstone) await recordTombstone(id, 'folder');
  }

  Future<void> _deleteFolderRecursive(String id) async {
    final subs = await (select(folders)
      ..where((t) => t.parentFolderId.equals(id))).get();
    for (final sub in subs) {
      await _deleteFolderRecursive(sub.id);
    }
    final quizzesInFolder = await (select(quizzes)
      ..where((t) => t.folderId.equals(id))).get();
    for (final quiz in quizzesInFolder) {
      await deleteQuiz(quiz.id);
    }
    await (delete(folders)..where((t) => t.id.equals(id))).go();
    await recordTombstone(id, 'folder');
  }

  // ─── Quizzes ──────────────────────────────────────────────────

  Future<List<Quiz>> getAllQuizzes() => select(quizzes).get();

  Stream<List<Quiz>> watchAllQuizzes() => select(quizzes).watch();

  Stream<List<Quiz>> watchQuizzesInFolder(String? folderId) {
    if (folderId == null) {
      return (select(quizzes)..where((t) => t.folderId.isNull())).watch();
    }
    return (select(quizzes)..where((t) => t.folderId.equals(folderId))).watch();
  }

  Future<String> insertQuiz(QuizzesCompanion entry) async {
    final id = entry.id.present ? entry.id.value : const Uuid().v4();
    await into(quizzes).insert(entry.copyWith(id: Value(id)));
    return id;
  }

  Future<bool> updateQuiz(QuizzesCompanion entry) =>
      update(quizzes).replace(entry);

  Future<void> deleteQuiz(String id, {bool tombstone = true}) async {
    // Capture question IDs before junction rows are removed.
    final rows = await (select(quizQuestions)
      ..where((t) => t.quizId.equals(id))).get();
    final questionIds = rows.map((r) => r.questionId).toList();

    await (delete(quizQuestions)..where((t) => t.quizId.equals(id))).go();
    await (delete(quizzes)..where((t) => t.id.equals(id))).go();
    if (tombstone) await recordTombstone(id, 'quiz');

    // Delete questions that are now orphaned (no remaining quiz references).
    for (final qId in questionIds) {
      final remaining = await (select(quizQuestions)
        ..where((t) => t.questionId.equals(qId))).get();
      if (remaining.isEmpty) {
        await (delete(questions)..where((t) => t.id.equals(qId))).go();
        await SrsService().deleteUserData(qId);
        if (tombstone) await recordTombstone(qId, 'question');
      }
    }
  }

  // ─── Questions ────────────────────────────────────────────────

  Future<List<Question>> getAllQuestions() => select(questions).get();

  Stream<List<Question>> watchAllQuestions() => select(questions).watch();

  Future<List<Question>> getQuestionsForQuiz(String quizId) {
    final query = select(questions).join([
      innerJoin(
        quizQuestions,
        quizQuestions.questionId.equalsExp(questions.id),
      ),
    ])
      ..where(quizQuestions.quizId.equals(quizId))
      ..orderBy([OrderingTerm(expression: quizQuestions.sortOrder)]);

    return query.map((row) => row.readTable(questions)).get();
  }

  Stream<List<Question>> watchQuestionsForQuiz(String quizId) {
    final query = select(questions).join([
      innerJoin(
        quizQuestions,
        quizQuestions.questionId.equalsExp(questions.id),
      ),
    ])
      ..where(quizQuestions.quizId.equals(quizId))
      ..orderBy([OrderingTerm(expression: quizQuestions.sortOrder)]);

    return query.map((row) => row.readTable(questions)).watch();
  }

  Future<void> reorderQuestion({
    required String quizId,
    required String questionId,
    required int newIndex,
  }) async {
    await (update(quizQuestions)
      ..where((t) =>
          t.quizId.equals(quizId) & t.questionId.equals(questionId)))
        .write(QuizQuestionsCompanion(sortOrder: Value(newIndex)));
    await _touchQuiz(quizId);
  }

  /// Bumps a quiz's [updatedAt] so membership/order changes are detected by
  /// last-write-wins sync. No-op if the quiz no longer exists.
  Future<void> _touchQuiz(String quizId) =>
      (update(quizzes)..where((t) => t.id.equals(quizId)))
          .write(QuizzesCompanion(updatedAt: Value(DateTime.now())));

  Future<String> insertQuestion(QuestionsCompanion question) async {
    final id = question.id.present ? question.id.value : const Uuid().v4();
    await into(questions).insert(question.copyWith(id: Value(id)));
    return id;
  }

  Future<String> insertQuestionIntoQuiz({
    required QuestionsCompanion question,
    required String quizId,
  }) {
    return transaction(() async {
      final questionId = await insertQuestion(question);
      final maxExpr = quizQuestions.sortOrder.max();
      final maxOrder = await (selectOnly(quizQuestions)
            ..where(quizQuestions.quizId.equals(quizId))
            ..addColumns([maxExpr]))
          .map((row) => row.read(maxExpr) ?? -1)
          .getSingle();
      await into(quizQuestions).insert(
        QuizQuestionsCompanion.insert(
          quizId: quizId,
          questionId: questionId,
          sortOrder: Value(maxOrder + 1),
        ),
      );
      await _touchQuiz(quizId);
      return questionId;
    });
  }

  /// Reassigns a question from [fromQuizId] to [toQuizId] by moving its junction
  /// row. SRS data (keyed by questionId) is untouched. Both quizzes are touched so
  /// the membership change wins last-write-wins during sync.
  Future<void> moveQuestionToQuiz({
    required String questionId,
    required String fromQuizId,
    required String toQuizId,
  }) {
    if (fromQuizId == toQuizId) return Future.value();
    return transaction(() async {
      await (delete(quizQuestions)
            ..where((t) =>
                t.quizId.equals(fromQuizId) & t.questionId.equals(questionId)))
          .go();
      final maxExpr = quizQuestions.sortOrder.max();
      final maxOrder = await (selectOnly(quizQuestions)
            ..where(quizQuestions.quizId.equals(toQuizId))
            ..addColumns([maxExpr]))
          .map((row) => row.read(maxExpr) ?? -1)
          .getSingle();
      await into(quizQuestions).insert(
        QuizQuestionsCompanion.insert(
          quizId: toQuizId,
          questionId: questionId,
          sortOrder: Value(maxOrder + 1),
        ),
        mode: InsertMode.insertOrIgnore, // no-op if already a member of target
      );
      await _touchQuiz(fromQuizId);
      await _touchQuiz(toQuizId);
    });
  }

  Future<bool> updateQuestion(QuestionsCompanion entry) =>
      update(questions).replace(entry);

  Future<void> deleteQuestion(String id,
      {bool tombstone = true, bool touchQuizzes = true}) async {
    // Bump updatedAt on every quiz that referenced this question so the
    // membership change wins last-write-wins during sync. Skipped from the
    // tombstone-apply path (touchQuizzes:false): bumping the parent quiz there
    // would make it look newer than the incoming quiz tombstone and wrongly
    // spare it from deletion.
    if (touchQuizzes) {
      final refs = await (select(quizQuestions)
        ..where((t) => t.questionId.equals(id))).get();
      for (final quizId in refs.map((r) => r.quizId).toSet()) {
        await _touchQuiz(quizId);
      }
    }
    await (delete(quizQuestions)..where((t) => t.questionId.equals(id))).go();
    await (delete(questions)..where((t) => t.id.equals(id))).go();
    if (tombstone) await recordTombstone(id, 'question');
  }

  // ─── Lookup helpers ───────────────────────────────────────────

  Future<Folder?> getFolderById(String id) =>
      (select(folders)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Quiz?> getQuizById(String id) =>
      (select(quizzes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Question?> getQuestionById(String id) =>
      (select(questions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateFolderParentId(String folderId, String parentFolderId) =>
      (update(folders)..where((t) => t.id.equals(folderId)))
          .write(FoldersCompanion(parentFolderId: Value(parentFolderId)));

  Future<void> moveFolderToParent(String folderId, String? newParentId) =>
      (update(folders)..where((t) => t.id.equals(folderId)))
          .write(FoldersCompanion(
            parentFolderId: Value(newParentId),
            updatedAt: Value(DateTime.now()),
          ));

  Future<void> moveQuizToFolder(String quizId, String? newFolderId) =>
      (update(quizzes)..where((t) => t.id.equals(quizId)))
          .write(QuizzesCompanion(
            folderId: Value(newFolderId),
            updatedAt: Value(DateTime.now()),
          ));

  Future<Set<String>> getFolderSubtreeIds(String folderId) =>
      _collectFolderSubtree(folderId);

  /// Bumps a folder's [updatedAt] so a revived folder wins last-write-wins.
  Future<void> touchFolder(String id) =>
      (update(folders)..where((t) => t.id.equals(id)))
          .write(FoldersCompanion(updatedAt: Value(DateTime.now())));

  /// True if the folder's live subtree contains any subfolder or quiz whose
  /// updatedAt is strictly newer than [when] — i.e. content a peer added or
  /// changed after the deletion recorded at [when]. Used to cancel an incoming
  /// folder-deletion tombstone so newly added content is preserved.
  Future<bool> folderHasContentNewerThan(String id, DateTime when) async {
    final subtree = await getFolderSubtreeIds(id); // includes id itself
    final newerSub = await (select(folders)
          ..where((t) =>
              t.parentFolderId.isIn(subtree) &
              t.updatedAt.isBiggerThanValue(when)))
        .get();
    if (newerSub.isNotEmpty) return true;
    final newerQuiz = await (select(quizzes)
          ..where((t) =>
              t.folderId.isIn(subtree) & t.updatedAt.isBiggerThanValue(when)))
        .get();
    return newerQuiz.isNotEmpty;
  }

  /// Deletes every row from every content table. Used by the dev wipe tool.
  /// Also clears tombstones so a wipe is a true clean slate (a leftover
  /// tombstone could otherwise delete re-pulled content on a peer at next sync).
  Future<void> wipeAllContent() => transaction(() async {
        await delete(quizQuestions).go();
        await delete(questions).go();
        await delete(quizzes).go();
        await delete(folders).go();
        await delete(tombstones).go();
      });

  Future<void> insertJunctionRowSafe(String quizId, String questionId, int sortOrder) =>
      into(quizQuestions).insert(
        QuizQuestionsCompanion.insert(
          quizId: quizId,
          questionId: questionId,
          sortOrder: Value(sortOrder),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Replaces a quiz's entire question membership with [orderedQuestionIds]
  /// (in order). Used by sync when the incoming quiz wins last-write-wins, so
  /// additions, reorders, and removals all propagate. Does not touch the
  /// question rows themselves — only the junction table.
  Future<void> replaceQuizJunctions(
      String quizId, List<String> orderedQuestionIds) async {
    await (delete(quizQuestions)..where((t) => t.quizId.equals(quizId))).go();
    int order = 0;
    for (final qId in orderedQuestionIds) {
      await into(quizQuestions).insert(
        QuizQuestionsCompanion.insert(
          quizId: quizId,
          questionId: qId,
          sortOrder: Value(order++),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  // ─── Image reference helpers ──────────────────────────────────

  static bool isUserImagePath(String? path) =>
      path != null && !path.startsWith('assets/');

  Set<String> _extractUserImagePathsFromQuestion(Question q) {
    final paths = <String>{};
    if (isUserImagePath(q.imagePath)) paths.add(q.imagePath!);
    if (q.imagePathVariants != null) {
      try {
        final variants = jsonDecode(q.imagePathVariants!) as List;
        for (final v in variants) {
          if (v is String && isUserImagePath(v)) paths.add(v);
        }
      } catch (_) {}
    }
    if (q.answerType == 'flashcard') {
      try {
        final config = jsonDecode(q.answerConfig) as Map<String, dynamic>;
        final front = config['frontImagePath'] as String?;
        final back = config['backImagePath'] as String?;
        if (isUserImagePath(front)) paths.add(front!);
        if (isUserImagePath(back)) paths.add(back!);
      } catch (_) {}
    }
    return paths;
  }

  /// Returns all user image paths referenced by the given quiz IDs
  /// (cover images + question images).
  Future<Set<String>> getImagePathsForQuizzes(Set<String> quizIds) async {
    if (quizIds.isEmpty) return {};
    final paths = <String>{};
    for (final quizId in quizIds) {
      final quiz = await getQuizById(quizId);
      if (quiz != null && isUserImagePath(quiz.imagePath)) paths.add(quiz.imagePath!);
      final qs = await getQuestionsForQuiz(quizId);
      for (final q in qs) {
        paths.addAll(_extractUserImagePathsFromQuestion(q));
      }
    }
    return paths;
  }

  /// Returns all user image paths referenced by the given folder IDs (cover images only).
  Future<Set<String>> getImagePathsForFolders(Set<String> folderIds) async {
    if (folderIds.isEmpty) return {};
    final paths = <String>{};
    for (final folderId in folderIds) {
      final folder = await getFolderById(folderId);
      if (folder != null && isUserImagePath(folder.imagePath)) paths.add(folder.imagePath!);
    }
    return paths;
  }

  /// Returns all quiz IDs contained in the given folder (recursive).
  Future<Set<String>> getFolderQuizIds(String folderId) async {
    final folderIds = await _collectFolderSubtree(folderId);
    final result = <String>{};
    for (final id in folderIds) {
      final folderQuizzes = await (select(quizzes)
        ..where((t) => t.folderId.equals(id))).get();
      for (final quiz in folderQuizzes) {
        result.add(quiz.id);
      }
    }
    return result;
  }

  /// Returns all user image paths currently referenced in the DB,
  /// optionally excluding specific quiz and folder IDs.
  Future<Set<String>> getAllReferencedUserImagePaths({
    Set<String> excludeQuizIds = const {},
    Set<String> excludeFolderIds = const {},
  }) async {
    final paths = <String>{};

    final allFolders = await getAllFolders();
    for (final f in allFolders) {
      if (excludeFolderIds.contains(f.id)) continue;
      if (isUserImagePath(f.imagePath)) paths.add(f.imagePath!);
    }

    final allQuizzes = await getAllQuizzes();
    for (final q in allQuizzes) {
      if (excludeQuizIds.contains(q.id)) continue;
      if (isUserImagePath(q.imagePath)) paths.add(q.imagePath!);
    }

    final allQuestions = await getAllQuestions();
    for (final q in allQuestions) {
      if (excludeQuizIds.isNotEmpty) {
        final junctions = await (select(quizQuestions)
          ..where((t) => t.questionId.equals(q.id))).get();
        if (junctions.isNotEmpty &&
            junctions.every((r) => excludeQuizIds.contains(r.quizId))) {
          continue;
        }
      }
      paths.addAll(_extractUserImagePathsFromQuestion(q));
    }

    return paths;
  }

  /// Returns a map from user image path to list of referencing names
  /// (quiz/folder titles) for the image library screen.
  Future<Map<String, List<String>>> getImageUsageMap() async {
    final usageMap = <String, Set<String>>{};

    void record(String? path, String label) {
      if (path == null || path.isEmpty) return;
      // In debug mode, user images are stored with 'assets/images/' relative
      // paths (not absolute). Include them so the image library can map usage.
      if (!isUserImagePath(path) && !path.startsWith('assets/images/')) return;
      usageMap.putIfAbsent(path, () => {}).add(label);
    }

    final allFolders = await getAllFolders();
    for (final f in allFolders) {
      record(f.imagePath, f.title);
    }

    final allQuizzes = await getAllQuizzes();
    for (final quiz in allQuizzes) {
      record(quiz.imagePath, quiz.title);
      final qs = await getQuestionsForQuiz(quiz.id);
      for (final q in qs) {
        for (final path in _extractUserImagePathsFromQuestion(q)) {
          usageMap.putIfAbsent(path, () => {}).add(quiz.title);
        }
      }
    }

    return usageMap.map((k, v) => MapEntry(k, v.toList()..sort()));
  }
}
