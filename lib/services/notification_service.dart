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

  // NEW: A listener to handle when you click "Pause" or "Stop" on the notification
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
      // NEW: This catches the button clicks from the notification tray!
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
      
      await androidImplementation?.requestExactAlarmsPermission();
      
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

  // 1. PERMANENT STICKY NOTIFICATION (WITH BUTTONS)
  Future<void> showActiveTimerNotification(String habitName, int durationInSeconds) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    await flutterLocalNotificationsPlugin.show(
      1, 
      '⏱️ Focus Mode Active',
      'Currently focusing on "$habitName".',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'orbit_active_timer_v5', 
          'Active Timer',
          channelDescription: 'Ongoing focus timer',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: true, // Non-removable while running
          autoCancel: false,
          showWhen: true,
          usesChronometer: true,
          // MAGIC: OS deletes this sticky notification the exact second the timer ends
          timeoutAfter: durationInSeconds * 1000, 
          // NEW: ACTION BUTTONS
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'pause_action',
              '⏸️ Pause',
              showsUserInterface: true, // Wakes app safely to pause memory
            ),
            const AndroidNotificationAction(
              'stop_action',
              '⏹️ Stop',
              showsUserInterface: true, // Wakes app safely to clear memory
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // 2. TIMER COMPLETED POPUP (REMOVABLE)
  Future<void> scheduleFocusComplete(int seconds, String habitName) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, 
      '✅ Task Completed',
      'You completed your focus session for "$habitName"!',
      tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'orbit_focus_complete_v5', 
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, 
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 3. DAILY 8 PM REMINDER
  Future<void> scheduleDailyReminder() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_allowed') ?? false)) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      2, 
      'Orbit Status Check 🪐',
      'Have you completed your routines today?',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'orbit_daily_reminder_v5',
          'Daily Reminders',
          channelDescription: 'Evening reminder to check tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelActiveTimerNotification() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(1); 
  }

  Future<void> cancelFocusTimerAlarm() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(0); 
  }

  Future<void> cancelNotifications() async {
    if (kIsWeb) return; 
    await cancelFocusTimerAlarm();
  }
}