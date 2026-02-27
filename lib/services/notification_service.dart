import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Function(String)? onAction;

  Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestSoundPermission: false,
            requestBadgePermission: false,
            requestAlertPermission: false);

    final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId != null) {
          onAction?.call(response.actionId!);
        }
      },
    );
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    bool isAllowed = false;

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      try { await androidImplementation?.requestExactAlarmsPermission(); } catch (_) {}
      isAllowed = granted ?? false;
    } else if (Platform.isIOS) {
      final bool? granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      isAllowed = granted ?? false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_allowed', isAllowed);
    return isAllowed;
  }

  // 1. PREMIUM LIVE-COUNTDOWN FOREGROUND SERVICE
  Future<void> showActiveTimerNotification(String habitName, int durationInSeconds) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    if (Platform.isAndroid) {
      final androidConfig = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          
      await androidConfig?.startForegroundService(
        1,
        '⏱️ Focus Session',
        'Deep work: $habitName',
        notificationDetails: AndroidNotificationDetails(
          'orbit_active_timer_v14', 
          'Active Timer',
          channelDescription: 'Live focus countdown',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true, // UN-REMOVABLE
          category: AndroidNotificationCategory.progress,
          color: const Color(0xFF007AFF), 
          
          // THE FIX: The OS will destroy this notification at EXACTLY zero. It will never count up.
          timeoutAfter: durationInSeconds * 1000, 
          when: DateTime.now().add(Duration(seconds: durationInSeconds)).millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          showWhen: true,

          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction('pause_action', '⏸️ Pause', showsUserInterface: true),
            const AndroidNotificationAction('stop_action', '⏹️ Stop', showsUserInterface: true),
          ],
        ),
      );
    } else {
      await flutterLocalNotificationsPlugin.show(
        1, '⏱️ Focus Session', 'Deep work: $habitName',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
      );
    }
  }

  // 2. PREMIUM TASK COMPLETED NOTIFICATION
  Future<void> showTaskCompletedNotification(String habitName) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    await flutterLocalNotificationsPlugin.show(
      0, 
      '✅ Target Reached',
      'Flawless execution. "$habitName" is complete.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'orbit_focus_complete_v14', 
          'Timer Complete Alerts',
          importance: Importance.max, 
          priority: Priority.max,     
          visibility: NotificationVisibility.public, 
          category: AndroidNotificationCategory.status,
          color: Color(0xFF50C878), 
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
      ),
    );
  }

  // 3. BACKUP ALARM (Fires exactly when timeoutAfter destroys the active one)
  Future<void> scheduleFocusComplete(int seconds, String habitName) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0, 
        '✅ Target Reached',
        'Flawless execution. "$habitName" is complete.',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'orbit_focus_complete_v14', 
            'Timer Complete Alerts',
            importance: Importance.max, 
            priority: Priority.max,     
            visibility: NotificationVisibility.public, 
            category: AndroidNotificationCategory.status,
            color: Color(0xFF50C878),
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, 
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Fallback
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0, '✅ Target Reached', 'Flawless execution. "$habitName" is complete.',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
        const NotificationDetails(android: AndroidNotificationDetails('orbit_focus_complete_v14', 'Timer Complete Alerts', importance: Importance.high, priority: Priority.high)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, 
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // 4. SMART DAILY REMINDER
  Future<void> scheduleDailyReminder() async {} 
  
  Future<void> updateSmartDailyReminder(bool allTasksCompleted) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0); // 8:00 PM

    // Pushes the alarm to tomorrow if tasks are done, so it doesn't annoy you.
    if (allTasksCompleted || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      2, 'Orbit Status Check 🪐', 'You have unfinished routines waiting. Stay consistent!', scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails('orbit_daily_reminder_v14', 'Daily Reminders', importance: Importance.high, priority: Priority.high, category: AndroidNotificationCategory.reminder)
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> stopForegroundServiceSafely() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      try { await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.stopForegroundService(); } catch (_) {}
    }
    try { await flutterLocalNotificationsPlugin.cancel(1); } catch (_) {}
  }

  Future<void> cancelFocusTimerAlarm() async {
    if (kIsWeb) return;
    try { await flutterLocalNotificationsPlugin.cancel(0); } catch (_) {}
  }
}