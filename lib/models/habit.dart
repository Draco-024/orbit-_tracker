import 'dart:convert';

class Habit {
  final String id;
  final String name;
  final int iconCodePoint; 
  final String iconFontFamily; 
  final int colorValue; 
  final DateTime createdAt; 
  final int targetDays; 
  int totalFocusSeconds; // NEW: Tracks time spent in Deep Focus
  List<String> completedDays; 

  Habit({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.iconFontFamily,
    required this.colorValue,
    required this.createdAt,
    this.targetDays = 0, 
    this.totalFocusSeconds = 0, // Default to 0
    this.completedDays = const [],
  });

  int get currentStreak {
    if (completedDays.isEmpty) return 0;
    
    List<DateTime> dates = completedDays.map((d) => DateTime.parse(d)).toList();
    dates.sort((a, b) => b.compareTo(a)); 

    int streak = 0;
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime expectedDate = today;

    if (dates.any((d) => d.isAtSameMomentAs(today))) {
      // Keep expectedDate as today
    } else if (dates.any((d) => d.isAtSameMomentAs(today.subtract(const Duration(days: 1))))) {
      expectedDate = today.subtract(const Duration(days: 1));
    } else {
      return 0; 
    }

    for (DateTime d in dates) {
      if (d.isAtSameMomentAs(expectedDate)) {
        streak++;
        expectedDate = expectedDate.subtract(const Duration(days: 1));
      } else if (d.isBefore(expectedDate)) {
        break; 
      }
    }
    return streak;
  }

  bool isCompletedOn(DateTime date) {
    String dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return completedDays.contains(dateStr);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'targetDays': targetDays,
      'totalFocusSeconds': totalFocusSeconds, // Save focus time
      'completedDays': completedDays,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      name: map['name'],
      iconCodePoint: map['iconCodePoint'],
      iconFontFamily: map['iconFontFamily'] ?? 'MaterialIcons',
      colorValue: map['colorValue'] ?? 0xFF00F2FE, 
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      targetDays: map['targetDays'] ?? 0, 
      totalFocusSeconds: map['totalFocusSeconds'] ?? 0, // Load focus time
      completedDays: List<String>.from(map['completedDays'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());
  factory Habit.fromJson(String source) => Habit.fromMap(json.decode(source));
}