import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // NEW IMPORT
import 'screens/splash_screen.dart'; 
import 'services/notification_service.dart';

// Global Notifier for the entire app
final ValueNotifier<int> accentPaletteNotifier = ValueNotifier(0); 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  
  // NEW: Forces the screen to NEVER turn off while the app is in the foreground
  WakelockPlus.enable();
  
  // PRE-LOAD THEME: Ensures the Splash Screen instantly knows what color to be!
  final prefs = await SharedPreferences.getInstance();
  accentPaletteNotifier.value = prefs.getInt('orbit_theme_palette') ?? 0;
  
  runApp(const OrbitApp());
}

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: accentPaletteNotifier,
      builder: (_, paletteIndex, __) {
        return MaterialApp(
          title: 'Orbit',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(paletteIndex),
          home: const SplashScreen(), // App boots into the Splash Screen
        );
      },
    );
  }

  ThemeData _buildTheme(int index) {
    final bool isLight = index == 1; // Solar Morning
    final Color bg = isLight ? const Color(0xFFFBFBFE) : (index == 2 ? const Color(0xFF0A1210) : const Color(0xFF09090B));
    final Color surface = isLight ? Colors.white : const Color(0xFF141417);
    final Color primaryText = isLight ? const Color(0xFF1A1C1E) : Colors.white;
    final Color secondary = index == 1 ? const Color(0xFF007AFF) : (index == 2 ? const Color(0xFF50C878) : const Color(0xFF00F2FE));

    return ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: secondary,
        brightness: isLight ? Brightness.light : Brightness.dark,
        surface: surface,
        primary: primaryText,
        secondary: secondary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: isLight ? Brightness.light : Brightness.dark).textTheme,
      ),
    );
  }
}