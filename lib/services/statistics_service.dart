import 'dart:math';
import 'package:hive/hive.dart';
import 'package:leerlus/models/user_question_data.dart' show SrsQuality;

class StatisticsService {
  StatisticsService._internal();
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;

  static const String _boxName = 'statistics';

  static const _kAnswered = 'answered';
  static const _kCorrect = 'correct';
  static const _kSrsRevisions = 'srs_revisions';
  static const _kSessions = 'sessions';
  static const _kPerfectSessions = 'perfect_sessions';

  static const _kAnswerTypeCounts = 'stats_answer_type_counts';
  static const _kSrsQuality = 'stats_srs_quality';
  static const _kTotalPerfectSessions = 'stats_total_perfect_sessions';

  late Box _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox(_boxName);
    } catch (_) {
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox(_boxName);
    }
    _initialized = true;
  }

  static String _todayKey() {
    final n = DateTime.now();
    return 'stats_day_${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static String _dateKey(DateTime dt) {
    return 'stats_day_${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  Map<String, int> _readDay(String key) {
    final raw = _box.get(key);
    if (raw == null) return {};
    return Map<String, int>.from((raw as Map).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    ));
  }

  void recordAnswer(String answerType, bool wasCorrect, bool isSrsMode) {
    final key = _todayKey();
    final day = _readDay(key);
    day[_kAnswered] = (day[_kAnswered] ?? 0) + 1;
    day[_kCorrect] = (day[_kCorrect] ?? 0) + (wasCorrect ? 1 : 0);
    if (isSrsMode) day[_kSrsRevisions] = (day[_kSrsRevisions] ?? 0) + 1;
    _box.put(key, day);

    final rawAt = _box.get(_kAnswerTypeCounts);
    final atCounts = rawAt != null
        ? Map<String, dynamic>.from(rawAt as Map)
        : <String, dynamic>{};
    final rawBucket = atCounts[answerType];
    final bucket = rawBucket != null
        ? Map<String, int>.from((rawBucket as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toInt())))
        : <String, int>{};
    bucket['answered'] = (bucket['answered'] ?? 0) + 1;
    bucket['correct'] = (bucket['correct'] ?? 0) + (wasCorrect ? 1 : 0);
    atCounts[answerType] = bucket;
    _box.put(_kAnswerTypeCounts, atCounts);
  }

  Future<void> recordSrsQuality(SrsQuality quality) async {
    final raw = _box.get(_kSrsQuality);
    final map = raw != null
        ? Map<String, int>.from((raw as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toInt())))
        : <String, int>{};
    final name = quality.name;
    map[name] = (map[name] ?? 0) + 1;
    await _box.put(_kSrsQuality, map);
  }

  Future<void> recordSessionComplete(bool isSrsSession) async {
    final key = _todayKey();
    final day = _readDay(key);
    day[_kSessions] = (day[_kSessions] ?? 0) + 1;
    await _box.put(key, day);
  }

  Future<void> recordPerfectSession() async {
    final key = _todayKey();
    final day = _readDay(key);
    day[_kPerfectSessions] = (day[_kPerfectSessions] ?? 0) + 1;
    await _box.put(key, day);

    final total = (_box.get(_kTotalPerfectSessions) as int?) ?? 0;
    await _box.put(_kTotalPerfectSessions, total + 1);
  }

  // ── Computed getters ─────────────────────────────────────────

  Map<String, int>? getTodayData() {
    final day = _readDay(_todayKey());
    return day.isEmpty ? null : day;
  }

  List<String> _allDayKeysSorted() {
    return _box.keys
        .whereType<String>()
        .where((k) => k.startsWith('stats_day_'))
        .toList()
      ..sort();
  }

  int getTotalAnswered() => _allDayKeysSorted().fold(0,
      (s, k) => s + (_readDay(k)[_kAnswered] ?? 0));

  int getTotalCorrect() => _allDayKeysSorted().fold(0,
      (s, k) => s + (_readDay(k)[_kCorrect] ?? 0));

  int getTotalSrsRevisions() => _allDayKeysSorted().fold(0,
      (s, k) => s + (_readDay(k)[_kSrsRevisions] ?? 0));

  int getTotalSessions() => _allDayKeysSorted().fold(0,
      (s, k) => s + (_readDay(k)[_kSessions] ?? 0));

  int getBestDayCount() {
    int best = 0;
    for (final k in _allDayKeysSorted()) {
      final count = _readDay(k)[_kAnswered] ?? 0;
      if (count > best) best = count;
    }
    return best;
  }

  String? getBestDayKey() {
    String? bestKey;
    int best = 0;
    for (final k in _allDayKeysSorted()) {
      final count = _readDay(k)[_kAnswered] ?? 0;
      if (count > best) {
        best = count;
        bestKey = k;
      }
    }
    return bestKey;
  }

  // Returns weekday 1=Mon … 7=Sun with most total answers, or null if no data.
  int? getMostActiveWeekday() {
    final totals = List<int>.filled(8, 0);
    for (final k in _allDayKeysSorted()) {
      final dateStr = k.substring('stats_day_'.length);
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;
      totals[dt.weekday] += _readDay(k)[_kAnswered] ?? 0;
    }
    int best = 0, bestDay = 0;
    for (int i = 1; i <= 7; i++) {
      if (totals[i] > best) {
        best = totals[i];
        bestDay = i;
      }
    }
    return bestDay == 0 ? null : bestDay;
  }

  /// All days with at least one answered question, normalized to date-only
  /// [DateTime]s — used to mark "studied" days on the streak calendar.
  Set<DateTime> getActiveDays() {
    final out = <DateTime>{};
    for (final k in _allDayKeysSorted()) {
      if ((_readDay(k)[_kAnswered] ?? 0) > 0) {
        final dt = DateTime.tryParse(k.substring('stats_day_'.length));
        if (dt != null) out.add(DateTime(dt.year, dt.month, dt.day));
      }
    }
    return out;
  }

  // Always returns exactly 7 entries, oldest first.
  List<Map<String, int>> getLast7DaysData() {
    final result = <Map<String, int>>[];
    final today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final dt = today.subtract(Duration(days: i));
      result.add(_readDay(_dateKey(dt)));
    }
    return result;
  }

  Map<String, Map<String, int>> getAnswerTypeCounts() {
    final raw = _box.get(_kAnswerTypeCounts);
    if (raw == null) return {};
    final outer = Map<String, dynamic>.from(raw as Map);
    return outer.map((type, val) {
      final inner = Map<String, int>.from((val as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toInt())));
      return MapEntry(type, inner);
    });
  }

  Map<String, int> getSrsQuality() {
    final raw = _box.get(_kSrsQuality);
    if (raw == null) return {};
    return Map<String, int>.from(
        (raw as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())));
  }

  int getTotalPerfectSessions() =>
      (_box.get(_kTotalPerfectSessions) as int?) ?? 0;

  // ── Sync ─────────────────────────────────────────────────────

  Map<String, dynamic> exportForSync() {
    final dailyData = <String, dynamic>{};
    for (final key in _box.keys.whereType<String>()) {
      if (key.startsWith('stats_day_')) {
        dailyData[key] = _readDay(key);
      }
    }
    return {
      'dailyData': dailyData,
      'answerTypeCounts': _box.get(_kAnswerTypeCounts),
      'srsQuality': _box.get(_kSrsQuality),
      'totalPerfectSessions': _box.get(_kTotalPerfectSessions),
    };
  }

  Future<void> mergeFromSync(Map<String, dynamic> remote) async {
    // 1. Daily data — union of dates; for same date take max per metric
    final remoteDailyRaw =
        (remote['dailyData'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final entry in remoteDailyRaw.entries) {
      final dayKey = entry.key;
      final remoteDay = Map<String, int>.from(
          (entry.value as Map).map((k, v) =>
              MapEntry(k as String, (v as num).toInt())));
      final localDay = _readDay(dayKey);
      final merged = <String, int>{};
      for (final k in {...localDay.keys, ...remoteDay.keys}) {
        merged[k] = max(localDay[k] ?? 0, remoteDay[k] ?? 0);
      }
      await _box.put(dayKey, merged);
    }

    // 2. Answer-type counts — per-type, per-metric max
    final remoteAt =
        (remote['answerTypeCounts'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawLocalAt = _box.get(_kAnswerTypeCounts);
    final localAt = rawLocalAt != null
        ? Map<String, dynamic>.from(rawLocalAt as Map)
        : <String, dynamic>{};
    for (final type in {...localAt.keys, ...remoteAt.keys}) {
      final rawLb = localAt[type];
      final lb = rawLb != null
          ? Map<String, int>.from((rawLb as Map).map(
              (k, v) => MapEntry(k as String, (v as num).toInt())))
          : <String, int>{};
      final rawRb = remoteAt[type];
      final rb = rawRb != null
          ? Map<String, int>.from((rawRb as Map).map(
              (k, v) => MapEntry(k as String, (v as num).toInt())))
          : <String, int>{};
      localAt[type] = {
        'answered': max(lb['answered'] ?? 0, rb['answered'] ?? 0),
        'correct': max(lb['correct'] ?? 0, rb['correct'] ?? 0),
      };
    }
    await _box.put(_kAnswerTypeCounts, localAt);

    // 3. SRS quality — max per bucket
    final rawRemoteSrs = remote['srsQuality'];
    final remoteSrs = rawRemoteSrs != null
        ? Map<String, int>.from((rawRemoteSrs as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toInt())))
        : <String, int>{};
    final localSrs = getSrsQuality();
    for (final q in ['again', 'hard', 'good', 'easy']) {
      localSrs[q] = max(localSrs[q] ?? 0, remoteSrs[q] ?? 0);
    }
    await _box.put(_kSrsQuality, localSrs);

    // 4. Perfect sessions total — max
    final rp = (remote['totalPerfectSessions'] as num?)?.toInt() ?? 0;
    final lp = (_box.get(_kTotalPerfectSessions) as int?) ?? 0;
    if (rp > lp) await _box.put(_kTotalPerfectSessions, rp);
  }

  /// Replaces local statistics with the remote snapshot exactly (hard sync).
  /// Unlike [mergeFromSync] this discards any local-only data so this device
  /// mirrors the initiator.
  Future<void> replaceFromSync(Map<String, dynamic> remote) async {
    // Clear everything exportForSync would have produced.
    final dayKeys = _box.keys
        .whereType<String>()
        .where((k) => k.startsWith('stats_day_'))
        .toList();
    for (final k in dayKeys) {
      await _box.delete(k);
    }
    await _box.delete(_kAnswerTypeCounts);
    await _box.delete(_kSrsQuality);
    await _box.delete(_kTotalPerfectSessions);

    // Import the remote snapshot verbatim.
    final remoteDailyRaw =
        (remote['dailyData'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final entry in remoteDailyRaw.entries) {
      final day = Map<String, int>.from((entry.value as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt())));
      await _box.put(entry.key, day);
    }
    if (remote['answerTypeCounts'] != null) {
      await _box.put(_kAnswerTypeCounts, remote['answerTypeCounts']);
    }
    if (remote['srsQuality'] != null) {
      await _box.put(_kSrsQuality, remote['srsQuality']);
    }
    if (remote['totalPerfectSessions'] != null) {
      await _box.put(_kTotalPerfectSessions,
          (remote['totalPerfectSessions'] as num).toInt());
    }
  }
}
