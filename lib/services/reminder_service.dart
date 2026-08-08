import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final details = const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(details);
      _ready = true;
    } catch (e) {
      _ready = false;
      debugPrint('Notifications unavailable: $e');
    }
  }

  bool get isReady => _ready;

  Future<bool> scheduleRevisit(String ideaId, String title, DateTime when) async {
    if (!_ready) return false;
    try {
      final now = DateTime.now();
      var at = when;
      if (at.isBefore(now)) {
        at = now.add(const Duration(minutes: 1));
      }
      final scheduledAt = tz.TZDateTime.from(at, tz.local);
      await _plugin.zonedSchedule(
        ideaId.hashCode,
        'Revisit your idea 💡',
        'Time to look at "$title" again',
        scheduledAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'idea_reminders',
            'Idea reminders',
            channelDescription: 'Nudges to revisit captured ideas',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (e) {
      debugPrint('Schedule failed: $e');
      return false;
    }
  }

  Future<void> cancelRevisit(String ideaId) async {
    try {
      await _plugin.cancel(ideaId.hashCode);
    } catch (_) {}
  }
}
