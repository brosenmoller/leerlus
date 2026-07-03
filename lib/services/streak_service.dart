import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:leerlus/services/notification_service.dart';
import 'package:leerlus/services/statistics_service.dart';

// ── Value types ───────────────────────────────────────────────────────────────

enum StreakEvent {
  /// Streak system is disabled in settings.
  disabled,

  /// Quiz was already counted today — no change.
  sameDay,

  /// Streak extended by one day (consecutive or first ever).
  continued,

  /// One or more freeze(s) consumed to bridge missed day(s); streak intact.
  freezeUsed,

  /// Ran out of freezes — streak broke and restarted at 1.
  reset,
}

class StreakState {
  final int streakCount;
  final int highestStreak;
  final int freezesRemaining;
  final bool streakEnabled;
  final bool completedToday;
  final bool usedFreezeYesterday;

  const StreakState({
    required this.streakCount,
    required this.highestStreak,
    required this.freezesRemaining,
    required this.streakEnabled,
    required this.completedToday,
    this.usedFreezeYesterday = false,
  });
}

/// Result of deriving the streak from a set of studied days (pure computation,
/// no persistence). See [StreakService._calc].
class _StreakCalc {
  /// Live streak as of today — 0 when the trailing gap to today can no longer
  /// be bridged by the weekly freeze budget ([lapsed]).
  final int current;

  /// Length of the achieved run ending at [last] (independent of [lapsed]);
  /// used for the all-time highest and the "streak ended" notice.
  final int run;

  /// Most recent studied day, or null when there is no history.
  final DateTime? last;

  /// Freeze days that bridged gaps *inside* the run, as 'YYYY-MM-DD' strings.
  final List<String> bridged;

  /// True when a missed day between [last] and today exhausts the freeze budget,
  /// so the streak has effectively ended.
  final bool lapsed;

  /// Freezes charged to the current (Mon–Sun) week by in-run bridges.
  final int freezesUsedThisWeek;

  const _StreakCalc({
    required this.current,
    required this.run,
    required this.last,
    required this.bridged,
    required this.lapsed,
    required this.freezesUsedThisWeek,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class StreakService {
  StreakService._internal();
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;

  late Box _box;
  bool _initialized = false;

  // Hive keys (all stored in the 'streak' box)
  static const _kStreakCount = 'streak_count';
  static const _kHighestStreak = 'streak_highest';
  static const _kLastActivity = 'streak_last_activity';
  static const _kFreezesUsed = 'streak_freezes_used';
  static const _kWeekAnchor = 'streak_week_anchor';
  static const _kStreakEnabled = 'streak_enabled';
  static const _kFreezeDates = 'streak_freeze_dates';
  static const _kNotifsEnabled = 'streak_notifs_enabled';
  static const _kNotifsHour = 'streak_notifs_hour';
  static const _kNotifsMinute = 'streak_notifs_minute';
  static const _kNotifsSound = 'streak_notifs_sound';
  static const _kNotifsVibration = 'streak_notifs_vibration';
  static const _kLapseNotified = 'streak_lapse_notified';

  /// Set by [reconcileOnOpen] when the streak has just lapsed since it was last
  /// surfaced; holds the ended run length for a one-time UI notice. The UI reads
  /// it once on startup and clears it.
  int? pendingLapseNotice;

  static const _notifTitle = 'Leerlus';
  static const _notifBody = "Don't forget to study — keep your streak alive!";

  static const maxFreezesPerWeek = 2;

  /// Reactive state — safe to use in ValueListenableBuilder.
  final ValueNotifier<StreakState> streakNotifier = ValueNotifier(
    const StreakState(streakCount: 0, highestStreak: 0, freezesRemaining: 2, streakEnabled: true, completedToday: false),
  );

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get streakEnabled => (_box.get(_kStreakEnabled) as bool?) ?? true;
  int get currentStreak => (_box.get(_kStreakCount) as int?) ?? 0;
  int get highestStreak => (_box.get(_kHighestStreak) as int?) ?? currentStreak;
  String? get lastActivityDate => _box.get(_kLastActivity) as String?;
  String? get weekAnchor => _box.get(_kWeekAnchor) as String?;
  int get freezesUsedThisWeek => (_box.get(_kFreezesUsed) as int?) ?? 0;
  int get freezesRemainingThisWeek =>
      (maxFreezesPerWeek - freezesUsedThisWeek).clamp(0, maxFreezesPerWeek);
  bool get notifsEnabled => (_box.get(_kNotifsEnabled) as bool?) ?? false;
  int get notifsHour => (_box.get(_kNotifsHour) as int?) ?? 20;
  int get notifsMinute => (_box.get(_kNotifsMinute) as int?) ?? 0;
  bool get notifsSound => (_box.get(_kNotifsSound) as bool?) ?? false;
  bool get notifsVibration => (_box.get(_kNotifsVibration) as bool?) ?? false;

  /// All days a freeze bridged a missed day, as 'YYYY-MM-DD' strings.
  List<String> get freezeDates =>
      (_box.get(_kFreezeDates) as List?)?.cast<String>() ?? const [];

  /// Freeze days normalized to date-only [DateTime]s — for calendar display.
  Set<DateTime> freezeDaySet() => freezeDates
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet();

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox('streak');
    } catch (_) {
      await Hive.deleteBoxFromDisk('streak');
      _box = await Hive.openBox('streak');
    }
    _initialized = true;
    _refreshNotifier();
  }

  // ── Core logic ─────────────────────────────────────────────────────────────

  /// Call whenever the user completes a quiz or SRS session. Derives the whole
  /// streak from the real practice-day history ([StatisticsService.getActiveDays])
  /// — including today — so partial-session days count and freezes are charged
  /// to the week the missed day actually falls in. Returns what happened for the
  /// completion-screen message.
  Future<StreakEvent> recordActivity() async {
    if (!streakEnabled) return StreakEvent.disabled;

    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    final todayStr = _dateStr(todayD);
    final prevLast = lastActivityDate;

    // Recompute from history with today included (the user just practised).
    final studied = <DateTime>{...StatisticsService().getActiveDays(), todayD};
    await recomputeFromHistory(studied);

    if (prevLast == todayStr) return StreakEvent.sameDay;

    StreakEvent event;
    if (prevLast == null) {
      event = StreakEvent.continued; // first activity ever (or after a reset)
    } else {
      final lastDt = DateTime.parse(prevLast);
      final gap = todayD
          .difference(DateTime(lastDt.year, lastDt.month, lastDt.day))
          .inDays -
          1;
      if (gap <= 0) {
        event = StreakEvent.continued; // consecutive day
      } else {
        // Gap existed — freezeUsed if every missed day was bridged, else reset.
        final frozen = freezeDaySet();
        var allBridged = true;
        for (var i = 1; i <= gap; i++) {
          final m = lastDt.add(Duration(days: i));
          if (!frozen.contains(DateTime(m.year, m.month, m.day))) {
            allBridged = false;
            break;
          }
        }
        event = allBridged ? StreakEvent.freezeUsed : StreakEvent.reset;
      }
    }

    // Push the daily reminder to tomorrow so it doesn't fire on a day already studied.
    if (notifsEnabled && streakEnabled) await _rescheduleForTomorrow();
    return event;
  }

  /// Reconciles the streak on app open from the real practice history. Self-heals
  /// the stored count and, when the streak has just lapsed (a trailing gap the
  /// freeze budget can no longer bridge), sets [pendingLapseNotice] once so the
  /// UI can tell the user their streak ended — instead of it silently vanishing
  /// on their next quiz.
  Future<void> reconcileOnOpen(Set<DateTime> studiedDays, {DateTime? now}) async {
    if (!streakEnabled) return;
    final today = now ?? DateTime.now();
    final calc = _calc(studiedDays, today);
    await _persist(calc, now: today);
    if (calc.lapsed && calc.run > 1 && calc.last != null) {
      final marker = _dateStr(calc.last!);
      if ((_box.get(_kLapseNotified) as String?) != marker) {
        pendingLapseNotice = calc.run;
        await _box.put(_kLapseNotified, marker);
      }
    }
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<void> setStreakEnabled(bool v) async {
    await _box.put(_kStreakEnabled, v);
    _refreshNotifier();
    if (!v) {
      await NotificationService().cancelReminder();
    } else if (notifsEnabled) {
      await _reschedule();
    }
  }

  Future<void> setNotifsEnabled(bool v) async {
    await _box.put(_kNotifsEnabled, v);
    if (v && streakEnabled) {
      await _reschedule();
    } else {
      await NotificationService().cancelReminder();
    }
  }

  Future<void> setNotifTime(int hour, int minute) async {
    await _box.put(_kNotifsHour, hour);
    await _box.put(_kNotifsMinute, minute);
    if (notifsEnabled && streakEnabled) await _reschedule();
  }

  Future<void> setNotifsSound(bool v) async {
    await _box.put(_kNotifsSound, v);
    if (notifsEnabled && streakEnabled) await _reschedule();
  }

  Future<void> setNotifsVibration(bool v) async {
    await _box.put(_kNotifsVibration, v);
    if (notifsEnabled && streakEnabled) await _reschedule();
  }

  /// Raises the stored all-time highest streak to [remoteHighest] if larger
  /// (normal sync — highest is monotonic across both devices).
  Future<void> mergeHighestStreak(int remoteHighest) async {
    if (remoteHighest > highestStreak) {
      await _box.put(_kHighestStreak, remoteHighest);
      _refreshNotifier();
    }
  }

  /// Forces the stored all-time highest streak to [value], which may *lower* it
  /// (hard sync — this device mirrors the initiator).
  Future<void> setHighestStreak(int value) async {
    await _box.put(_kHighestStreak, value);
    _refreshNotifier();
  }

  /// Rebuilds the entire streak state purely from the merged set of studied
  /// days, applying the weekly freeze budget ([maxFreezesPerWeek] per Mon–Sun
  /// week). Called after a sync unions in the other device's practice history
  /// so both devices resolve to the *same* streak regardless of sync order:
  ///
  ///  * a day missed on one device but studied on the other closes the gap
  ///    (the loss is redeemed — a real study day beats a freeze), and
  ///  * a gap that neither device covered, and that the weekly freeze budget
  ///    cannot bridge, breaks the streak on both devices.
  ///
  /// The run is anchored at the most recent studied day (not "today"), matching
  /// the daily-path semantics where a streak persists until the next practice.
  Future<void> recomputeFromHistory(Set<DateTime> studiedDays, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return _persist(_calc(studiedDays, today), now: today);
  }

  /// Pure derivation of the streak from [studiedDays] as of [today]. See the
  /// field docs on [_StreakCalc]. No persistence — call [_persist] to store.
  _StreakCalc _calc(Set<DateTime> studiedDays, DateTime today) {
    final todayD = DateTime(today.year, today.month, today.day);

    // Normalize to date-only, dedupe, sort most-recent first.
    final days = studiedDays
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (days.isEmpty) {
      return const _StreakCalc(
        current: 0,
        run: 0,
        last: null,
        bridged: [],
        lapsed: false,
        freezesUsedThisWeek: 0,
      );
    }

    final latest = days.first;
    var run = 1;
    final bridged = <String>[];
    final weekUsed = <String, int>{}; // Monday 'YYYY-MM-DD' -> freezes used.

    var prev = latest; // more-recent day of the pair being compared
    for (var i = 1; i < days.length; i++) {
      final cur = days[i]; // earlier studied day
      final gap = prev.difference(cur).inDays - 1; // missed days strictly between

      if (gap == 0) {
        // Consecutive studied days — no freeze needed.
        run++;
        prev = cur;
        continue;
      }

      // Try to bridge every missed day within its week's freeze budget.
      final tentative = <String>[];
      final tentativeWeek = <String, int>{};
      var bridgeable = true;
      for (var d = 1; d <= gap; d++) {
        final missed = cur.add(Duration(days: d));
        final wk = _dateStr(_monday(missed));
        final used = (weekUsed[wk] ?? 0) + (tentativeWeek[wk] ?? 0);
        if (used < maxFreezesPerWeek) {
          tentativeWeek[wk] = (tentativeWeek[wk] ?? 0) + 1;
          tentative.add(_dateStr(missed));
        } else {
          bridgeable = false;
          break;
        }
      }
      if (!bridgeable) break; // Gap can't be covered — run ends at [prev].

      tentativeWeek.forEach((k, v) => weekUsed[k] = (weekUsed[k] ?? 0) + v);
      bridged.addAll(tentative);
      run++;
      prev = cur;
    }

    // Trailing gap: days strictly between the last studied day and today (today
    // itself is not "missed" — it can still be practised). If the budget can't
    // cover them the streak has lapsed and the live count is 0.
    var lapsed = false;
    final trailingMissed = todayD.difference(latest).inDays - 1;
    for (var d = 1; d <= trailingMissed; d++) {
      final missed = latest.add(Duration(days: d));
      final wk = _dateStr(_monday(missed));
      if ((weekUsed[wk] ?? 0) < maxFreezesPerWeek) {
        weekUsed[wk] = (weekUsed[wk] ?? 0) + 1;
      } else {
        lapsed = true;
        break;
      }
    }

    final thisMonday = _dateStr(_monday(todayD));
    final freezesThisWeek = bridged
        .where((d) => _dateStr(_monday(DateTime.parse(d))) == thisMonday)
        .length;

    bridged.sort();
    return _StreakCalc(
      current: lapsed ? 0 : run,
      run: run,
      last: latest,
      bridged: bridged,
      lapsed: lapsed,
      freezesUsedThisWeek: freezesThisWeek,
    );
  }

  /// Persists a [_StreakCalc]. The all-time highest is raised to the achieved
  /// [run] (never lowered — the getter falls back to the live count when unset).
  Future<void> _persist(_StreakCalc calc, {DateTime? now}) async {
    final priorHighest = highestStreak;
    await _box.put(_kStreakCount, calc.current);
    if (calc.last != null) {
      await _box.put(_kLastActivity, _dateStr(calc.last!));
    } else {
      await _box.delete(_kLastActivity);
    }
    await _box.put(_kFreezeDates, calc.bridged);
    await _box.put(_kWeekAnchor, _dateStr(_monday(now ?? DateTime.now())));
    await _box.put(_kFreezesUsed, calc.freezesUsedThisWeek);
    await _box.put(
        _kHighestStreak, priorHighest > calc.run ? priorHighest : calc.run);
    _refreshNotifier();
  }

  Future<void> resetStreak() async {
    await _box.put(_kStreakCount, 0);
    await _box.delete(_kLastActivity);
    await _box.put(_kFreezesUsed, 0);
    _refreshNotifier();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static String _dateStr(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  static DateTime _monday(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day)
          .subtract(Duration(days: dt.weekday - 1));

  Future<void> _reschedule() => NotificationService().rescheduleReminder(
        hour: notifsHour,
        minute: notifsMinute,
        title: _notifTitle,
        body: _notifBody,
        sound: notifsSound,
        vibration: notifsVibration,
      );

  Future<void> _rescheduleForTomorrow() => NotificationService().rescheduleReminder(
        hour: notifsHour,
        minute: notifsMinute,
        title: _notifTitle,
        body: _notifBody,
        sound: notifsSound,
        vibration: notifsVibration,
        forceNextDay: true,
      );

  void _refreshNotifier() {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));
    streakNotifier.value = StreakState(
      streakCount: currentStreak,
      highestStreak: highestStreak,
      freezesRemaining: freezesRemainingThisWeek,
      streakEnabled: streakEnabled,
      completedToday: lastActivityDate == _dateStr(today),
      usedFreezeYesterday: freezeDaySet().contains(yesterday),
    );
  }
}
