import 'package:drift/drift.dart';

@DataClassName('Folder')
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get parentFolderId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // Bumped on every local edit/move; used by sync for last-write-wins.
  // clientDefault (not withDefault): drift supplies the value from Dart on
  // every insert, so the column needs no SQL expression default. SQLite's
  // ALTER TABLE ADD COLUMN forbids expression defaults, so this is required to
  // let the v10 migration add the column to existing databases.
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Quiz')
class Quizzes extends Table {
  TextColumn get id => text()();
  // Nullable: quizzes can be at the root (no folder)
  TextColumn get folderId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // Optional BCP-47 language tag for the quiz content (e.g. 'en', 'nl', 'de').
  // Null means the quiz is language-neutral / applicable to all languages.
  TextColumn get languageCode => text().nullable()();
  // Bumped on every local edit/move; used by sync for last-write-wins.
  // clientDefault (not withDefault): drift supplies the value from Dart on
  // every insert, so the column needs no SQL expression default. SQLite's
  // ALTER TABLE ADD COLUMN forbids expression defaults, so this is required to
  // let the v10 migration add the column to existing databases.
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  @override
  Set<Column> get primaryKey => {id};
}

class Questions extends Table {
  TextColumn get id => text()();
  TextColumn get questionText => text()();
  // Store variants as JSON string: '["Variant A", "Variant B"]'
  TextColumn get questionVariants => text().nullable()();
  TextColumn get answerType => text()(); // 'multipleChoice' | 'typed' | 'imageClick' | 'flashcard'
  // Store the full config as a JSON blob — flexible for all answer types
  TextColumn get answerConfig => text()();
  TextColumn get explanation => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  // JSON array of image paths — one is picked at random each time the question
  // is displayed. Null means fall back to the legacy single imagePath.
  TextColumn get imagePathVariants => text().nullable()();
  // JSON blob storing OcclusionData (hidden areas + highlight shapes).
  // Null means no occlusion configured for this question.
  TextColumn get occlusionConfig => text().nullable()();
  // Bumped on every local edit; used by sync for last-write-wins.
  // clientDefault (not withDefault): drift supplies the value from Dart on
  // every insert, so the column needs no SQL expression default. SQLite's
  // ALTER TABLE ADD COLUMN forbids expression defaults, so this is required to
  // let the v10 migration add the column to existing databases.
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  @override
  Set<Column> get primaryKey => {id};
}

// Junction table — a question can belong to multiple quizzes
class QuizQuestions extends Table {
  TextColumn get quizId => text().references(Quizzes, #id)();
  TextColumn get questionId => text().references(Questions, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {quizId, questionId};
}

// Records a content deletion so it can propagate during sync instead of the
// item resurrecting from a peer that still has it. entityType is one of
// 'folder' | 'quiz' | 'question'. A tombstone only wins over a peer's live
// copy when its deletedAt is strictly newer than that copy's updatedAt.
// Favorites are tombstoned separately in Hive (FavoritesService).
class Tombstones extends Table {
  TextColumn get entityId => text()();
  TextColumn get entityType => text()();
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entityId, entityType};
}
