import 'package:flutter/material.dart';
import 'widgets/bauhaus_button.dart';
import 'task_model.dart';

enum SessionKind { work, shortBreak, longBreak }
enum CatState { idle, working, resting }

class TimerScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const TimerScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // ===== TIMER STATE =====
  SessionKind _sessionKind = SessionKind.work;
  int _workMinutes = 25;
  int _breakMinutes = 5;
  bool _isRunning = false;
  Duration _remaining = const Duration(minutes: 25);
  CatState _catState = CatState.idle;

  // ===== TASKS =====
  final TextEditingController _taskController = TextEditingController();
  final List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _remaining = Duration(minutes: _workMinutes);
  }

  // ---------- TIME FORMAT ----------
  String get _formattedTime {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  // ---------- UI HELPERS ----------
  String get catImage {
    switch (_catState) {
      case CatState.working:
        return 'assets/images/cat_working.png';
      case CatState.resting:
        return 'assets/images/cat_resting.png';
      default:
        return 'assets/images/cat_idle.png';
    }
  }

  void _setSession(SessionKind kind) {
    if (_isRunning) return;

    setState(() {
      _sessionKind = kind;

      if (kind == SessionKind.work) {
        _remaining = Duration(minutes: _workMinutes);
        _catState = CatState.idle;
      } else {
        _remaining = Duration(minutes: _breakMinutes);
        _catState = CatState.resting;
      }
    });
  }

  void _selectWork(int m) {
    if (_isRunning) return;
    setState(() {
      _workMinutes = m;
      if (_sessionKind == SessionKind.work) {
        _remaining = Duration(minutes: _workMinutes);
      }
    });
  }

  void _selectBreak(int m) {
    if (_isRunning) return;
    setState(() {
      _breakMinutes = m;
      if (_sessionKind != SessionKind.work) {
        _remaining = Duration(minutes: _breakMinutes);
      }
    });
  }

  // ---------- CONTROLS ----------
  void _start() {
    setState(() {
      _isRunning = true;
      _catState =
          _sessionKind == SessionKind.work ? CatState.working : CatState.resting;
    });
  }

  void _pause() {
    setState(() {
      _isRunning = false;
      _catState =
          _sessionKind == SessionKind.work ? CatState.idle : CatState.resting;
    });
  }

  void _reset() {
    setState(() {
      _isRunning = false;
      _catState = _sessionKind == SessionKind.work
          ? CatState.idle
          : CatState.resting;
      _remaining = Duration(
        minutes: _sessionKind == SessionKind.work ? _workMinutes : _breakMinutes,
      );
    });
  }

  // ---------- TASK LOGIC ----------
  void _addTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tasks.add(Task(title: text));
      _taskController.clear();
    });
  }

  void _removeTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tomato Cat Pomodoro"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Image.asset(
              "assets/images/settings_button.png",
              width: 28,
              height: 28,
            ),
            onPressed: () {},
          ),
        ],
      ),

      // ===================== BODY =====================
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== TOP TIMER AREA =====
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Row(
                    children: [
                      Image.asset(catImage, width: 70),
                      const SizedBox(width: 12),

                      // TIMER PILL
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: Colors.black, width: 3),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "TIMER",
                                style: TextStyle(
                                    letterSpacing: 4,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    ),
                                    
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formattedTime,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),
                      Image.asset(catImage, width: 70),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // CIRCLE BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BauhausCircleButton(
                        icon: Icons.refresh,
                        label: "Reset",
                        onPressed: _reset,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 16),
                      BauhausCircleButton(
                        icon: Icons.play_arrow,
                        label: "Start",
                        onPressed: _isRunning ? null : _start,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 16),
                      BauhausCircleButton(
                        icon: Icons.pause,
                        label: "Pause",
                        onPressed: _isRunning ? _pause : null,
                        color: Colors.orange.shade700,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(thickness: 2),

            // ===== TASK AREA =====
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tasks",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 2,
                      
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ADD TASK ROW
                  Row(
                    children: [
                      InkWell(
                        onTap: _addTask,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _taskController,
                            decoration: const InputDecoration(
                              hintText: "Type task here",
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _addTask(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // TASK LIST
                  Expanded(
                    child: ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: task.completed,
                                onChanged: (v) {
                                  setState(() => task.completed = v ?? false);
                                },
                              ),
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                        color: Colors.black, width: 2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    task.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      decoration: task.completed
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline_outlined),
                                onPressed: () => _removeTask(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
