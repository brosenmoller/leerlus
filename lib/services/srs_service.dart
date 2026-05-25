import 'dart:async';
import 'package:hive/hive.dart';
import 'package:med_brew/models/question_data.dart';
import 'package:med_brew/models/quiz_data.dart';
import 'package:med_brew/models/user_question_data.dart';
import 'package:med_brew/services/question_service.dart';
import 'package:med_brew/services/settings_service.dart';

class SrsService {
  static final SrsService _instance = SrsService._internal();
  factory SrsService() => _instance;
  SrsService._internal();
  bool _initialized = false;

  static const String boxName = 'userQuestions';
  late Box<UserQuestionData> _userQuestionBox;

  final QuestionService _questionService = QuestionService();

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
      unawaited(_box.put(question.id, userData));
    }
    return userData;
  }

  /// Sets the User Data's spacedRepetitionEnabled for this question to 'enabled'
  Future<void> setQuestionSrs(QuestionData question, bool enabled) async {
    final userData = getUserData(question);
    userData.spacedRepetitionEnabled = enabled;
    await _box.put(question.id, userData);
  }

  /// Puts the Updated User Data into Hive
  Future<void> updateUserData(UserQuestionData userData) async {
    await _box.put(userData.questionId, userData);
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

  /// Upsert SRS data from sync — keeps the entry with the more recent lastReviewed.
  Future<void> upsertUserData(UserQuestionData incoming) async {
    final existing = _box.get(incoming.questionId);
    if (existing == null || incoming.lastReviewed.isAfter(existing.lastReviewed)) {
      await _box.put(incoming.questionId, incoming);
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
