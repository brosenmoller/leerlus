import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:leerlus/services/notification_service.dart';

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
  static const _kLastFreezeDate = 'streak_last_freeze_date';
  static const _kNotifsEnabled = 'streak_notifs_enabled';
  static const _kNotifsHour = 'streak_notifs_hour';
  static const _kNotifsMinute = 'streak_notifs_minute';

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

  /// Call whenever the user completes a quiz or SRS session.
  /// Handles freeze logic automatically and returns what happened.
  Future<StreakEvent> recordActivity() async {
    if (!streakEnabled) return StreakEvent.disabled;

    final today = DateTime.now();
    final todayStr = _dateStr(today);

    await _maybeResetWeeklyFreezes(today);

    final last = lastActivityDate;

    // Already counted today — idempotent.
    if (last == todayStr) return StreakEvent.sameDay;

    // First activity ever.
    if (last == null) {
      await _box.put(_kStreakCount, 1);
      await _box.put(_kLastActivity, todayStr);
      _refreshNotifier();
      return StreakEvent.continued;
    }

    final lastDt = DateTime.parse(last);
    final daysSince = DateTime(today.year, today.month, today.day)
        .difference(DateTime(lastDt.year, lastDt.month, lastDt.day))
        .inDays;

    int newStreak;
    StreakEvent event;

    if (daysSince == 1) {
      // Perfectly consecutive day.
      newStreak = currentStreak + 1;
      event = StreakEvent.continued;
    } else {
      // Gap: daysSince-1 missed days need to be covered by freezes.
      final missedDays = daysSince - 1;
      final available = freezesRemainingThisWeek;

      if (available <= 0) {
        // No freezes left — streak breaks.
        newStreak = 1;
        event = StreakEvent.reset;
      } else if (available >= missedDays) {
        // Enough freezes to cover all missed days.
        await _box.put(_kFreezesUsed, freezesUsedThisWeek + missedDays);
        await _box.put(_kLastFreezeDate, _dateStr(today.subtract(const Duration(days: 1))));
        newStreak = currentStreak + 1;
        event = StreakEvent.freezeUsed;
      } else {
        // Not enough freezes — use what's left, streak still breaks.
        await _box.put(_kFreezesUsed, maxFreezesPerWeek);
        newStreak = 1;
        event = StreakEvent.reset;
      }
    }

    await _box.put(_kStreakCount, newStreak);
    await _box.put(_kLastActivity, todayStr);
    if (newStreak > highestStreak) {
      await _box.put(_kHighestStreak, newStreak);
    }
    _refreshNotifier();
    // Push the daily reminder to tomorrow so it doesn't fire on a day already studied.
    if (notifsEnabled && streakEnabled) await _rescheduleForTomorrow();
    return event;
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

  /// Merges incoming streak data from a sync peer.
  /// Only applied when the remote state is "better" (higher count or more recent date).
  /// Highest streak is always merged as the max of local and remote.
  Future<void> mergeFromSync({
    required int remoteCount,
    required String? remoteLastDate,
    required int remoteFreezesUsed,
    required String? remoteWeekAnchor,
    int remoteHighestStreak = 0,
  }) async {
    final localCount = currentStreak;
    final localDate = lastActivityDate;

    final remoteWins = remoteCount > localCount ||
        (remoteCount == localCount &&
            remoteLastDate != null &&
            (localDate == null ||
                remoteLastDate.compareTo(localDate) > 0));

    if (remoteWins) {
      await _box.put(_kStreakCount, remoteCount);
      if (remoteLastDate != null) {
        await _box.put(_kLastActivity, remoteLastDate);
      } else {
        await _box.delete(_kLastActivity);
      }
      await _box.put(_kFreezesUsed, remoteFreezesUsed);
      if (remoteWeekAnchor != null) {
        await _box.put(_kWeekAnchor, remoteWeekAnchor);
      }
    }

    // Always take the highest streak from either side.
    final newHighest = [highestStreak, remoteHighestStreak, remoteCount].reduce((a, b) => a > b ? a : b);
    if (newHighest > highestStreak) {
      await _box.put(_kHighestStreak, newHighest);
    }

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

  Future<void> _maybeResetWeeklyFreezes(DateTime today) async {
    final thisMonday = _dateStr(_monday(today));
    if (weekAnchor != thisMonday) {
      await _box.put(_kWeekAnchor, thisMonday);
      await _box.put(_kFreezesUsed, 0);
    }
  }

  Future<void> _reschedule() => NotificationService().rescheduleReminder(
        hour: notifsHour,
        minute: notifsMinute,
        title: _notifTitle,
        body: _notifBody,
      );

  Future<void> _rescheduleForTomorrow() => NotificationService().rescheduleReminder(
        hour: notifsHour,
        minute: notifsMinute,
        title: _notifTitle,
        body: _notifBody,
        forceNextDay: true,
      );

  void _refreshNotifier() {
    final today = DateTime.now();
    final yesterdayStr = _dateStr(today.subtract(const Duration(days: 1)));
    final lastFreezeDate = _box.get(_kLastFreezeDate) as String?;
    streakNotifier.value = StreakState(
      streakCount: currentStreak,
      highestStreak: highestStreak,
      freezesRemaining: freezesRemainingThisWeek,
      streakEnabled: streakEnabled,
      completedToday: lastActivityDate == _dateStr(today),
      usedFreezeYesterday: lastFreezeDate == yesterdayStr,
    );
  }
}
