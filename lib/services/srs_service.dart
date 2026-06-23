import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/models/user_question_data.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/settings_service.dart';

class SrsService {
  static final SrsService _instance = SrsService._internal();
  factory SrsService() => _instance;
  SrsService._internal();
  bool _initialized = false;

  static const String boxName = 'userQuestions';
  late Box<UserQuestionData> _userQuestionBox;

  final QuestionService _questionService = QuestionService();

  /// Bumped whenever a question's SRS enrollment changes, so widgets that show
  /// aggregate enrollment state (e.g. [FolderTile]) can refresh reactively
  /// rather than only on a fresh build.
  final ValueNotifier<int> enrollmentRevision = ValueNotifier<int>(0);

  /// Initialize Hive box
  Future<void> init() async {
    if (_initialized) { return; }
    try {
      _userQuestionBox = await Hive.openBox<UserQuestionData>(boxName);
    } catch (_) {
      await Hive.deleteBoxFromDisk(boxName);
      _userQuestionBox = await Hive.openBox<UserQuestionData>(boxName);
    }
    _initialized = true;
  }

  Box<UserQuestionData> get _box {
    if (!_initialized) throw Exception('SRSService not initialized');
    return _userQuestionBox;
  }

  /// Get UserQuestionData for a specific question
  UserQuestionData getUserData(QuestionData question) {
    UserQuestionData? userData = _box.get(question.id);
    if (userData == null) {
      final settings = SettingsService().srsSettings;
      userData = UserQuestionData(
        questionId: question.id,
        easeFactor: settings.initialEase,
      );
      // Intentionally NOT persisted. A default placeholder just means "no SRS
      // data yet"; persisting it (with spacedRepetitionEnabled:false and
      // lastReviewed:now) used to pollute the box with disabled entries whose
      // fresh timestamp could win a sync last-write-wins merge and wrongly
      // disable a question that was enrolled on another device. Callers that
      // actually change state (enroll/answer) persist explicitly.
    }
    return userData;
  }

  /// Sets the User Data's spacedRepetitionEnabled for this question to 'enabled'
  Future<void> setQuestionSrs(QuestionData question, bool enabled) async {
    final userData = getUserData(question);
    userData.spacedRepetitionEnabled = enabled;
    await _box.put(question.id, userData);
    enrollmentRevision.value++;
  }

  /// Enroll [questionId] in SRS iff its quiz already has SRS enabled (any other
  /// question in the quiz is enrolled). Call right after inserting a new question.
  /// A fresh card is due immediately (nextReview defaults to now).
  Future<void> enrollIfQuizEnabled(String quizId, String questionId) async {
    final quiz = _questionService.getQuiz(quizId);
    if (quiz == null) return;
    final quizEnabled = quiz.questionIds
        .where((id) => id != questionId)
        .any((id) => _box.get(id)?.spacedRepetitionEnabled ?? false);
    if (!quizEnabled) return;

    final data = _box.get(questionId) ??
        UserQuestionData(
          questionId: questionId,
          easeFactor: SettingsService().srsSettings.initialEase,
        );
    data.spacedRepetitionEnabled = true;
    await _box.put(questionId, data);
  }

  /// Back-fill: ensure every question in an SRS-enabled quiz is itself enrolled.
  /// A quiz counts as SRS-enabled if any of its questions is enrolled. Idempotent
  /// and cheap (in-memory reads; only writes questions that actually change), so it
  /// is safe to run on every startup. Returns the number of questions newly enrolled.
  Future<int> reconcileQuizEnrollment() async {
    int changed = 0;
    for (final quiz in _questionService.getAllQuizzes()) {
      final ids = quiz.questionIds;
      final quizEnabled =
          ids.any((id) => _box.get(id)?.spacedRepetitionEnabled ?? false);
      if (!quizEnabled) continue;
      for (final id in ids) {
        final data = _box.get(id);
        if (data != null && data.spacedRepetitionEnabled) continue;
        final entry = data ??
            UserQuestionData(
              questionId: id,
              easeFactor: SettingsService().srsSettings.initialEase,
            );
        entry.spacedRepetitionEnabled = true;
        await _box.put(id, entry);
        changed++;
      }
    }
    return changed;
  }

  /// Puts the Updated User Data into Hive
  Future<void> updateUserData(UserQuestionData userData) async {
    await _box.put(userData.questionId, userData);
    enrollmentRevision.value++;
  }

  /// Update user data after answering a question
  Future<void> updateAfterAnswer(QuestionData question, SrsQuality quality) async {
    final userData = getUserData(question);
    userData.updateAfterAnswer(quality, SettingsService().srsSettings);
    await _box.put(question.id, userData);
  }

  /// Return all questions due for review from a given list
  List<QuestionData> getDueQuestions(List<QuestionData> allQuestions) {
    return allQuestions
        .where((question) => getUserData(question).isDue)
        .toList();
  }

  /// Return all due questions across all categories/quizzes
  List<QuestionData> getAllDueQuestions() {
    final allQuestions = _questionService.getAllQuestions();
    return getDueQuestions(allQuestions);
  }

  /// Get all questions in a specific quiz
  List<QuestionData> getQuestionsForQuiz({String? quizId, QuizData? quiz}) {
    QuizData? q = quiz ?? (quizId != null ? _questionService.getQuiz(quizId) : null);
    if (q == null) return [];

    return q.questionIds
        .map((id) => _questionService.getQuestion(id))
        .whereType<QuestionData>()
        .toList();
  }

  /// Return all UserQuestionData
  List<UserQuestionData> getAllUserData() {
    return _box.values.toList();
  }

  /// Remove SRS data for a deleted question.
  Future<void> deleteUserData(String questionId) async {
    await _box.delete(questionId);
  }

  /// Reset all user SRS data
  Future<void> resetAll() async {
    await _box.clear();
  }

  /// Upsert SRS data from sync, merging it against any local entry.
  ///
  /// Resolves the two orthogonal concerns separately:
  ///  - **Review progress** (streak / ease / interval / schedule): an entry that
  ///    has actually been reviewed always wins over a never-reviewed one; if both
  ///    (or neither) carry progress, the more recently reviewed wins. This stops a
  ///    freshly-enrolled placeholder (lastReviewed = enrollment time, streak 0,
  ///    interval 0) from clobbering a peer's real review history just because its
  ///    enrollment timestamp happens to be newer.
  ///  - **Enrollment** (spacedRepetitionEnabled): plain last-write-wins by
  ///    lastReviewed, preserving the previous enable/disable sync behaviour.
  Future<void> upsertUserData(UserQuestionData incoming) async {
    final existing = _box.get(incoming.questionId);
    if (existing == null) {
      await _box.put(incoming.questionId, incoming);
      return;
    }
    final merged = _mergeSrs(existing, incoming);
    if (!identical(merged, existing)) {
      await _box.put(incoming.questionId, merged);
    }
  }

  /// Returns the merged entry, or [existing] unchanged when [incoming] adds
  /// nothing. See [upsertUserData] for the resolution rules.
  UserQuestionData _mergeSrs(
      UserQuestionData existing, UserQuestionData incoming) {
    bool hasProgress(UserQuestionData d) => d.streak > 0 || d.intervalSeconds > 0;
    final incomingNewer = incoming.lastReviewed.isAfter(existing.lastReviewed);

    final bool scheduleFromIncoming;
    if (hasProgress(incoming) != hasProgress(existing)) {
      scheduleFromIncoming = hasProgress(incoming); // the reviewed entry wins
    } else {
      scheduleFromIncoming = incomingNewer; // tie/both → last-write-wins
    }
    final bool enabled = incomingNewer
        ? incoming.spacedRepetitionEnabled
        : existing.spacedRepetitionEnabled;

    if (!scheduleFromIncoming && enabled == existing.spacedRepetitionEnabled) {
      return existing; // nothing the incoming entry brings changes our copy
    }

    final schedule = scheduleFromIncoming ? incoming : existing;
    return UserQuestionData(
      questionId: existing.questionId,
      streak: schedule.streak,
      easeFactor: schedule.easeFactor,
      intervalSeconds: schedule.intervalSeconds,
      lastReviewed: schedule.lastReviewed,
      nextReview: schedule.nextReview,
      spacedRepetitionEnabled: enabled,
    );
  }

  /// Replaces all SRS data with [entries] exactly (hard sync overwrite).
  /// Unlike [upsertUserData] this drops any local entries not present in
  /// [entries], so this device mirrors the initiator.
  Future<void> replaceAllFromSync(Iterable<UserQuestionData> entries) async {
    await _box.clear();
    for (final e in entries) {
      await _box.put(e.questionId, e);
    }
  }

  /// Get next due question in a quiz
  QuestionData? getNextDueQuestionInQuiz(String quizId) {
    final quiz = _questionService.getQuiz(quizId);
    if (quiz == null) return null;

    // Get all questions in this quiz
    final quizQuestions = quiz.questionIds
        .map((id) => _questionService.getQuestion(id))
        .whereType<QuestionData>()
        .toList();

    // Filter due questions
    final dueQuestions = getDueQuestions(quizQuestions);

    if (dueQuestions.isEmpty) return null;

    dueQuestions.shuffle();
    return dueQuestions.first;
  }
}
