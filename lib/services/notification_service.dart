import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Outcome of asking the OS for notification permission.
enum NotifPermission {
  /// Granted — notifications will be shown.
  granted,

  /// Denied this time, but the system dialog can still be shown again later.
  denied,

  /// Denied permanently ("don't ask again"). The system dialog will no longer
  /// appear; the only way back is the app-settings screen ([openSettings]).
  permanentlyDenied,

  /// Notifications aren't supported on this platform.
  unsupported,
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _supported = false;

  bool get isSupported => _supported;

  static const _reminderId = 0;
  static const _channelPrefix = 'streak_reminder';
  static const _channelName = 'Daily Reminder';
  static const _channelDescription = 'Daily reminder to keep your study streak';

  /// Sound/vibration are locked into a channel when it's first created, so each
  /// combination needs its own channel id. The reminder is always high
  /// importance (heads-up — pops up at the top of the screen).
  String _channelIdFor({required bool sound, required bool vibration}) =>
      '${_channelPrefix}_s${sound ? 1 : 0}_v${vibration ? 1 : 0}';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      tz_data.initializeTimeZones();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const linux = LinuxInitializationSettings(defaultActionName: 'Open');
      const settings = InitializationSettings(android: android, linux: linux);
      await _plugin.initialize(settings);
      _supported = Platform.isAndroid || Platform.isLinux;
    } catch (_) {
      _supported = false;
    }
  }

  /// Whether the OS currently allows this app to post notifications.
  ///
  /// This reflects the *live* OS state, so it catches the case where the
  /// in-app reminder toggle is on but the user later revoked the permission
  /// (in which case scheduled notifications are silently dropped).
  Future<bool> hasPermission() async {
    if (!_supported) return false;
    if (!Platform.isAndroid) return true;
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await impl?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests POST_NOTIFICATIONS permission on Android 13+, reporting whether
  /// the request was permanently denied so the caller can route the user to
  /// the app-settings screen.
  ///
  /// On Android 13+ the system permission dialog only appears the first time
  /// (or two). After the user dismisses/denies it, further requests resolve
  /// immediately to [NotifPermission.permanentlyDenied] without showing
  /// anything — the user must re-enable it from the app's settings page via
  /// [openSettings].
  Future<NotifPermission> ensurePermission() async {
    if (!_supported) return NotifPermission.unsupported;
    if (!Platform.isAndroid) return NotifPermission.granted;
    try {
      if (await hasPermission()) return NotifPermission.granted;
      final status = await Permission.notification.request();
      if (status.isGranted) return NotifPermission.granted;
      if (status.isPermanentlyDenied) return NotifPermission.permanentlyDenied;
      return NotifPermission.denied;
    } catch (_) {
      return NotifPermission.denied;
    }
  }

  /// Opens the system settings page for this app so the user can manually
  /// grant notification permission after a permanent denial.
  Future<void> openSettings() => openAppSettings();

  /// Whether the OS will currently deliver *exact* alarms. On Android 12+
  /// (API 31+) exact alarms are gated behind a permission; if it isn't held,
  /// scheduling with [AndroidScheduleMode.exactAllowWhileIdle] throws, so we
  /// fall back to inexact instead of silently failing. With `USE_EXACT_ALARM`
  /// in the manifest this returns true without any user action.
  Future<bool> _canScheduleExact() async {
    if (!Platform.isAndroid) return true;
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await impl?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Creates the channel matching the requested [sound]/[vibration] settings
  /// and removes any stale reminder channels (including the legacy bare-id one)
  /// so the user only ever sees a single "Daily Reminder" channel in system
  /// settings. Each channel id always maps to identical settings, so deleting
  /// and later recreating one is safe.
  Future<void> _ensureChannel(
      {required bool sound, required bool vibration}) async {
    if (!Platform.isAndroid) return;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;

    final id = _channelIdFor(sound: sound, vibration: vibration);
    await impl.createNotificationChannel(AndroidNotificationChannel(
      id,
      _channelName,
      description: _channelDescription,
      importance: Importance.high, // heads-up: pops at the top of the screen
      playSound: sound,
      enableVibration: vibration,
    ));

    final existing = await impl.getNotificationChannels();
    if (existing == null) return;
    for (final c in existing) {
      if (c.id != id && c.id.startsWith(_channelPrefix)) {
        await impl.deleteNotificationChannel(c.id);
      }
    }
  }

  /// Cancels any existing reminder and schedules a new daily one at [hour]:[minute]
  /// (local time). Repeats every 24 h at the same UTC-converted time.
  /// [sound] and [vibration] control the reminder channel (both off = a silent
  /// heads-up). Set [forceNextDay] to true to skip today entirely (e.g. after
  /// recording activity).
  Future<void> rescheduleReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required bool sound,
    required bool vibration,
    bool forceNextDay = false,
  }) async {
    if (!_supported) return;
    try {
      await _plugin.cancelAll();
      await _ensureChannel(sound: sound, vibration: vibration);

      // Convert desired local time to UTC for scheduling.
      final now = DateTime.now();
      var nextLocal = DateTime(now.year, now.month, now.day, hour, minute);
      if (forceNextDay || !nextLocal.isAfter(now)) {
        nextLocal = nextLocal.add(const Duration(days: 1));
      }
      final nextUtc = nextLocal.toUtc();
      final tzDate = tz.TZDateTime(
        tz.UTC,
        nextUtc.year,
        nextUtc.month,
        nextUtc.day,
        nextUtc.hour,
        nextUtc.minute,
      );

      await _plugin.zonedSchedule(
        _reminderId,
        title,
        body,
        tzDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelIdFor(sound: sound, vibration: vibration),
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: sound,
            enableVibration: vibration,
          ),
          linux: const LinuxNotificationDetails(),
        ),
        androidScheduleMode: await _canScheduleExact()
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelReminder() async {
    if (!_supported) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
