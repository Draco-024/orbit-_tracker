import 'dart:async';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import 'notification_service.dart';

class TimerService extends ChangeNotifier with WidgetsBindingObserver {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  
  TimerService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  Habit? activeHabit;
  int totalSeconds = 25 * 60;
  int currentSeconds = 25 * 60;
  int elapsedSeconds = 0;
  bool isRunning = false;
  bool isPaused = false;
  DateTime? endTime;
  Timer? _timer;

  // Callback to inform screens when the mission is complete
  Function(Habit, int)? onTimerComplete;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If user returns to app, sync the timer instantly based on the wall clock
    if (state == AppLifecycleState.resumed && isRunning && !isPaused && endTime != null) {
      final remaining = endTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        currentSeconds = 0;
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
    NotificationService().cancelNotifications();
    notifyListeners();
  }

  void stopAndCancel() {
    isRunning = false;
    isPaused = false;
    _timer?.cancel();
    NotificationService().cancelNotifications();
    activeHabit = null;
    notifyListeners();
  }

  void complete() {
    _timer?.cancel();
    isRunning = false;
    isPaused = false;
    if (activeHabit != null && onTimerComplete != null) {
      onTimerComplete!(activeHabit!, elapsedSeconds); 
    }
    activeHabit = null;
    NotificationService().cancelNotifications();
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