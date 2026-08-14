import 'dart:math';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:leerlus/models/user_question_data.dart' show SrsQuality;

/// Per-device study statistics.
///
/// Every counter is stored as a grow-only counter (G-Counter): a
/// `{originId: count}` map instead of a bare int. A device only ever increments
/// its *own* origin's entry, reads sum across origins, and [mergeFromSync]
/// takes the max per origin. That makes syncing additive (5 answers here + 7
/// there reads as 12, not 7) while staying idempotent — re-syncing or receiving
/// our own counts back can never inflate a total.
///
/// Counts recorded before per-device counters existed were already max-merged,
/// so their true split between devices is unknowable. They are attributed to the
/// shared [legacyOrigin]; because every device uses the same id for them they
/// keep the old max semantics and are never double counted.
class StatisticsService {
  StatisticsService._internal();
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;

  static const String boxName = 'statistics';

  static const _kAnswered = 'answered';
  static const _kCorrect = 'correct';
  static const _kSrsRevisions = 'srs_revisions';
  static const _kSessions = 'sessions';
  static const _kPerfectSessions = 'perfect_sessions';

  static const _kAnswerTypeCounts = 'stats_answer_type_counts';
  static const _kSrsQuality = 'stats_srs_quality';
  static const _kTotalPerfectSessions = 'stats_total_perfect_sessions';

  /// This device's counter origin. Never exported — a hard sync mirrors a
  /// peer's counts but this device keeps its own identity for future counts.
  static const _kOriginId = 'stats_origin_id';

  /// Origin id carrying pre-CRDT counts (see the class doc).
  static const String legacyOrigin = 'legacy';

  late Box _box;
  bool _initialized = false;
  String? _originId;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox(boxName);
    } catch (_) {
      await Hive.deleteBoxFromDisk(boxName);
      _box = await Hive.openBox(boxName);
    }
    _initialized = true;
    _originId ??= _resolveOriginId();
  }

  /// This device's origin id, generated once on first use.
  String get _originKey => _originId ??= _resolveOriginId();

  String _resolveOriginId() {
    final stored = _box.get(_kOriginId);
    if (stored is String && stored.isNotEmpty) return stored;
    final generated = const Uuid().v4();
    _box.put(_kOriginId, generated);
    return generated;
  }

  /// Makes this instance record under [originId] — used by tests to simulate a
  /// second device against the same box.
  @visibleForTesting
  Future<void> debugUseOrigin(String originId) async {
    _originId = originId;
    await _box.put(_kOriginId, originId);
  }

  static String _todayKey() => _dateKey(DateTime.now());

  static String _dateKey(DateTime dt) {
    return 'stats_day_${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  // ── Counter primitives ───────────────────────────────────────

  /// Normalizes a stored counter. Accepts both shapes: a bare int (data written
  /// before per-device counters, attributed to [legacyOrigin]) and a
  /// `{originId: count}` map. Migration is therefore lazy — reads normalize on
  /// the fly and the next write stores the map form.
  static Map<String, int> _counter(dynamic raw) {
    if (raw == null) return {};
    if (raw is num) return {legacyOrigin: raw.toInt()};
    return Map<String, int>.from(
        (raw as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())));
  }

  static int _total(Map<String, int> counter) =>
      counter.values.fold(0, (a, b) => a + b);

  /// Per-origin max — the G-Counter merge.
  static Map<String, int> _mergeCounters(
      Map<String, int> local, Map<String, int> remote) {
    final out = Map<String, int>.from(local);
    for (final e in remote.entries) {
      out[e.key] = max(out[e.key] ?? 0, e.value);
    }
    return out;
  }

  Map<String, int> _bump(Map<String, int> counter) {
    final out = Map<String, int>.from(counter);
    out[_originKey] = (out[_originKey] ?? 0) + 1;
    return out;
  }

  // ── Stored-shape readers ─────────────────────────────────────

  /// A day as raw counters: metric → {origin: count}.
  Map<String, Map<String, int>> _readDayCounters(String key) {
    final raw = _box.get(key);
    if (raw == null) return {};
    return (raw as Map).map((k, v) => MapEntry(k as String, _counter(v)));
  }

  /// A day with each metric summed across origins — what the UI sees.
  Map<String, int> _readDay(String key) =>
      _readDayCounters(key).map((k, v) => MapEntry(k, _total(v)));

  /// Answer-type counts as raw counters: type → metric → {origin: count}.
  Map<String, Map<String, Map<String, int>>> _readAnswerTypeCounters() {
    final raw = _box.get(_kAnswerTypeCounts);
    if (raw == null) return {};
    return (raw as Map).map((type, bucket) => MapEntry(type as String,
        (bucket as Map).map((m, v) => MapEntry(m as String, _counter(v)))));
  }

  /// SRS quality counts as raw counters: quality → {origin: count}.
  Map<String, Map<String, int>> _readSrsQualityCounters() {
    final raw = _box.get(_kSrsQuality);
    if (raw == null) return {};
    return (raw as Map).map((k, v) => MapEntry(k as String, _counter(v)));
  }

  Map<String, int> _readPerfectSessionCounter() =>
      _counter(_box.get(_kTotalPerfectSessions));

  // ── Recording ────────────────────────────────────────────────

  void recordAnswer(String answerType, bool wasCorrect, bool isSrsMode) {
    final key = _todayKey();
    final day = _readDayCounters(key);
    day[_kAnswered] = _bump(day[_kAnswered] ?? {});
    if (wasCorrect) day[_kCorrect] = _bump(day[_kCorrect] ?? {});
    if (isSrsMode) day[_kSrsRevisions] = _bump(day[_kSrsRevisions] ?? {});
    _box.put(key, day);

    final atCounts = _readAnswerTypeCounters();
    final bucket = atCounts[answerType] ?? {};
    bucket['answered'] = _bump(bucket['answered'] ?? {});
    if (wasCorrect) bucket['correct'] = _bump(bucket['correct'] ?? {});
    atCounts[answerType] = bucket;
    _box.put(_kAnswerTypeCounts, atCounts);
  }

  Future<void> recordSrsQuality(SrsQuality quality) async {
    final counters = _readSrsQualityCounters();
    counters[quality.name] = _bump(counters[quality.name] ?? {});
    await _box.put(_kSrsQuality, counters);
  }

  Future<void> recordSessionComplete(bool isSrsSession) async {
    final key = _todayKey();
    final day = _readDayCounters(key);
    day[_kSessions] = _bump(day[_kSessions] ?? {});
    await _box.put(key, day);
  }

  Future<void> recordPerfectSession() async {
    final key = _todayKey();
    final day = _readDayCounters(key);
    day[_kPerfectSessions] = _bump(day[_kPerfectSessions] ?? {});
    await _box.put(key, day);

    await _box.put(
        _kTotalPerfectSessions, _bump(_readPerfectSessionCounter()));
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
    return _readAnswerTypeCounters().map((type, bucket) =>
        MapEntry(type, bucket.map((m, c) => MapEntry(m, _total(c)))));
  }

  Map<String, int> getSrsQuality() {
    return _readSrsQualityCounters().map((q, c) => MapEntry(q, _total(c)));
  }

  int getTotalPerfectSessions() => _total(_readPerfectSessionCounter());

  // ── Sync ─────────────────────────────────────────────────────

  /// Exports in two shapes on purpose:
  ///
  /// * `*V2` — the per-origin counters this version merges additively.
  /// * the original flat keys — totals, so a peer still running the old
  ///   max-merging version reads them without choking on a nested map.
  Map<String, dynamic> exportForSync() {
    final dailyV2 = <String, dynamic>{};
    final dailyV1 = <String, dynamic>{};
    for (final key in _box.keys.whereType<String>()) {
      if (!key.startsWith('stats_day_')) continue;
      final counters = _readDayCounters(key);
      dailyV2[key] = counters;
      dailyV1[key] = counters.map((m, c) => MapEntry(m, _total(c)));
    }

    final atV2 = _readAnswerTypeCounters();
    final srsV2 = _readSrsQualityCounters();
    final perfectV2 = _readPerfectSessionCounter();

    return {
      // V1 (legacy peers)
      'dailyData': dailyV1,
      'answerTypeCounts': atV2.map((type, bucket) =>
          MapEntry(type, bucket.map((m, c) => MapEntry(m, _total(c))))),
      'srsQuality': srsV2.map((q, c) => MapEntry(q, _total(c))),
      'totalPerfectSessions': _total(perfectV2),
      // V2 (per-origin counters)
      'dailyDataV2': dailyV2,
      'answerTypeCountsV2': atV2,
      'srsQualityV2': srsV2,
      'totalPerfectSessionsV2': perfectV2,
    };
  }

  /// Picks the per-origin payload when the peer sends one, else the flat legacy
  /// payload — [_counter] maps those bare ints onto [legacyOrigin], which
  /// reproduces the old max-merge behaviour without double counting.
  static dynamic _remoteSection(
          Map<String, dynamic> remote, String v1Key, String v2Key) =>
      remote[v2Key] ?? remote[v1Key];

  /// Merges [remote] statistics into the local box. Returns true only when at
  /// least one stored total actually grew, so sync can report statistics as
  /// updated only when there was something to update.
  Future<bool> mergeFromSync(Map<String, dynamic> remote) async {
    bool changed = false;

    // 1. Daily data — union of dates; per metric, per-origin max.
    final remoteDailyRaw =
        (_remoteSection(remote, 'dailyData', 'dailyDataV2') as Map?) ?? {};
    for (final entry in remoteDailyRaw.entries) {
      final dayKey = entry.key as String;
      final remoteDay = (entry.value as Map)
          .map((k, v) => MapEntry(k as String, _counter(v)));
      final localDay = _readDayCounters(dayKey);
      final merged = <String, Map<String, int>>{};
      bool dayChanged = false;
      for (final metric in {...localDay.keys, ...remoteDay.keys}) {
        final local = localDay[metric] ?? {};
        final m = _mergeCounters(local, remoteDay[metric] ?? {});
        merged[metric] = m;
        // A missing metric and a stored 0 are semantically identical, so only a
        // genuine increase counts as a change (avoids false "updated" reports).
        if (_total(m) != _total(local)) dayChanged = true;
      }
      if (dayChanged) {
        await _box.put(dayKey, merged);
        changed = true;
      }
    }

    // 2. Answer-type counts — per type, per metric, per-origin max.
    final remoteAt = (_remoteSection(
            remote, 'answerTypeCounts', 'answerTypeCountsV2') as Map?) ??
        {};
    final localAt = _readAnswerTypeCounters();
    bool atChanged = false;
    for (final typeKey in {...localAt.keys, ...remoteAt.keys}) {
      final type = typeKey as String;
      final lb = localAt[type] ?? {};
      final rawRb = remoteAt[type];
      final rb = rawRb != null
          ? (rawRb as Map).map((k, v) => MapEntry(k as String, _counter(v)))
          : <String, Map<String, int>>{};
      final mergedBucket = <String, Map<String, int>>{};
      for (final metric in {'answered', 'correct', ...lb.keys, ...rb.keys}) {
        final local = lb[metric] ?? {};
        final m = _mergeCounters(local, rb[metric] ?? {});
        mergedBucket[metric] = m;
        if (_total(m) != _total(local)) atChanged = true;
      }
      localAt[type] = mergedBucket;
    }
    if (atChanged) {
      await _box.put(_kAnswerTypeCounts, localAt);
      changed = true;
    }

    // 3. SRS quality — per bucket, per-origin max.
    final rawRemoteSrs =
        _remoteSection(remote, 'srsQuality', 'srsQualityV2') as Map?;
    final remoteSrs = rawRemoteSrs != null
        ? rawRemoteSrs.map((k, v) => MapEntry(k as String, _counter(v)))
        : <String, Map<String, int>>{};
    final localSrs = _readSrsQualityCounters();
    final mergedSrs = Map<String, Map<String, int>>.from(localSrs);
    bool srsChanged = false;
    for (final q in {'again', 'hard', 'good', 'easy', ...remoteSrs.keys}) {
      final local = localSrs[q] ?? {};
      final m = _mergeCounters(local, remoteSrs[q] ?? {});
      mergedSrs[q] = m;
      // Missing bucket == stored 0; only a genuine increase is a real change.
      if (_total(m) != _total(local)) srsChanged = true;
    }
    if (srsChanged) {
      await _box.put(_kSrsQuality, mergedSrs);
      changed = true;
    }

    // 4. Perfect sessions total — per-origin max.
    final localPerfect = _readPerfectSessionCounter();
    final mergedPerfect = _mergeCounters(
        localPerfect,
        _counter(_remoteSection(
            remote, 'totalPerfectSessions', 'totalPerfectSessionsV2')));
    if (_total(mergedPerfect) != _total(localPerfect)) {
      await _box.put(_kTotalPerfectSessions, mergedPerfect);
      changed = true;
    }

    return changed;
  }

  /// Replaces local statistics with the remote snapshot exactly (hard sync).
  /// Unlike [mergeFromSync] this discards any local-only data so this device
  /// mirrors the initiator. This device's own origin id is kept, so counts it
  /// records afterwards still merge additively.
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

    // Import the remote snapshot verbatim, normalized to per-origin counters.
    final remoteDailyRaw =
        (_remoteSection(remote, 'dailyData', 'dailyDataV2') as Map?) ?? {};
    for (final entry in remoteDailyRaw.entries) {
      final day = (entry.value as Map)
          .map((k, v) => MapEntry(k as String, _counter(v)));
      await _box.put(entry.key as String, day);
    }

    final rawAt =
        _remoteSection(remote, 'answerTypeCounts', 'answerTypeCountsV2') as Map?;
    if (rawAt != null) {
      await _box.put(
          _kAnswerTypeCounts,
          rawAt.map((type, bucket) => MapEntry(
              type as String,
              (bucket as Map)
                  .map((m, v) => MapEntry(m as String, _counter(v))))));
    }

    final rawSrs = _remoteSection(remote, 'srsQuality', 'srsQualityV2') as Map?;
    if (rawSrs != null) {
      await _box.put(_kSrsQuality,
          rawSrs.map((k, v) => MapEntry(k as String, _counter(v))));
    }

    final rawPerfect = _remoteSection(
        remote, 'totalPerfectSessions', 'totalPerfectSessionsV2');
    if (rawPerfect != null) {
      await _box.put(_kTotalPerfectSessions, _counter(rawPerfect));
    }
  }
}
