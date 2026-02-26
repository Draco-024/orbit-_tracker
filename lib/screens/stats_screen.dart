import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Habit> habits = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedHabits = prefs.getStringList('orbit_habits');
    
    if (storedHabits != null) {
      habits = storedHabits.map((h) => Habit.fromJson(h)).toList();
    }
    
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  static DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  int get _bestActiveStreak {
    if (habits.isEmpty) return 0;
    return habits.map((h) => h.currentStreak).reduce((a, b) => a > b ? a : b);
  }

  List<List<Habit>> _getWeeklyCompletions() {
    List<List<Habit>> weekly = [];
    final today = _stripTime(DateTime.now());

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      List<Habit> completedThatDay = [];
      
      for (var habit in habits) {
        if (date.compareTo(_stripTime(habit.createdAt)) >= 0 && habit.isCompletedOn(date)) {
          completedThatDay.add(habit);
        }
      }
      weekly.add(completedThatDay);
    }
    return weekly;
  }

  int _getTotalActiveHabitsOnDate(DateTime date) {
    return habits.where((h) => date.compareTo(_stripTime(h.createdAt)) >= 0).length;
  }

  List<double> _getHeatmapData() {
    List<double> heatmap = [];
    final today = _stripTime(DateTime.now());

    for (int i = 83; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      int completions = 0;
      int activeHabits = _getTotalActiveHabitsOnDate(date);
      
      if (activeHabits == 0) {
        heatmap.add(0.0);
        continue;
      }

      for (var habit in habits) {
        if (date.compareTo(_stripTime(habit.createdAt)) >= 0 && habit.isCompletedOn(date)) {
          completions++;
        }
      }
      heatmap.add(completions / activeHabits);
    }
    return heatmap;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: colorScheme.secondary)));
    }

    final today = _stripTime(DateTime.now());
    final visibleHabitsToday = habits.where((h) => today.compareTo(_stripTime(h.createdAt)) >= 0).toList();
    final completedToday = visibleHabitsToday.where((h) => h.isCompletedOn(today)).length;
    double completionRate = visibleHabitsToday.isEmpty ? 0 : completedToday / visibleHabitsToday.length;
    
    final weeklyCompletions = _getWeeklyCompletions();
    final heatmapData = _getHeatmapData();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -50, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.secondary.withValues(alpha: isLight ? 0.1 : 0.06)),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 6.seconds),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Insights", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1, color: colorScheme.primary)).animate().fadeIn().slideY(begin: -0.2),
                  const SizedBox(height: 32),
                  
                  Center(
                    child: Column(
                      children: [
                        Text("Current Alignment", style: TextStyle(color: colorScheme.primary.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5)).animate().fadeIn(delay: 100.ms),
                        const SizedBox(height: 32),
                        _buildOrbitalCore(visibleHabitsToday, today, theme),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 48),

                  Row(
                    children: [
                      Expanded(child: _buildStatCard("Today's Orbit", "${(completionRate * 100).toInt()}%", Icons.track_changes_rounded, theme, delay: 100)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard("Top Streak", "$_bestActiveStreak Days", Icons.local_fire_department_rounded, theme, delay: 200)),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  Text("7-Day Trajectory", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.primary, letterSpacing: -0.5)).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 20),
                  
                  Container(
                    height: 260,
                    padding: const EdgeInsets.only(top: 32, right: 24, left: 24, bottom: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))]
                    ),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceBetween,
                        maxY: 100,
                        minY: 0,
                        gridData: FlGridData(
                          show: true, drawVerticalLine: false, horizontalInterval: 25,
                          getDrawingHorizontalLine: (value) => FlLine(color: colorScheme.onSurface.withValues(alpha: 0.05), strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final date = today.subtract(Duration(days: 6 - value.toInt()));
                                final dayStr = DateFormat('E').format(date).substring(0, 1);
                                final isToday = value.toInt() == 6;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(dayStr, style: TextStyle(color: isToday ? colorScheme.secondary : colorScheme.primary.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(7, (index) {
                          final completedHabits = weeklyCompletions[index];
                          final dateForColumn = today.subtract(Duration(days: 6 - index));
                          final totalPossible = _getTotalActiveHabitsOnDate(dateForColumn);

                          double currentY = 0;
                          List<BarChartRodStackItem> stackItems = [];
                          double chunk = totalPossible > 0 ? (100.0 / totalPossible) : 0;

                          for (var habit in completedHabits) {
                            stackItems.add(BarChartRodStackItem(currentY, currentY + chunk, Color(habit.colorValue)));
                            currentY += chunk;
                          }

                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: currentY > 0 ? currentY : 0.1,
                                width: 18,
                                borderRadius: BorderRadius.circular(6),
                                rodStackItems: stackItems, 
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: 100,
                                  color: colorScheme.onSurface.withValues(alpha: 0.03),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ).animate().fadeIn(delay: 400.ms).scale(duration: 500.ms, curve: Curves.easeOutBack),
                  ),

                  const SizedBox(height: 40),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("12-Week Matrix", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.primary, letterSpacing: -0.5)),
                      Text("Last 84 Days", style: TextStyle(color: colorScheme.primary.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 20),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05), width: 1.5),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(84, (index) {
                        final rate = heatmapData[index];
                        Color cellColor = colorScheme.onSurface.withValues(alpha: 0.03);
                        if (rate > 0 && rate < 0.4) {
                          cellColor = colorScheme.secondary.withValues(alpha: 0.3);
                        } else if (rate >= 0.4 && rate < 0.8) {
                          cellColor = colorScheme.secondary.withValues(alpha: 0.6);
                        } else if (rate >= 0.8) {
                          cellColor = colorScheme.secondary;
                        }

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: (MediaQuery.of(context).size.width - 48 - 48 - (11 * 8)) / 12, 
                          height: (MediaQuery.of(context).size.width - 48 - 48 - (11 * 8)) / 12, 
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: rate >= 0.8 ? [BoxShadow(color: cellColor.withValues(alpha: 0.5), blurRadius: 4)] : [],
                          ),
                        ).animate().scale(delay: Duration(milliseconds: index * 5)); 
                      }),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbitalCore(List<Habit> activeHabits, DateTime today, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    if (activeHabits.isEmpty) {
      return Container(
        height: 180, width: 180,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1), width: 2, style: BorderStyle.solid)),
        child: Center(child: Icon(Icons.blur_circular_rounded, color: colorScheme.primary.withValues(alpha: 0.2), size: 40)),
      ).animate().fadeIn();
    }

    final int maxDisplayRings = 10;
    final List<Habit> displayHabits = activeHabits.take(maxDisplayRings).toList();
    final int outerHabitsCount = activeHabits.length > maxDisplayRings ? activeHabits.length - maxDisplayRings : 0;

    double currentSize = 220.0;
    double minSize = 60.0; 
    double gapSize = displayHabits.length > 1 ? (currentSize - minSize) / (displayHabits.length - 1) : 0;
    
    List<Widget> rings = [];

    // Center Sun
    rings.add(
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.primary,
          boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)]
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 2.seconds),
    );

    for (int i = 0; i < displayHabits.length; i++) {
      final habit = displayHabits[i];
      final isDone = habit.isCompletedOn(today);
      final color = Color(habit.colorValue);
      final strokeWidth = displayHabits.length > 6 ? 1.5 : 2.5; 
      
      final actualBorderWidth = isDone ? strokeWidth + 1 : strokeWidth;
      final double exactOffset = -(4.0 + (actualBorderWidth / 2));

      rings.insert(0, 
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone ? color : colorScheme.onSurface.withValues(alpha: 0.05),
              width: actualBorderWidth,
            ),
            boxShadow: isDone 
              ? [
                  BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 0),
                  BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 5, spreadRadius: 1) 
                ] 
              : [],
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: isDone
              ? Transform.translate(
                  offset: Offset(0, exactOffset), 
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      color: color, 
                      boxShadow: [BoxShadow(color: color, blurRadius: 10)]
                    ),
                  ).animate(onPlay: (c) => c.repeat()).moveX(begin: -5, end: 5, duration: 2.seconds, curve: Curves.easeInOutSine),
                )
              : null,
          ),
        ).animate().scale(delay: Duration(milliseconds: 50 * i), duration: 600.ms, curve: Curves.easeOutBack)
      );
      
      currentSize -= gapSize; 
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          width: 220,
          child: Stack(
            alignment: Alignment.center,
            children: rings,
          ),
        ),
        if (outerHabitsCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text("+$outerHabitsCount tasks in outer orbit", style: TextStyle(color: colorScheme.primary.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.bold)),
          )
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, ThemeData theme, {required int delay}) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colorScheme.onSurface.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(icon, color: colorScheme.primary.withValues(alpha: 0.7), size: 24),
          ),
          const SizedBox(height: 24),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colorScheme.primary, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.primary.withValues(alpha: 0.5))),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.1);
  }
}