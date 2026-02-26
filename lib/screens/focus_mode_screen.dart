import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/habit.dart';
import '../services/timer_service.dart';

class FocusModeScreen extends StatefulWidget {
  final Habit habit;
  const FocusModeScreen({super.key, required this.habit});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final TimerService timerService = TimerService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    timerService.initialize(widget.habit);
    
    if (timerService.isRunning && !timerService.isPaused) {
      _pulseController.repeat(reverse: true);
    }
    
    timerService.addListener(_handleTimerStateChanges);
  }

  void _handleTimerStateChanges() {
    if (mounted) {
      if (timerService.isRunning && !timerService.isPaused && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      } else if (timerService.isPaused && _pulseController.isAnimating) {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    timerService.removeListener(_handleTimerStateChanges);
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.habit.colorValue);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: timerService,
          builder: (context, child) {
            final progress = timerService.totalSeconds > 0 
                ? timerService.currentSeconds / timerService.totalSeconds 
                : 0.0;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(IconData(widget.habit.iconCodePoint, fontFamily: widget.habit.iconFontFamily), size: 16, color: color),
                            const SizedBox(width: 8),
                            Text("Deep Focus", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), 
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    width: 280 + (_pulseController.value * 80),
                                    height: 280 + (_pulseController.value * 80),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color.withValues(alpha: 0.02 + (_pulseController.value * 0.08)), 
                                    ),
                                  );
                                },
                              ),
                              SizedBox(
                                width: 280,
                                height: 280,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                  valueColor: AlwaysStoppedAnimation(color),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(timerService.currentSeconds),
                                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]),
                                  ),
                                  if (!timerService.isRunning)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white24), onPressed: () => timerService.adjustTime(-5)),
                                          const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Text("Adjust", style: TextStyle(color: Colors.white24))),
                                          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white24), onPressed: () => timerService.adjustTime(5)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text(widget.habit.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text(timerService.isRunning ? "Ends at ${TimeOfDay.fromDateTime(timerService.endTime ?? DateTime.now()).format(context)}" : "Stay in orbit.", style: const TextStyle(color: Colors.white38)),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 40, top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (timerService.isRunning && !timerService.isPaused)
                        FloatingActionButton.large(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            timerService.pause();
                          },
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          elevation: 0,
                          child: const Icon(Icons.pause_rounded, color: Colors.white, size: 40),
                        )
                      else ...[
                        if (timerService.isPaused) ...[
                           FloatingActionButton(
                             onPressed: () {
                               HapticFeedback.mediumImpact();
                               timerService.stopAndCancel();
                             },
                             backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                             elevation: 0,
                             child: const Icon(Icons.stop_rounded, color: Colors.redAccent),
                           ),
                           const SizedBox(width: 24),
                        ],
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8))]
                          ),
                          child: FloatingActionButton.large(
                            onPressed: () {
                              HapticFeedback.heavyImpact();
                              timerService.start();
                            },
                            backgroundColor: color,
                            elevation: 0, 
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 40),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1.seconds),
                      ]
                    ],
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}