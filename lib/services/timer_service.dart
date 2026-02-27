import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import 'notification_service.dart';

class TimerService extends ChangeNotifier with WidgetsBindingObserver {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  
  TimerService._internal() {
    WidgetsBinding.instance.addObserver(this);
    
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

  // --- NEW: THE "DEAD APP" RECOVERY SYSTEM ---
  Future<void> restoreState(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHabitId = prefs.getString('orbit_active_timer_habit');
    final savedEndTimeStr = prefs.getString('orbit_active_timer_end');
    final savedTotalSecs = prefs.getInt('orbit_active_timer_total');

    if (savedHabitId != null && savedEndTimeStr != null && savedTotalSecs != null) {
      final savedEndTime = DateTime.parse(savedEndTimeStr);
      final now = DateTime.now();
      
      try {
        final habit = habits.firstWhere((h) => h.id == savedHabitId);
        
        if (now.isAfter(savedEndTime)) {
          // The timer finished while the app was completely closed!
          if (onTimerComplete != null) {
            onTimerComplete!(habit, savedTotalSecs);
          }
          await _clearDiskState();
        } else {
          // App was reopened and timer is STILL running. Resume the UI!
          activeHabit = habit;
          totalSeconds = savedTotalSecs;
          currentSeconds = savedEndTime.difference(now).inSeconds;
          elapsedSeconds = totalSeconds - currentSeconds;
          endTime = savedEndTime;
          isRunning = true;
          
          _startInternalTimer();
          notifyListeners();
        }
      } catch (e) {
        await _clearDiskState(); // Habit was deleted or not found
      }
    }
  }

  Future<void> _saveToDisk(Habit habit, DateTime end, int totalSecs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('orbit_active_timer_habit', habit.id);
    await prefs.setString('orbit_active_timer_end', end.toIso8601String());
    await prefs.setInt('orbit_active_timer_total', totalSecs);
  }

  Future<void> _clearDiskState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('orbit_active_timer_habit');
    await prefs.remove('orbit_active_timer_end');
    await prefs.remove('orbit_active_timer_total');
  }
  // -------------------------------------------

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
    
    // Save to hard drive immediately in case user swipes app away
    _saveToDisk(activeHabit!, endTime!, totalSeconds);
    
    // Trigger OS-level background notifications
    NotificationService().showActiveTimerNotification(activeHabit!.name, currentSeconds);
    NotificationService().scheduleFocusComplete(currentSeconds, activeHabit!.name);

    _startInternalTimer();
    notifyListeners();
  }

  void _startInternalTimer() {
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
  }

  void pause() {
    isPaused = true;
    _timer?.cancel();
    _clearDiskState(); // Clear hard drive state
    NotificationService().cancelActiveTimerNotification(); 
    NotificationService().cancelFocusTimerAlarm(); 
    notifyListeners();
  }

  void stopAndCancel() {
    isRunning = false;
    isPaused = false;
    _timer?.cancel();
    _clearDiskState();
    NotificationService().cancelActiveTimerNotification();
    NotificationService().cancelFocusTimerAlarm(); 
    activeHabit = null;
    notifyListeners();
  }

  void complete() {
    _timer?.cancel();
    isRunning = false;
    isPaused = false;
    
    // Clear state
    _clearDiskState();
    NotificationService().cancelActiveTimerNotification();

    if (activeHabit != null && onTimerComplete != null) {
      onTimerComplete!(activeHabit!, elapsedSeconds); 
    }
    
    activeHabit = null;
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