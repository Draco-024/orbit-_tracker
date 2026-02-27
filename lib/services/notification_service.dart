import 'dart:io';
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

      final bool? granted =
          await androidImplementation?.requestNotificationsPermission();
      
      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (_) {}
      
      isAllowed = granted ?? false;
    } else if (Platform.isIOS) {
      final bool? granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      isAllowed = granted ?? false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_allowed', isAllowed);

    return isAllowed;
  }

  Future<void> showActiveTimerNotification(String habitName) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    if (Platform.isAndroid) {
      final androidConfig = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          
      await androidConfig?.startForegroundService(
        1,
        '⏱️ Focus Mode Active',
        'Currently focusing on "$habitName".',
        notificationDetails: const AndroidNotificationDetails(
          'orbit_active_timer_v11', 
          'Active Timer',
          channelDescription: 'Ongoing focus timer',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true, // HOTSPOT PINNED
          usesChronometer: true,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('pause_action', '⏸️ Pause', showsUserInterface: true),
            AndroidNotificationAction('stop_action', '⏹️ Stop', showsUserInterface: true),
          ],
        ),
      );
    } else {
      await flutterLocalNotificationsPlugin.show(
        1, '⏱️ Focus Mode Active', 'Currently focusing on "$habitName".',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
      );
    }
  }

  Future<void> showTaskCompletedNotification(String habitName) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    await flutterLocalNotificationsPlugin.show(
      0, 
      '✅ Task Completed',
      'You completed your focus session for "$habitName"!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'orbit_focus_complete_v11', 
          'Timer Complete Alerts',
          channelDescription: 'Alerts when a focus session ends',
          importance: Importance.max, 
          priority: Priority.max,     
          visibility: NotificationVisibility.public, 
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
      ),
    );
  }

  Future<void> scheduleFocusComplete(int seconds, String habitName) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0, 
        '✅ Task Completed',
        'You completed your focus session for "$habitName"!',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'orbit_focus_complete_v11', 
            'Timer Complete Alerts',
            importance: Importance.max, 
            priority: Priority.max,     
            visibility: NotificationVisibility.public, 
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, 
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Fallback if Android 14+ forces a deny
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0, '✅ Task Completed', 'You completed your focus session for "$habitName"!',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
        const NotificationDetails(android: AndroidNotificationDetails('orbit_focus_complete_v11', 'Timer Complete Alerts', importance: Importance.high, priority: Priority.high)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, 
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> scheduleDailyReminder() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
    if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 1));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      2, 'Orbit Status Check 🪐', 'Have you completed your routines today?', scheduledDate,
      const NotificationDetails(android: AndroidNotificationDetails('orbit_daily_reminder_v11', 'Daily Reminders')),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> stopForegroundServiceSafely() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      try {
        await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.stopForegroundService();
      } catch (_) {}
    }
    try {
      await flutterLocalNotificationsPlugin.cancel(1); 
    } catch (_) {}
  }

  Future<void> cancelFocusTimerAlarm() async {
    if (kIsWeb) return;
    try {
      await flutterLocalNotificationsPlugin.cancel(0); 
    } catch (_) {}
  }

  Future<void> cancelNotifications() async {
    if (kIsWeb) return; 
    await cancelFocusTimerAlarm();
  }
}