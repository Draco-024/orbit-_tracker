import 'dart:async';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import 'notification_service.dart';

class TimerService extends ChangeNotifier with WidgetsBindingObserver {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  
  TimerService._internal() {
    WidgetsBinding.instance.addObserver(this);
    
    // NEW: Listen to the buttons pressed in the notification tray!
    NotificationService.onAction = (actionId) {
      if (actionId == 'pause_action') {
        pause();
      } else if (actionId == 'stop_action') {
        stopAndCancel();
      }
    };
  }

  Habit? activeHabit;
  int totalSeconds = 25 * 60;
  int currentSeconds = 25 * 60;
  int elapsedSeconds = 0;
  bool isRunning = false;
  bool isPaused = false;
  DateTime? endTime;
  Timer? _timer;

  Function(Habit, int)? onTimerComplete;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncBackgroundTime();
    }
  }

  void syncBackgroundTime() {
    if (isRunning && !isPaused && endTime != null) {
      final remaining = endTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        currentSeconds = 0;
        elapsedSeconds = totalSeconds; 
        complete();
      } else {
        currentSeconds = remaining;
        elapsedSeconds = totalSeconds - currentSeconds;
        notifyListeners();
      }
    }
  }

  void initialize(Habit habit) {
    if (activeHabit?.id == habit.id) return; 
    activeHabit = habit;
    totalSeconds = 25 * 60;
    currentSeconds = totalSeconds;
    elapsedSeconds = 0;
    isRunning = false;
    isPaused = false;
    notifyListeners();
  }

  void start() {
    if (activeHabit == null) return;
    isRunning = true;
    isPaused = false;
    endTime = DateTime.now().add(Duration(seconds: currentSeconds));
    
    // Pass currentSeconds so the OS automatically deletes the sticky notification when time is up
    NotificationService().showActiveTimerNotification(activeHabit!.name, currentSeconds);
    NotificationService().scheduleFocusComplete(currentSeconds, activeHabit!.name);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentSeconds > 0) {
        currentSeconds--;
        elapsedSeconds++;
        notifyListeners(); 
      } else {
        complete();
      }
    });
    notifyListeners();
  }

  void pause() {
    isPaused = true;
    _timer?.cancel();
    // User paused, so clear the active sticky and cancel the complete alarm
    NotificationService().cancelActiveTimerNotification(); 
    NotificationService().cancelFocusTimerAlarm(); 
    notifyListeners();
  }

  void stopAndCancel() {
    isRunning = false;
    isPaused = false;
    _timer?.cancel();
    NotificationService().cancelActiveTimerNotification();
    NotificationService().cancelFocusTimerAlarm(); 
    activeHabit = null;
    notifyListeners();
  }

  void complete() {
    _timer?.cancel();
    isRunning = false;
    isPaused = false;
    
    // This triggers the home screen code to automatically check the task off in the app!
    if (activeHabit != null && onTimerComplete != null) {
      onTimerComplete!(activeHabit!, elapsedSeconds); 
    }
    activeHabit = null;
    
    // Clear only the sticky notification (the timeoutAfter should also handle this, but this is a safe backup)
    NotificationService().cancelActiveTimerNotification();
    notifyListeners();
  }

  void adjustTime(int deltaMinutes) {
    if (isRunning && !isPaused) return; 
    int minutes = totalSeconds ~/ 60;
    int newMinutes = (minutes + deltaMinutes).clamp(1, 120);
    totalSeconds = newMinutes * 60;
    currentSeconds = totalSeconds;
    notifyListeners();
  }
}