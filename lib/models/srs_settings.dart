class SrsSettings {
  static const double defaultLapseMultiplier = 0.25;
  static const double defaultEaseAgain = -0.15;
  static const double defaultEaseHard = -0.10;
  static const double defaultEaseGood = 0.0;
  static const double defaultEaseEasy = 0.15;
  static const double defaultInitialEase = 2.0;
  static const int defaultMaxIntervalDays = 365;
  static const int defaultEasyMinIntervalDays = 1;

  final double lapseMultiplier;
  final double easeAgain;
  final double easeHard;
  final double easeGood;
  final double easeEasy;
  final double initialEase;
  final int maxIntervalDays;
  final int easyMinIntervalDays;

  const SrsSettings({
    this.lapseMultiplier = defaultLapseMultiplier,
    this.easeAgain = defaultEaseAgain,
    this.easeHard = defaultEaseHard,
    this.easeGood = defaultEaseGood,
    this.easeEasy = defaultEaseEasy,
    this.initialEase = defaultInitialEase,
    this.maxIntervalDays = defaultMaxIntervalDays,
    this.easyMinIntervalDays = defaultEasyMinIntervalDays,
  });

  SrsSettings copyWith({
    double? lapseMultiplier,
    double? easeAgain,
    double? easeHard,
    double? easeGood,
    double? easeEasy,
    double? initialEase,
    int? maxIntervalDays,
    int? easyMinIntervalDays,
  }) {
    return SrsSettings(
      lapseMultiplier: lapseMultiplier ?? this.lapseMultiplier,
      easeAgain: easeAgain ?? this.easeAgain,
      easeHard: easeHard ?? this.easeHard,
      easeGood: easeGood ?? this.easeGood,
      easeEasy: easeEasy ?? this.easeEasy,
      initialEase: initialEase ?? this.initialEase,
      maxIntervalDays: maxIntervalDays ?? this.maxIntervalDays,
      easyMinIntervalDays: easyMinIntervalDays ?? this.easyMinIntervalDays,
    );
  }
}
