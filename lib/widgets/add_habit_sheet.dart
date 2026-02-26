import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/habit.dart';

class AddHabitSheet extends StatefulWidget {
  final Function(Habit) onAdd;

  const AddHabitSheet({super.key, required this.onAdd});

  @override
  State<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<AddHabitSheet> {
  final TextEditingController _nameController = TextEditingController();
  
  final List<IconData> _icons = [
    Icons.auto_awesome_rounded, Icons.menu_book_rounded, Icons.fitness_center_rounded,
    Icons.directions_run_rounded, Icons.water_drop_rounded, Icons.self_improvement_rounded,
    Icons.edit_document, Icons.video_library_rounded, Icons.analytics_rounded,
    Icons.code_rounded, Icons.spa_rounded, Icons.palette_rounded,
  ];

  final List<Color> _colors = [
    const Color(0xFF00F2FE), const Color(0xFFB388FF), const Color(0xFFFF8A80), 
    const Color(0xFF69F0AE), const Color(0xFFFFD180), const Color(0xFFEA80FC),
  ];
  
  int _selectedIconIndex = 0;
  int _selectedColorIndex = 0;
  int _targetDays = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) return;

    final newHabit = Habit(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      iconCodePoint: _icons[_selectedIconIndex].codePoint,
      iconFontFamily: _icons[_selectedIconIndex].fontFamily ?? 'MaterialIcons',
      colorValue: _colors[_selectedColorIndex].value, 
      createdAt: DateTime.now(), 
      targetDays: _targetDays,
      completedDays: [],
    );

    widget.onAdd(newHabit);
    Navigator.pop(context);
  }

  Widget _buildDurationChip(String label, int days) {
    bool isSelected = _targetDays == days;
    final activeColor = _colors[_selectedColorIndex];
    
    return GestureDetector(
      onTap: () => setState(() => _targetDays = days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : Colors.transparent, width: 1.5),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? activeColor : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _colors[_selectedColorIndex];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 32, top: 32, left: 24, right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF09090B).withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 32),
            const Text("New Routine", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
            const SizedBox(height: 24),
            
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
              cursorColor: activeColor,
              decoration: InputDecoration(
                hintText: "e.g., Morning Run...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: activeColor.withValues(alpha: 0.5), width: 1)),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text("Goal Duration", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDurationChip("Forever", 0),
                _buildDurationChip("7 Days", 7),
                _buildDurationChip("21 Days", 21),
                _buildDurationChip("30 Days", 30),
              ],
            ),
            const SizedBox(height: 24),

            const Text("Select Icon", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _icons.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIconIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIconIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12),
                      width: 60,
                      decoration: BoxDecoration(
                        color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? activeColor : Colors.white10, width: isSelected ? 2 : 1),
                      ),
                      child: Icon(_icons[index], color: isSelected ? activeColor : Colors.white54),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            const Text("Aura Color", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedColorIndex == index;
                  final color = _colors[index];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 16),
                      width: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isSelected ? 1.0 : 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                        boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1)] : [],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(backgroundColor: activeColor, foregroundColor: const Color(0xFF0A0A0C), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Create Routine", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}