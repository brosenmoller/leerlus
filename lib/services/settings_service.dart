import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:leerlus/models/srs_settings.dart';

class SettingsService {
  SettingsService._internal();
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;

  late Box _box;

  /// Notifier for the currently active locale. null = follow system locale.
  final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

  Future<void> init() async {
    try {
      _box = await Hive.openBox('settings');
    } catch (_) {
      await Hive.deleteBoxFromDisk('settings');
      _box = await Hive.openBox('settings');
    }
    final code = _box.get('languageCode') as String?;
    if (code != null) {
      localeNotifier.value = Locale(code);
    }
  }

  // ── Language ──────────────────────────────────────────────────────────────

  /// The stored language code, or null for system default.
  String? get languageCode => _box.get('languageCode') as String?;

  Future<void> setLanguageCode(String? code) async {
    if (code == null) {
      await _box.delete('languageCode');
      localeNotifier.value = null;
    } else {
      await _box.put('languageCode', code);
      localeNotifier.value = Locale(code);
    }
  }

  // ── SRS settings ──────────────────────────────────────────────────────────

  static const _kLapseMult = 'srs_lapse_mult';
  static const _kEaseAgain = 'srs_ease_again';
  static const _kEaseHard = 'srs_ease_hard';
  static const _kEaseGood = 'srs_ease_good';
  static const _kEaseEasy = 'srs_ease_easy';
  static const _kInitialEase = 'srs_initial_ease';
  static const _kMaxDays = 'srs_max_days';
  static const _kEasyMin = 'srs_easy_min_days';

  SrsSettings get srsSettings => SrsSettings(
    lapseMultiplier:
        (_box.get(_kLapseMult) as double?) ?? SrsSettings.defaultLapseMultiplier,
    easeAgain:
        (_box.get(_kEaseAgain) as double?) ?? SrsSettings.defaultEaseAgain,
    easeHard:
        (_box.get(_kEaseHard) as double?) ?? SrsSettings.defaultEaseHard,
    easeGood:
        (_box.get(_kEaseGood) as double?) ?? SrsSettings.defaultEaseGood,
    easeEasy:
        (_box.get(_kEaseEasy) as double?) ?? SrsSettings.defaultEaseEasy,
    initialEase:
        (_box.get(_kInitialEase) as double?) ?? SrsSettings.defaultInitialEase,
    maxIntervalDays:
        (_box.get(_kMaxDays) as int?) ?? SrsSettings.defaultMaxIntervalDays,
    easyMinIntervalDays: (_box.get(_kEasyMin) as int?) ??
        SrsSettings.defaultEasyMinIntervalDays,
  );

  Future<void> setSrsSettings(SrsSettings s) async {
    await _box.put(_kLapseMult, s.lapseMultiplier);
    await _box.put(_kEaseAgain, s.easeAgain);
    await _box.put(_kEaseHard, s.easeHard);
    await _box.put(_kEaseGood, s.easeGood);
    await _box.put(_kEaseEasy, s.easeEasy);
    await _box.put(_kInitialEase, s.initialEase);
    await _box.put(_kMaxDays, s.maxIntervalDays);
    await _box.put(_kEasyMin, s.easyMinIntervalDays);
  }

  // ── Default quiz language ─────────────────────────────────────────────────

  static const _kDefaultQuizLang = 'default_quiz_language_code';

  String? get defaultQuizLanguageCode =>
      _box.get(_kDefaultQuizLang) as String?;

  Future<void> setDefaultQuizLanguageCode(String? code) async {
    if (code == null) {
      await _box.delete(_kDefaultQuizLang);
    } else {
      await _box.put(_kDefaultQuizLang, code);
    }
  }

  // ── Last export directory (desktop save dialog) ───────────────────────────

  static const _kLastExportDir = 'last_export_directory';

  /// The directory last chosen in the desktop "save export" dialog, or null.
  String? get lastExportDirectory => _box.get(_kLastExportDir) as String?;

  Future<void> setLastExportDirectory(String? path) async {
    if (path == null) {
      await _box.delete(_kLastExportDir);
    } else {
      await _box.put(_kLastExportDir, path);
    }
  }

  // ── Animations ───────────────────────────────────────────────────────────

  static const _kAnimationsEnabled = 'animations_enabled';

  bool get animationsEnabled =>
      (_box.get(_kAnimationsEnabled) as bool?) ?? true;

  Future<void> setAnimationsEnabled(bool value) =>
      _box.put(_kAnimationsEnabled, value);

  Future<void> resetSrsSettings() async {
    for (final key in [
      _kLapseMult,
      _kEaseAgain,
      _kEaseHard,
      _kEaseGood,
      _kEaseEasy,
      _kInitialEase,
      _kMaxDays,
      _kEasyMin,
    ]) {
      await _box.delete(key);
    }
  }
}
