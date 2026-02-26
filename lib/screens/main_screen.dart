import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'home_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const StatsScreen(),
    const ProfileScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _screens[_currentIndex],
      extendBody: true, 
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: colorScheme.secondary.withValues(alpha: isLight ? 0.05 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: isLight ? 0.9 : 0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.track_changes_rounded, "Orbit", theme),
                  _buildNavItem(1, Icons.insights_rounded, "Insights", theme),
                  _buildNavItem(2, Icons.person_rounded, "Profile", theme), 
                ],
              ),
            ),
          ),
        ),
      ).animate().slideY(begin: 1, duration: 600.ms, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, ThemeData theme) {
    bool isSelected = _currentIndex == index;
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.secondary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.secondary : colorScheme.primary.withValues(alpha: 0.4),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ).animate().fadeIn().slideX(begin: -0.2),
            ]
          ],
        ),
      ),
    );
  }
}