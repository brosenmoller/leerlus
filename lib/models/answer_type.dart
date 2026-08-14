enum AnswerType {
  multipleChoice,
  typed,
  imageClick,
  flashcard,
  sorting,
  set,
}

extension AnswerTypeJson on AnswerType {
  /// Key the answer config is stored under in export/import JSON.
  ///
  /// Deliberately an exhaustive switch over the enum with no default branch:
  /// adding a new [AnswerType] breaks the build here until its key is added.
  /// The previous string-based switches in export/import silently dropped the
  /// types they didn't list, which is how `set` and `sorting` answers were lost
  /// on every round trip.
  String get configJsonKey => switch (this) {
        AnswerType.multipleChoice => 'multipleChoiceConfig',
        AnswerType.typed => 'typedAnswerConfig',
        AnswerType.imageClick => 'imageClickConfig',
        AnswerType.flashcard => 'flashcardConfig',
        AnswerType.sorting => 'sortingConfig',
        AnswerType.set => 'setConfig',
      };
}

/// Resolves the `answerType` string stored in the DB / export JSON, or null if
/// it names no known type (data from a newer app version).
AnswerType? answerTypeFromName(String name) {
  for (final type in AnswerType.values) {
    if (type.name == name) return type;
  }
  return null;
}
