import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One daily reminder at 19:00 when the daily puzzle is still unsolved.
///
/// Scheduling is a single one-shot notification that is re-synced whenever
/// the app opens or a daily puzzle is solved, so a solved day never nags.
class Reminders {
  Reminders._();

  static const _id = 1;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  /// Asks for the Android 13+ notification permission.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Next reminder time: today 19:00, or tomorrow if past or already solved.
  static DateTime nextTime(DateTime now, {required bool solvedToday}) {
    var at = DateTime(now.year, now.month, now.day, 19);
    if (solvedToday || !at.isAfter(now)) {
      at = DateTime(now.year, now.month, now.day + 1, 19);
    }
    return at;
  }

  static Future<void> sync({required bool enabled, required bool solvedToday}) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
      if (!enabled) return;
      final at = nextTime(DateTime.now(), solvedToday: solvedToday);
      await _plugin.zonedSchedule(
        id: _id,
        title: 'Daily ፊደል is waiting',
        body: 'A little logic, a new word. Today’s puzzle is ready.',
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Daily reminder',
            channelDescription: 'One reminder when the daily puzzle is unsolved',
            importance: Importance.defaultImportance,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Could not schedule reminder: $e');
    }
  }
}
