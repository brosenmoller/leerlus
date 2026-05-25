import 'package:leerlus/models/answer_configs.dart' show FlashcardConfig, ImageClickConfig, MultipleChoiceConfig, SetConfig, SortingConfig, TypedAnswerConfig;
import 'package:leerlus/models/answer_type.dart' show AnswerType;
import 'package:leerlus/models/occlusion_data.dart' show OcclusionData;

class QuestionData {
  final String id;
  final List<String> questionVariants;
  final String? imagePath;
  /// All image paths for this question. When more than one is present, the
  /// display widget picks one at random each time the question is shown.
  /// For imageClick questions this is always empty (imagePath is used instead).
  final List<String> imagePathVariants;
  final AnswerType answerType;
  final String? explanation;

  /// Optional occlusion overlay (hidden areas + highlight shapes) for this question's image.
  final OcclusionData? occlusionData;

  // Type-specific data
  final MultipleChoiceConfig? multipleChoiceConfig;
  final TypedAnswerConfig? typedAnswerConfig;
  final ImageClickConfig? imageClickConfig;
  final FlashcardConfig? flashcardConfig;
  final SortingConfig? sortingConfig;
  final SetConfig? setConfig;

  QuestionData({
    required this.id,
    required this.questionVariants,
    required this.answerType,
    this.explanation,
    this.imagePath,
    this.imagePathVariants = const [],
    this.occlusionData,
    this.multipleChoiceConfig,
    this.typedAnswerConfig,
    this.imageClickConfig,
    this.flashcardConfig,
    this.sortingConfig,
    this.setConfig,
  });

  factory QuestionData.fromJson(Map<String, dynamic> json) {
    final rawVariants = json['imagePathVariants'] as List?;
    return QuestionData(
      id: json['id'] as String,
      questionVariants: List<String>.from(json['questionVariants'] ?? []),
      imagePath: json['imagePath'] as String?,
      imagePathVariants: rawVariants != null
          ? List<String>.from(rawVariants)
          : (json['imagePath'] as String?) != null
              ? [json['imagePath'] as String]
              : [],
      answerType: AnswerType.values.firstWhere(
            (e) => e.toString().split('.').last == json['answerType'],
      ),
      explanation: json['explanation'] as String?,
      multipleChoiceConfig: json['multipleChoiceConfig'] != null
          ? MultipleChoiceConfig.fromJson(json['multipleChoiceConfig']) : null,
      typedAnswerConfig: json['typedAnswerConfig'] != null
          ? TypedAnswerConfig.fromJson(json['typedAnswerConfig']) : null,
      imageClickConfig: json['imageClickConfig'] != null
          ? ImageClickConfig.fromJson(json['imageClickConfig']) : null,
      flashcardConfig: json['flashcardConfig'] != null
          ? FlashcardConfig.fromJson(json['flashcardConfig']) : null,
      sortingConfig: json['sortingConfig'] != null
          ? SortingConfig.fromJson(json['sortingConfig']) : null,
      setConfig: json['setConfig'] != null
          ? SetConfig.fromJson(json['setConfig']) : null,
    );
  }
}