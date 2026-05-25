import 'package:hive/hive.dart';
import 'package:leerlus/models/srs_settings.dart';
part 'user_question_data.g.dart';
enum SrsQuality { again, hard, good, easy }

@HiveType(typeId: 0)
class UserQuestionData extends HiveObject {
  @HiveField(0)
  final String questionId;

  @HiveField(1)
  int streak;

  @HiveField(2)
  double easeFactor;

  @HiveField(3)
  double intervalSeconds;

  @HiveField(4)
  DateTime lastReviewed;

  @HiveField(5)
  DateTime nextReview;

  @HiveField(6)
  bool spacedRepetitionEnabled;

  UserQuestionData({
    required this.questionId,
    this.streak = 0,
    this.easeFactor = 2.0,
    this.intervalSeconds = 0,
    this.spacedRepetitionEnabled = false,
    DateTime? lastReviewed,
    DateTime? nextReview,
  })  : lastReviewed = lastReviewed ?? DateTime.now(),
        nextReview = nextReview ?? DateTime.now();

  UserQuestionData copy() {
    return UserQuestionData(
      questionId: questionId,
      streak: streak,
      easeFactor: easeFactor,
      intervalSeconds: intervalSeconds,
      spacedRepetitionEnabled: spacedRepetitionEnabled,
      lastReviewed: lastReviewed,
      nextReview: nextReview,
    );
  }

  Duration get intervalDuration => Duration(seconds: intervalSeconds.round());

  void _adjustEase(double adjustment) {
    easeFactor = (easeFactor + adjustment).clamp(1.1, 3.0);
  }

  void updateAfterAnswer(SrsQuality quality, [SrsSettings settings = const SrsSettings()]) {
    final now = DateTime.now();
    lastReviewed = now;
    final maxSecs = settings.maxIntervalDays * 24.0 * 3600;

    if (streak == 0) {
      switch (quality) {
        case SrsQuality.again:
          intervalSeconds = const Duration(minutes: 1).inSeconds.toDouble();
          break;
        case SrsQuality.hard:
          intervalSeconds = const Duration(minutes: 5).inSeconds.toDouble();
          break;
        case SrsQuality.good:
          intervalSeconds = const Duration(minutes: 10).inSeconds.toDouble();
          break;
        case SrsQuality.easy:
          intervalSeconds = const Duration(days: 7).inSeconds.toDouble();
          break;
      }
      if (quality != SrsQuality.again) streak++;
      nextReview = now.add(intervalDuration);
      return;
    }

    if (quality == SrsQuality.again) {
      streak = 0;
      intervalSeconds = (intervalSeconds * settings.lapseMultiplier)
          .clamp(const Duration(minutes: 10).inSeconds.toDouble(), maxSecs);
      _adjustEase(settings.easeAgain);
    } else {
      streak++;
      switch (quality) {
        case SrsQuality.hard:
          _adjustEase(settings.easeHard);
          break;
        case SrsQuality.good:
          _adjustEase(settings.easeGood);
          break;
        case SrsQuality.easy:
          _adjustEase(settings.easeEasy);
          break;
        default:
          break;
      }
      intervalSeconds = (intervalSeconds * easeFactor).clamp(0, maxSecs);
    }

    nextReview = now.add(intervalDuration);
  }

  bool get isDue =>
      spacedRepetitionEnabled && nextReview.isBefore(DateTime.now());

  @override
  String toString() {
    return 'UserQuestionData(questionId: $questionId, spacedRepetitionEnabled: $spacedRepetitionEnabled, '
        'streak: $streak, intervalSeconds: $intervalSeconds, nextReview: $nextReview)';
  }
}