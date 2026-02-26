import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/habit.dart';

class EditHabitScreen extends StatefulWidget {
  final Habit habit;
  final Function(Habit) onSave;
  final VoidCallback onDelete;

  const EditHabitScreen({
    super.key,
    required this.habit,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends State<EditHabitScreen> {
  late TextEditingController _nameController;
  late int _selectedIconCode;
  late int _selectedColorIndex;
  late int _targetDays;
  
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit.name);
    _selectedIconCode = widget.habit.iconCodePoint;
    _targetDays = widget.habit.targetDays;
    
    _selectedColorIndex = _colors.indexWhere((c) => c.value == widget.habit.colorValue);
    if (_selectedColorIndex == -1) _selectedColorIndex = 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;

    final updatedHabit = Habit(
      id: widget.habit.id,
      name: _nameController.text.trim(),
      iconCodePoint: _selectedIconCode,
      iconFontFamily: 'MaterialIcons',
      colorValue: _colors[_selectedColorIndex].value, 
      createdAt: widget.habit.createdAt, 
      targetDays: _targetDays,
      completedDays: widget.habit.completedDays,
    );

    widget.onSave(updatedHabit);
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

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("Edit Routine", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [IconButton(icon: Icon(Icons.check_rounded, color: activeColor), onPressed: _save)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Routine Name", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                cursorColor: activeColor,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: activeColor.withValues(alpha: 0.5), width: 1)),
                ),
              ),
              const SizedBox(height: 32),

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
              const SizedBox(height: 32),
              
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

              const Text("Icon", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: _icons.length,
                  itemBuilder: (context, index) {
                    final icon = _icons[index];
                    final isSelected = icon.codePoint == _selectedIconCode;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconCode = icon.codePoint),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? activeColor : Colors.transparent, width: 2),
                        ),
                        child: Icon(icon, color: isSelected ? activeColor : Colors.white54, size: 28),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onDelete();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  label: const Text("Delete Routine", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.1), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}