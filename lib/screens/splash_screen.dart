import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootApp();
  }

  Future<void> _bootApp() async {
    // Let the smooth animation play out for 2.5 seconds
    // Behind the scenes, the app is already preparing the saved data
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      // Fluid, seamless fade transition into the Main Screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800), // Smooth 0.8s fade
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing, Pulsing Core
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondary.withValues(alpha: 0.2),
                border: Border.all(color: colorScheme.secondary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.secondary.withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ]
              ),
              child: Icon(Icons.blur_circular_rounded, color: colorScheme.secondary, size: 40),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1.5.seconds, curve: Curves.easeInOutCubic)
             .fadeIn(duration: 600.ms),
            
            const SizedBox(height: 40),
            
            // Premium Typography
            Text(
              "ORBIT",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 12,
                color: colorScheme.primary,
              ),
            ).animate()
             .fadeIn(delay: 400.ms, duration: 800.ms)
             .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
             
             const SizedBox(height: 16),
             
             Text(
              "STAY IN GRAVITY",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ).animate()
             .fadeIn(delay: 800.ms, duration: 800.ms),
          ],
        ),
      ),
    );
  }
}