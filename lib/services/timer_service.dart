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
      if (actionId == 'pause_action') pause();
      else if (actionId == 'stop_action') stopAndCancel();
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

  Function(Habit, int, bool)? onTimerComplete;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncBackgroundTime();
    }
  }

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
          // GHOST COMPLETE: Finished while app was dead.
          if (onTimerComplete != null) onTimerComplete!(habit, savedTotalSecs, true);
          await _clearDiskState();
        } else {
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
        await _clearDiskState(); 
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

  void syncBackgroundTime() {
    if (isRunning && !isPaused && endTime != null) {
      final remaining = endTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        currentSeconds = 0;
        elapsedSeconds = totalSeconds; 
        // Woke up and time has passed -> IT'S A GHOST. No sudden popup!
        complete(isGhost: true); 
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
    
    _saveToDisk(activeHabit!, endTime!, totalSeconds);
    
    NotificationService().showActiveTimerNotification(activeHabit!.name, currentSeconds);
    NotificationService().scheduleFocusComplete(currentSeconds, activeHabit!.name);

    _startInternalTimer();
    notifyListeners();
  }

  void _startInternalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (endTime != null && !isPaused) {
        final now = DateTime.now();
        final remaining = endTime!.difference(now).inSeconds;
        
        if (remaining <= 0) {
          currentSeconds = 0;
          elapsedSeconds = totalSeconds;
          
          // If it overshot by more than 1 second, it means the app was frozen in the background. Flag as ghost to prevent jump-scare popups.
          bool wasAsleep = endTime!.difference(now).inMilliseconds < -1000;
          complete(isGhost: wasAsleep); 
        } else {
          if (currentSeconds != remaining) {
            currentSeconds = remaining;
            elapsedSeconds = totalSeconds - currentSeconds;
            notifyListeners(); 
          }
        }
      }
    });
  }

  void pause() {
    isPaused = true;
    _timer?.cancel();
    _clearDiskState(); 
    NotificationService().stopForegroundServiceSafely(); 
    NotificationService().cancelFocusTimerAlarm(); 
    notifyListeners();
  }

  void stopAndCancel() {
    isRunning = false;
    isPaused = false;
    _timer?.cancel();
    _clearDiskState();
    NotificationService().stopForegroundServiceSafely();
    NotificationService().cancelFocusTimerAlarm(); 
    activeHabit = null;
    notifyListeners();
  }

  Future<void> complete({bool isGhost = false}) async {
    _timer?.cancel();
    isRunning = false;
    isPaused = false;
    
    await _clearDiskState();
    await NotificationService().stopForegroundServiceSafely();
    await NotificationService().cancelFocusTimerAlarm();

    if (activeHabit != null) {
      // If it's a ghost (completed in background), the OS Alarm already fired the notification. Don't double fire!
      if (!isGhost) {
        await NotificationService().showTaskCompletedNotification(activeHabit!.name);
      }

      if (onTimerComplete != null) {
        onTimerComplete!(activeHabit!, elapsedSeconds, isGhost); 
      }
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