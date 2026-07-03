import 'dart:convert';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/folder_data.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/models/answer_configs.dart' show FlashcardConfig, ImageClickConfig, MultipleChoiceConfig, SetConfig, SortingConfig, TypedAnswerConfig;
import 'package:leerlus/models/answer_type.dart';
import 'package:leerlus/models/occlusion_data.dart';

class QuestionService {
  QuestionService._internal();
  static final QuestionService _instance = QuestionService._internal();
  factory QuestionService() => _instance;

  bool _initialized = false;
  late AppDatabase _db;

  final Map<String, QuestionData> _questions = {};
  final Map<String, FolderData> _folders = {};
  final Map<String, QuizData> _quizzes = {};

  Future<void> init(AppDatabase db) async {
    if (_initialized) return;
    _db = db;
    await _load();
  }

  Future<void> refresh() async {
    _initialized = false;
    await _load();
  }

  Future<void> _load() async {
    _questions.clear();
    _folders.clear();
    _quizzes.clear();

    // ── Folders ──────────────────────────────────────────────────
    final allFolderRows = await _db.getAllFolders();
    for (final row in allFolderRows) {
      _folders[row.id] = FolderData(
        id: row.id,
        parentFolderId: row.parentFolderId,
        title: row.title,
        imagePath: row.imagePath,
        subfolderIds: [],
        quizIds: [],
      );
    }
    // Wire up parent → child relationships
    for (final row in allFolderRows) {
      if (row.parentFolderId != null) {
        _folders[row.parentFolderId!]
            ?.subfolderIds.add(row.id);
      }
    }

    // ── Quizzes + Questions ───────────────────────────────────────
    final allQuizRows = await _db.getAllQuizzes();
    for (final quizRow in allQuizRows) {
      final quizId = quizRow.id;
      final questionRows = await _db.getQuestionsForQuiz(quizRow.id);
      final questionIds = <String>[];

      for (final qRow in questionRows) {
        final questionId = qRow.id;

        AnswerType answerType;
        try {
          answerType = AnswerType.values.firstWhere(
            (e) => e.toString().split('.').last == qRow.answerType,
          );
        } catch (_) {
          continue;
        }

        Map<String, dynamic> config;
        try {
          config = jsonDecode(qRow.answerConfig) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        List<String> questionVariants;
        try {
          questionVariants = qRow.questionVariants != null
              ? List<String>.from(jsonDecode(qRow.questionVariants!))
              : [qRow.questionText];
        } catch (_) {
          questionVariants = [qRow.questionText];
        }

        // imagePathVariants: prefer the new column; fall back to legacy imagePath.
        // For imageClick the variants list is intentionally empty — imagePath
        // is used directly by ImageClickWidget for the background image.
        List<String> imagePathVariants;
        if (answerType == AnswerType.imageClick) {
          imagePathVariants = [];
        } else if (qRow.imagePathVariants != null) {
          try {
            imagePathVariants =
                List<String>.from(jsonDecode(qRow.imagePathVariants!));
          } catch (_) {
            imagePathVariants = [];
          }
        } else if (qRow.imagePath != null) {
          imagePathVariants = [qRow.imagePath!];
        } else {
          imagePathVariants = [];
        }

        Map<String, OcclusionData> occlusionDataByImage = {};
        if (qRow.occlusionConfig != null) {
          try {
            final occJson = jsonDecode(qRow.occlusionConfig!) as Map<String, dynamic>;
            if (occJson.containsKey('perImage')) {
              final perImage = occJson['perImage'] as Map<String, dynamic>;
              occlusionDataByImage = {
                for (final e in perImage.entries)
                  e.key: OcclusionData.fromJson(e.value as Map<String, dynamic>)
              };
            } else {
              final legacy = OcclusionData.fromJson(occJson);
              if (!legacy.isEmpty) {
                if (answerType == AnswerType.flashcard) {
                  occlusionDataByImage = {'front': legacy};
                } else if (imagePathVariants.isNotEmpty) {
                  occlusionDataByImage = {imagePathVariants.first: legacy};
                }
              }
            }
          } catch (_) {}
        }

        questionIds.add(questionId);
        _questions[questionId] = QuestionData(
          id: questionId,
          questionVariants: questionVariants,
          imagePath: qRow.imagePath,
          imagePathVariants: imagePathVariants,
          answerType: answerType,
          explanation: qRow.explanation,
          occlusionDataByImage: occlusionDataByImage,
          multipleChoiceConfig: answerType == AnswerType.multipleChoice
              ? MultipleChoiceConfig.fromJson(config) : null,
          typedAnswerConfig: answerType == AnswerType.typed
              ? TypedAnswerConfig.fromJson(config) : null,
          imageClickConfig: answerType == AnswerType.imageClick
              ? ImageClickConfig.fromJson(config) : null,
          flashcardConfig: answerType == AnswerType.flashcard
              ? FlashcardConfig.fromJson(config) : null,
          sortingConfig: answerType == AnswerType.sorting
              ? SortingConfig.fromJson(config) : null,
          setConfig: answerType == AnswerType.set
              ? SetConfig.fromJson(config) : null,
        );
      }

      final folderId = quizRow.folderId;
      _quizzes[quizId] = QuizData(
        id: quizId,
        parentFolderId: folderId,
        title: quizRow.title,
        imagePath: quizRow.imagePath,
        languageCode: quizRow.languageCode,
        questionIds: questionIds,
      );

      // Wire quiz into its folder
      if (folderId != null) {
        _folders[folderId]?.quizIds.add(quizId);
      }
    }

    _initialized = true;
  }

  void _ensureInitialized() {
    if (!_initialized) throw Exception('QuestionService not initialized');
  }

  // ── Folder queries ────────────────────────────────────────────

  List<FolderData> getRootFolders() {
    _ensureInitialized();
    return _folders.values.where((f) => f.parentFolderId == null).toList();
  }

  List<FolderData> getAllFolders() {
    _ensureInitialized();
    return _folders.values.toList();
  }

  List<FolderData> getSubfolders(String folderId) {
    _ensureInitialized();
    return _folders.values
        .where((f) => f.parentFolderId == folderId)
        .toList();
  }

  FolderData? getFolder(String id) => _folders[id];

  // ── Quiz queries ──────────────────────────────────────────────

  /// Quizzes directly inside [folderId]; pass null for root-level quizzes.
  List<QuizData> getQuizzesInFolder(String? folderId) {
    _ensureInitialized();
    return _quizzes.values
        .where((q) => q.parentFolderId == folderId)
        .toList();
  }

  List<QuizData> getAllQuizzes() {
    _ensureInitialized();
    return _quizzes.values.toList();
  }

  QuizData? getQuiz(String id) => _quizzes[id];

  // ── Question queries ──────────────────────────────────────────

  List<QuestionData> getAllQuestions() {
    _ensureInitialized();
    return _questions.values.toList();
  }

  QuestionData? getQuestion(String id) => _questions[id];

  /// The id of the first quiz that contains [questionId], or null if none.
  String? getQuizIdForQuestion(String questionId) {
    _ensureInitialized();
    for (final quiz in _quizzes.values) {
      if (quiz.questionIds.contains(questionId)) return quiz.id;
    }
    return null;
  }

  List<QuestionData> getQuestionsForQuiz(String quizId) {
    _ensureInitialized();
    final quiz = _quizzes[quizId];
    if (quiz == null) return [];
    return quiz.questionIds
        .map((id) => _questions[id])
        .whereType<QuestionData>()
        .toList();
  }
}
