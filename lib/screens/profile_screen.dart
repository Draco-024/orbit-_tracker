import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../main.dart'; // Ensure this points to where accentPaletteNotifier is defined

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>> _loadProfileStats() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedHabits = prefs.getStringList('orbit_habits');
    
    int totalHabits = 0;
    int totalCompletions = 0;
    int totalFocusSeconds = 0; 
    
    if (storedHabits != null) {
      final habits = storedHabits.map((h) => Habit.fromJson(h)).toList();
      totalHabits = habits.length;
      for (var habit in habits) {
        totalCompletions += habit.completedDays.length;
        totalFocusSeconds += habit.totalFocusSeconds;
      }
    }

    int orbitScore = (totalHabits * 50) + (totalCompletions * 100);

    return {
      'habits': totalHabits,
      'completions': totalCompletions,
      'score': orbitScore,
      'focusSeconds': totalFocusSeconds,
    };
  }

  Future<void> _updateTheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('orbit_theme_palette', index);
    accentPaletteNotifier.value = index;
    HapticFeedback.mediumImpact();
  }

  Future<void> _exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final habits = prefs.getStringList('orbit_habits') ?? [];
    final journals = prefs.getString('orbit_journals') ?? "{}";
    
    final backupData = {
      'habits': habits,
      'journals': journals,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    
    final jsonString = json.encode(backupData);
    await Clipboard.setData(ClipboardData(text: jsonString));
    
    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Backup copied to clipboard! Save it to your notes."),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _factoryReset() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        title: const Text("Reset All Data?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("This will permanently delete all your routines, journals, and cosmic progress. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pop(context);
              setState(() {}); 
              HapticFeedback.heavyImpact();
            },
            child: const Text("Delete Everything", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String getRankName(int score) {
    if (score < 500) return "Stardust";
    if (score < 2000) return "Meteor";
    if (score < 5000) return "Satellite";
    if (score < 10000) return "Lunar Voyager";
    if (score < 25000) return "Solar Captain";
    return "Supernova";
  }

  int getNextRankGoal(int score) {
    if (score < 500) return 500;
    if (score < 2000) return 2000;
    if (score < 5000) return 5000;
    if (score < 10000) return 10000;
    if (score < 25000) return 25000;
    return 50000;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadProfileStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final stats = snapshot.data!;
        final score = stats['score'] as int;
        final totalHabits = stats['habits'] as int;
        final totalCompletions = stats['completions'] as int;
        final totalFocusSecs = stats['focusSeconds'] as int;
        
        final hours = totalFocusSecs ~/ 3600;
        final minutes = (totalFocusSecs % 3600) ~/ 60;
        final focusString = "${hours}h ${minutes}m";

        final rankName = getRankName(score);
        final nextGoal = getNextRankGoal(score);
        final rankColor = Theme.of(context).colorScheme.secondary;
        double progressToNextRank = (score / nextGoal).clamp(0.0, 1.0);

        return Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: -100, left: -50,
                child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rankColor.withValues(alpha: 0.1)),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 10.seconds),
              ),
              
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Astronaut Profile", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                      ),
                      const SizedBox(height: 32),

                      // THEME SWITCHER
                      _buildSectionHeader("Interface Vibe"),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildThemeButton(0, "Midnight", const Color(0xFF09090B), const Color(0xFF00F2FE)),
                          const SizedBox(width: 12),
                          _buildThemeButton(1, "Solar", Colors.white, const Color(0xFF007AFF)),
                          const SizedBox(width: 12),
                          _buildThemeButton(2, "Zen", const Color(0xFF0D1B1E), const Color(0xFF6CF0B2)),
                        ],
                      ),
                      
                      const SizedBox(height: 48),

                      // RANK BADGE
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 140, height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: rankColor.withValues(alpha: 0.3), width: 2),
                              boxShadow: [BoxShadow(color: rankColor.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 10)],
                            ),
                          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                          Icon(Icons.rocket_launch_rounded, size: 64, color: rankColor).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -5, end: 5, duration: 2.seconds),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      Text("Rank: $rankName", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: rankColor)).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 8),
                      Text("$score Orbit Points", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)).animate().fadeIn(delay: 300.ms),
                      
                      const SizedBox(height: 32),

                      Row(
                        children: [
                          Expanded(child: _buildSmallStatCard("Routines", "$totalHabits", Icons.list_alt_rounded)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSmallStatCard("Ticks", "$totalCompletions", Icons.check_circle_outline_rounded)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSmallStatCard("Focus", focusString, Icons.timer_outlined)),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Next Milestone", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text("$score / $nextGoal", style: TextStyle(color: rankColor, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progressToNextRank, 
                                minHeight: 8, 
                                backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), 
                                color: rankColor,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                      const SizedBox(height: 48),
                      _buildSectionHeader("System Controls"),
                      const SizedBox(height: 16),

                      _buildSettingsTile(
                        icon: Icons.ios_share_rounded, 
                        title: "Backup Data to Clipboard", 
                        color: Theme.of(context).colorScheme.onSurface,
                        onTap: _exportData,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTile(
                        icon: Icons.warning_rounded, 
                        title: "Erase All Data", 
                        color: Colors.redAccent, 
                        isDanger: true,
                        onTap: _factoryReset,
                      ),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeButton(int index, String label, Color bg, Color accent) {
    return ValueListenableBuilder<int>(
      valueListenable: accentPaletteNotifier,
      builder: (context, activeIndex, _) {
        bool isSelected = activeIndex == index;
        return Expanded(
          child: GestureDetector(
            onTap: () => _updateTheme(index),
            child: AnimatedContainer(
              duration: 300.ms,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? accent : Colors.grey.withValues(alpha: 0.2), width: 2),
                boxShadow: isSelected ? [BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 10)] : [],
              ),
              child: Column(
                children: [
                  CircleAvatar(backgroundColor: accent, radius: 8),
                  const SizedBox(height: 8),
                  Text(label, style: TextStyle(color: index == 1 ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft, 
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey))
    );
  }

  Widget _buildSmallStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required Color color, bool isDanger = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDanger ? color.withValues(alpha: 0.05) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDanger ? color.withValues(alpha: 0.2) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: isDanger ? color : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 16)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), size: 16),
          ],
        ),
      ),
    );
  }
}