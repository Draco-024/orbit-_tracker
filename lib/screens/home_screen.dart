import 'dart:ui';
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../widgets/add_habit_sheet.dart';
import 'edit_habit_screen.dart';
import 'focus_mode_screen.dart'; 
import '../services/timer_service.dart';
import '../services/notification_service.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Habit> habits = [];
  Map<String, String> _journals = {};
  final TextEditingController _journalController = TextEditingController();
  final FocusNode _journalFocusNode = FocusNode();

  bool isLoading = true;
  late ConfettiController _confettiController;
  final ScrollController _timelineController = ScrollController();
  
  DateTime _selectedDate = _stripTime(DateTime.now());
  bool _isSelectionMode = false;
  final Set<String> _selectedHabitIds = {};

  static DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    _loadData().then((_) {
      TimerService().restoreState(habits);
    });
    
    NotificationService().requestPermission().then((allowed) {
      if (allowed) _updateSmartReminder();
    });

    _journalFocusNode.addListener(() {
      setState(() {});
    });

    _journalController.addListener(() {
      _saveJournal(_journalController.text);
      if (_journalController.text.length <= 1) setState(() {}); 
    });

    TimerService().onTimerComplete = (habit, elapsedSeconds, isGhost) {
      _handleTimerComplete(habit, elapsedSeconds, isGhost);
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    _timelineController.dispose();
    _journalController.dispose();
    _journalFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TimerService().syncBackgroundTime();
      setState(() {}); 
    } 
  }

  void _updateSmartReminder() {
    final today = _stripTime(DateTime.now());
    final todaysHabits = habits.where((h) => _stripTime(h.createdAt).compareTo(today) <= 0).toList();
    
    bool allDone = false;
    if (todaysHabits.isNotEmpty) {
      allDone = todaysHabits.every((h) => h.isCompletedOn(today));
    }
    
    NotificationService().updateSmartDailyReminder(allDone);
  }

  void _handleTimerComplete(Habit habit, int elapsedSeconds, bool isGhost) async {
    bool newlyCompleted = false;
    int index = habits.indexWhere((h) => h.id == habit.id);
    
    if (index != -1) {
      habits[index].totalFocusSeconds += elapsedSeconds;
      final now = DateTime.now();
      final actualTodayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      if (!habits[index].completedDays.contains(actualTodayString)) {
        habits[index].completedDays.add(actualTodayString);
        newlyCompleted = true;
      }
    }
    
    await _saveHabits();
    _updateSmartReminder(); 

    if (mounted) {
      setState(() {
        if (newlyCompleted && !isGhost) _checkCelebration();
      });
    }

    if (isGhost) return;
    if (!mounted || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return; 

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        try {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Target Reached: ${habit.name}!"),
              backgroundColor: Color(habit.colorValue),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        } catch (_) {}
      }
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedHabits = prefs.getStringList('orbit_habits');
    final String? storedJournals = prefs.getString('orbit_journals');

    if (storedHabits != null) habits = storedHabits.map((h) => Habit.fromJson(h)).toList();
    if (storedJournals != null) _journals = Map<String, String>.from(json.decode(storedJournals));
    
    _updateJournalTextField();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _saveHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encodedHabits = habits.map((h) => h.toJson()).toList();
    await prefs.setStringList('orbit_habits', encodedHabits);
  }

  Future<void> _saveJournal(String text) async {
    final dateString = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    _journals[dateString] = text;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('orbit_journals', json.encode(_journals));
  }

  void _updateJournalTextField() {
    final dateString = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    _journalController.text = _journals[dateString] ?? "";
  }

  void toggleHabit(Habit habit) async {
    if (_isSelectionMode) {
      HapticFeedback.selectionClick();
      setState(() {
        if (_selectedHabitIds.contains(habit.id)) _selectedHabitIds.remove(habit.id);
        else _selectedHabitIds.add(habit.id);
      });
      return;
    }

    HapticFeedback.lightImpact();
    final dateString = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    setState(() {
      if (habit.completedDays.contains(dateString)) habit.completedDays.remove(dateString); 
      else habit.completedDays.add(dateString); 
    });
    
    await _saveHabits();
    _checkCelebration();
    _updateSmartReminder(); 
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedHabitIds.clear();
    });
    HapticFeedback.selectionClick();
  }

  void _deleteSelectedHabits() async {
    if (_selectedHabitIds.isEmpty) {
      _toggleSelectionMode();
      return;
    }
    setState(() {
      habits.removeWhere((h) => _selectedHabitIds.contains(h.id));
      _selectedHabitIds.clear();
      _isSelectionMode = false;
    });
    await _saveHabits();
    _updateSmartReminder(); 
    HapticFeedback.heavyImpact();
  }

  void _checkCelebration() {
    bool isViewingToday = _selectedDate.isAtSameMomentAs(_stripTime(DateTime.now()));
    final visibleHabits = _getVisibleHabits();
    if (isViewingToday && visibleHabits.isNotEmpty && visibleHabits.every((h) => h.isCompletedOn(_selectedDate))) {
      _confettiController.play();
    }
  }

  void _showAddHabitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddHabitSheet(
        onAdd: (newHabit) async {
          setState(() => habits.add(newHabit));
          await _saveHabits();
          _updateSmartReminder(); 
        },
      ),
    );
  }

  void _editHabit(Habit habit) async {
    if (_isSelectionMode) return; 
    int index = habits.indexWhere((h) => h.id == habit.id);
    if (index == -1) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditHabitScreen(
          habit: habits[index],
          onSave: (updatedHabit) async {
            setState(() => habits[index] = updatedHabit);
            await _saveHabits();
            _updateSmartReminder(); 
          },
          onDelete: () async {
            setState(() => habits.removeAt(index));
            await _saveHabits();
            _updateSmartReminder(); 
          },
        ),
      ),
    );
  }

  void _openFocusMode(Habit habit) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => FocusModeScreen(habit: habit)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: Theme.of(context).colorScheme.secondary, surface: const Color(0xFF141417)),
            dialogBackgroundColor: const Color(0xFF09090B),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedDate = _stripTime(picked);
        _updateJournalTextField();
      });
      _scrollToDate(picked);
    }
  }

  void _scrollToDate(DateTime targetDate) {
    final daysAgo = _stripTime(DateTime.now()).difference(_stripTime(targetDate)).inDays;
    final targetOffset = daysAgo * 64.0;
    _timelineController.animateTo(targetOffset, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
  }

  List<Habit> _getVisibleHabits() {
    return habits.where((h) {
      final createdDate = _stripTime(h.createdAt);
      return createdDate.compareTo(_selectedDate) <= 0;
    }).toList();
  }

  void _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final visibleHabits = _getVisibleHabits();
      final oldGlobalIndex = habits.indexOf(visibleHabits[oldIndex]);
      final newGlobalIndex = habits.indexOf(visibleHabits[newIndex]);
      final item = habits.removeAt(oldGlobalIndex);
      habits.insert(newGlobalIndex, item);
    });
    await _saveHabits();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final now = _stripTime(DateTime.now());
    bool isViewingPast = !_selectedDate.isAtSameMomentAs(now);
    
    final isLight = Theme.of(context).brightness == Brightness.light;
    final Color bgColor = isLight ? const Color(0xFFF8F9FA) : const Color(0xFF09090B);
    final Color textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final Color mutedTextColor = isLight ? Colors.black54 : Colors.white54;
    final Color cardColor = isLight ? Colors.white : const Color(0xFF141417);
    final Color borderColor = isLight ? Colors.black12 : Colors.white10;
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    if (isLoading) return Scaffold(backgroundColor: bgColor, body: Center(child: CircularProgressIndicator(color: accentColor)));
    final visibleHabits = _getVisibleHabits();

    bool isJournalActive = _journalFocusNode.hasFocus || _journalController.text.isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), 
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            Positioned(
              top: -100, right: -100,
              child: AnimatedContainer(duration: const Duration(milliseconds: 700), width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isViewingPast ? Colors.purple.withValues(alpha: 0.08) : accentColor.withValues(alpha: 0.08))).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 4.seconds),
            ),
            Positioned(
              bottom: 100, left: -150,
              child: AnimatedContainer(duration: const Duration(milliseconds: 700), width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: isViewingPast ? Colors.indigo.withValues(alpha: 0.05) : accentColor.withValues(alpha: 0.05))).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 5.seconds),
            ),
            BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(_isSelectionMode ? "Select Routines" : (isViewingPast ? "Time Travel Mode" : "Today's Orbit"), key: ValueKey("$_isSelectionMode-$isViewingPast"), style: TextStyle(color: _isSelectionMode ? Colors.redAccent.withValues(alpha: 0.8) : (isViewingPast ? Colors.purpleAccent.withValues(alpha: 0.8) : mutedTextColor), fontSize: 14, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation), child: child)),
                              child: Text(_isSelectionMode ? "${_selectedHabitIds.length} Selected" : DateFormat('EEEE, MMM d').format(_selectedDate), key: ValueKey("$_isSelectionMode-$_selectedDate-${_selectedHabitIds.length}"), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: textColor)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(icon: Icon(_isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded, color: _isSelectionMode ? textColor : mutedTextColor, size: 28), onPressed: _toggleSelectionMode),
                            if (!_isSelectionMode) IconButton(icon: Icon(Icons.calendar_month_rounded, color: textColor, size: 28), onPressed: _pickDate),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 85,
                      child: ListView.builder(
                        controller: _timelineController, scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), reverse: true, itemCount: 365, 
                        itemBuilder: (context, index) {
                          final date = now.subtract(Duration(days: index));
                          final isSelected = date.isAtSameMomentAs(_selectedDate);
                          final isToday = date.isAtSameMomentAs(now);
                          return GestureDetector(
                            onTap: () {
                              if (_isSelectionMode) return;
                              HapticFeedback.selectionClick();
                              setState(() { _selectedDate = date; _updateJournalTextField(); });
                              _scrollToDate(date);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300), width: 52, margin: EdgeInsets.only(left: 12, right: index == 0 ? 0 : 0),
                              decoration: BoxDecoration(color: isSelected ? accentColor : cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? accentColor : borderColor, width: isSelected ? 1.5 : 1)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(DateFormat('E').format(date).substring(0, 1), style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : mutedTextColor, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(date.day.toString(), style: TextStyle(fontSize: 16, color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold)),
                                  if (isToday && !isSelected) Container(margin: const EdgeInsets.only(top: 4), width: 4, height: 4, decoration: BoxDecoration(color: mutedTextColor, shape: BoxShape.circle))
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 24),
                    
                    // --- LUXURIOUS ORBITING CAPTAIN'S LOG ---
                    SizedBox(
                      height: isJournalActive ? 120 : 64, // Extends height when active
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // 1. The Orbiting Glowing Dot
                          // This sits behind the solid pill, revealing only its neon aura around the edges
                          SizedBox(
                            width: MediaQuery.of(context).size.width - 20, 
                            height: 180, // Wide track so it sweeps smoothly along the pill borders
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 12, spreadRadius: 4),
                                    BoxShadow(color: accentColor.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 8),
                                  ],
                                ),
                              ),
                            ),
                          ).animate(onPlay: (c) => c.repeat()).rotate(duration: 4.seconds, curve: Curves.linear),

                          // 2. The Solid Pill Container (Hides the track, reveals the glow)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            height: isJournalActive ? 120 : 64,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              // Solid color blocks the dot from showing through the center
                              color: isLight ? Colors.white : const Color(0xFF141417), 
                              borderRadius: BorderRadius.circular(isJournalActive ? 28 : 100), 
                              border: Border.all(
                                color: isJournalActive ? accentColor.withValues(alpha: 0.6) : borderColor,
                                width: isJournalActive ? 1.5 : 1
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isJournalActive) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.auto_awesome_rounded, size: 16, color: accentColor),
                                      const SizedBox(width: 8),
                                      Text("CAPTAIN'S LOG", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: accentColor)),
                                    ],
                                  ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1),
                                  const SizedBox(height: 12),
                                ],
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center, // PERFECT VERTICAL CENTER
                                  children: [
                                    if (!isJournalActive)
                                      Icon(Icons.edit_note_rounded, color: mutedTextColor, size: 22).animate().scale(),
                                    if (!isJournalActive)
                                      const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _journalController, 
                                        focusNode: _journalFocusNode, 
                                        maxLines: isJournalActive ? null : 1, 
                                        minLines: isJournalActive ? 3 : 1, 
                                        textInputAction: TextInputAction.done,
                                        textAlignVertical: TextAlignVertical.center, // CRUCIAL FOR CENTERING
                                        style: TextStyle(
                                          color: textColor, 
                                          fontSize: 15, 
                                          fontWeight: FontWeight.w700, // BOLD TEXT
                                          height: 1.5
                                        ), 
                                        cursorColor: accentColor,
                                        decoration: InputDecoration(
                                          isDense: true, // REMOVES INTERNAL HIDDEN PADDING
                                          contentPadding: EdgeInsets.zero, // STRIPS MARGINS
                                          hintText: isJournalActive ? "Reflect on your progress today..." : "Captain's Log...", 
                                          hintStyle: TextStyle(color: mutedTextColor.withValues(alpha: 0.6), fontSize: 14, fontWeight: FontWeight.w500), 
                                          border: InputBorder.none, 
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                    // --- END CAPTAIN'S LOG ---

                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Your Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                        if (!isViewingPast && !_isSelectionMode)
                          GestureDetector(
                            onTap: _showAddHabitSheet,
                            child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.add_rounded, color: accentColor, size: 24)),
                          ).animate().scale(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: AnimatedBuilder(
                        animation: TimerService(),
                        builder: (context, child) {
                          if (visibleHabits.isEmpty) return _buildEmptyState(textColor, mutedTextColor);
                          return ReorderableListView.builder(
                            physics: const BouncingScrollPhysics(), padding: const EdgeInsets.only(bottom: 120), itemCount: visibleHabits.length, buildDefaultDragHandles: false, onReorder: _onReorder,
                            itemBuilder: (context, index) {
                              final habit = visibleHabits[index];
                              return Container(
                                key: ValueKey(habit.id),
                                child: PremiumHabitCard(
                                  habit: habit, index: index, selectedDate: _selectedDate, isSelectionMode: _isSelectionMode, isSelectedForDeletion: _selectedHabitIds.contains(habit.id), isLight: isLight, cardColor: cardColor, textColor: textColor, mutedTextColor: mutedTextColor, borderColor: borderColor,
                                  onToggle: () => toggleHabit(habit), onLongPress: () => _editHabit(habit), onFocusTap: () => _openFocusMode(habit), 
                                ).animate().fadeIn(delay: Duration(milliseconds: 20 * index)).slideX(begin: 0.05),
                              );
                            },
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSelectionMode && _selectedHabitIds.isNotEmpty)
              Positioned(
                bottom: 100, left: 24, right: 24,
                child: GestureDetector(
                  onTap: _deleteSelectedHabits,
                  child: Container(
                    height: 60, decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 5))]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text("Delete ${_selectedHabitIds.length} Routines", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutBack),
              )
            else if (isViewingPast && !_isSelectionMode)
              Positioned(
                bottom: 100, right: 24,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() { _selectedDate = now; _updateJournalTextField(); });
                    _scrollToDate(now);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))]),
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, color: bgColor, size: 18),
                        const SizedBox(width: 8),
                        Text("Back to Today", style: TextStyle(color: bgColor, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutBack),
              ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(confettiController: _confettiController, blastDirectionality: BlastDirectionality.explosive, shouldLoop: false, colors: [accentColor, const Color(0xFFE2DFD2), textColor]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color mutedTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.all_inclusive_rounded, size: 64, color: mutedTextColor.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          Text("Space is empty here.\nReturn to today to add routines.", textAlign: TextAlign.center, style: TextStyle(color: mutedTextColor, fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}

class PremiumHabitCard extends StatelessWidget {
  final Habit habit;
  final int index;
  final DateTime selectedDate;
  final bool isSelectionMode;
  final bool isSelectedForDeletion;
  final bool isLight;
  final Color cardColor;
  final Color textColor;
  final Color mutedTextColor;
  final Color borderColor;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final VoidCallback onFocusTap;

  const PremiumHabitCard({
    super.key, required this.habit, required this.index, required this.selectedDate,
    required this.isLight, required this.cardColor, required this.textColor, required this.mutedTextColor, required this.borderColor,
    this.isSelectionMode = false, this.isSelectedForDeletion = false,
    required this.onToggle, required this.onLongPress, required this.onFocusTap, 
  });

  @override
  Widget build(BuildContext context) {
    bool isDone = habit.isCompletedOn(selectedDate);
    final dynamicColor = Color(habit.colorValue); 
    final double opacity = (isSelectionMode && !isSelectedForDeletion) ? 0.4 : 1.0;

    final timerService = TimerService();
    final isActiveTimer = timerService.activeHabit?.id == habit.id && (timerService.isRunning || timerService.isPaused);
    final m = timerService.currentSeconds ~/ 60;
    final s = timerService.currentSeconds % 60;
    final timeString = "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";

    return GestureDetector(
      behavior: HitTestBehavior.opaque, onTap: onToggle,
      onLongPress: () { HapticFeedback.mediumImpact(); onLongPress(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelectedForDeletion ? Colors.redAccent.withValues(alpha: 0.1) : (isDone && !isSelectionMode ? dynamicColor.withValues(alpha: 0.1) : cardColor),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isActiveTimer ? dynamicColor.withValues(alpha: 0.8) : (isSelectedForDeletion ? Colors.redAccent.withValues(alpha: 0.5) : (isDone && !isSelectionMode ? dynamicColor.withValues(alpha: 0.3) : borderColor)), 
            width: (isSelectedForDeletion || isActiveTimer) ? 1.5 : 1
          ),
          boxShadow: isActiveTimer ? [BoxShadow(color: dynamicColor.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: -5)] : [],
        ),
        child: Opacity(
          opacity: opacity,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: isSelectedForDeletion ? Colors.redAccent.withValues(alpha: 0.2) : (isDone && !isSelectionMode ? dynamicColor.withValues(alpha: 0.2) : (isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.03))), shape: BoxShape.circle),
                child: Icon(IconData(habit.iconCodePoint, fontFamily: habit.iconFontFamily), color: isSelectedForDeletion ? Colors.redAccent : (isDone && !isSelectionMode ? dynamicColor : mutedTextColor), size: 24),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: (isDone || isSelectedForDeletion) ? FontWeight.w700 : FontWeight.w600, letterSpacing: -0.3, decoration: isDone ? TextDecoration.lineThrough : null, color: isSelectedForDeletion ? Colors.redAccent : (isDone && !isSelectionMode ? mutedTextColor : textColor)),
                      child: Text(habit.name),
                    ),
                    const SizedBox(height: 6),
                    if (isActiveTimer)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: dynamicColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 12, color: dynamicColor).animate(onPlay: (c) => timerService.isRunning ? c.repeat(reverse: true) : null).fadeOut(duration: 1.seconds),
                            const SizedBox(width: 4),
                            Text(timeString, style: TextStyle(fontSize: 12, color: dynamicColor, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()])),
                          ],
                        )
                      )
                    else
                      Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded, size: 14, color: habit.currentStreak > 0 ? (isDone ? dynamicColor.withValues(alpha: 0.5) : (isLight ? Colors.black38 : const Color(0xFFE2DFD2))) : mutedTextColor.withValues(alpha: 0.3)),
                          const SizedBox(width: 6),
                          Text(habit.targetDays > 0 ? "${habit.completedDays.length}/${habit.targetDays}" : "${habit.currentStreak} Day Streak", style: TextStyle(fontSize: 13, color: mutedTextColor, fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
              ),
              if (isSelectionMode)
                AnimatedContainer(duration: const Duration(milliseconds: 300), width: 28, height: 28, decoration: BoxDecoration(color: isSelectedForDeletion ? Colors.redAccent : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: isSelectedForDeletion ? Colors.redAccent : borderColor, width: 2)), child: isSelectedForDeletion ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null)
              else ...[
                if (!isDone) ...[
                  GestureDetector(
                    onTap: onFocusTap,
                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, color: isActiveTimer ? dynamicColor.withValues(alpha: 0.2) : (isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.05))), child: Icon(isActiveTimer ? Icons.zoom_out_map_rounded : Icons.timer_outlined, size: 18, color: isActiveTimer ? dynamicColor : mutedTextColor)),
                  ),
                  const SizedBox(width: 12),
                ],
                SizedBox(
                  width: 32, height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(duration: const Duration(milliseconds: 300), width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isDone ? dynamicColor.withValues(alpha: 0.4) : borderColor, width: 2))),
                      AnimatedScale(scale: isDone ? 1.0 : 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack, child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: dynamicColor))),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ReorderableDragStartListener(index: index, child: Icon(Icons.drag_indicator_rounded, color: borderColor, size: 24)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}