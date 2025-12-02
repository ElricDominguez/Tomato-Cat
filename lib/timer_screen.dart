import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'widgets/bauhaus_button.dart';
import 'task_model.dart';

enum SessionKind { work, shortBreak, longBreak }
enum CatState { idle, working, resting }
enum TimerStatus { idle, running, paused }

class _BackgroundOption {
  final String key;
  final String label;
  final Color? color;
  final String? asset;

  const _BackgroundOption({
    required this.key,
    required this.label,
    this.color,
    this.asset,
  });
}

const List<_BackgroundOption> _backgroundOptions = [
  _BackgroundOption(
    key: 'pusheen',
    label: 'Pusheen',
    asset: 'assets/images/pusheen.jpg',
  ),
  _BackgroundOption(
    key: 'darkPusheen',
    label: 'Dark Pusheen',
    asset: 'assets/images/darkPusheen.jpg',
  ),
];

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

  Duration _remaining = const Duration(minutes: 25);
  CatState _catState = CatState.idle;
  TimerStatus _timerStatus = TimerStatus.idle;
  Timer? _timer;
  String _backgroundKey = 'pusheen';
  bool _muted = false;

  // ===== AUDIO PLAYERS =====
  final AudioPlayer _alertPlayer = AudioPlayer();      // 16 / 8 / 3 min marks
  final AudioPlayer _countdownPlayer = AudioPlayer();  // single beep at 5 sec to make illusion of starting at 3. . .its weird, someone edit this pls
  final AudioPlayer _endPlayer = AudioPlayer();        // session finished

  // ===== TASKS =====
  final TextEditingController _taskController = TextEditingController();
  final List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _remaining = Duration(minutes: _workMinutes);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taskController.dispose();
    _alertPlayer.dispose();
    _countdownPlayer.dispose();
    _endPlayer.dispose();
    super.dispose();
  }

  _BackgroundOption get _selectedBackground {
    return _backgroundOptions.firstWhere(
      (option) => option.key == _backgroundKey,
      orElse: () => _backgroundOptions.first,
    );
  }

  BoxDecoration _backgroundDecoration() {
    final option = _selectedBackground;
    if (option.asset != null) {
      return BoxDecoration(
        image: DecorationImage(
          image: AssetImage(option.asset!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.05),
            BlendMode.srcATop,
          ),
        ),
      );
    }

    return BoxDecoration(
      color: option.color ?? Theme.of(context).scaffoldBackgroundColor,
    );
  }

  Color? get _contentOverlayColor {
    switch (_selectedBackground.key) {
      case 'pusheen':
        return Colors.black.withOpacity(0.10);
      case 'darkPusheen':
        return Colors.white.withOpacity(0.10);
      default:
        return null;
    }
  }

  // ---------- TIME FORMAT ----------
  String get _formattedTime {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  String _formatDuration(Duration duration) {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  String get _breakTimerText {
    final duration = _sessionKind == SessionKind.work
        ? Duration(minutes: _breakMinutes) // upcoming break
        : Duration(minutes: _workMinutes); // upcoming work
    return _formatDuration(duration);
  }

  String get _breakLabel {
    return _sessionKind == SessionKind.work ? "Upcoming break" : "Upcoming work";
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

  // ---------- AUDIO HELPERS ----------
  Future<void> _playAlert() async {
    if (_muted) return;
    await _alertPlayer.play(AssetSource('sounds/meow.mp3'));
  }

  Future<void> _playCountdown() async {
    if (_muted) return;
    await _countdownPlayer.play(AssetSource('sounds/countdown.mp3'));
  }

  Future<void> _playSessionEnd() async {
    if (_muted) return;
    await _endPlayer.play(AssetSource('sounds/meowmine.mp3'));
  }

  // ---------- SESSION / DURATION ----------
  void _setSession(SessionKind kind) {
    if (_timerStatus == TimerStatus.running) return;

    _timer?.cancel();
    setState(() {
      _sessionKind = kind;
      _timerStatus = TimerStatus.idle;

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
    if (_timerStatus == TimerStatus.running) return;
    setState(() {
      _workMinutes = m;
      if (_sessionKind == SessionKind.work) {
        _remaining = Duration(minutes: _workMinutes);
      }
    });
  }

  void _selectBreak(int m) {
    if (_timerStatus == TimerStatus.running) return;
    setState(() {
      _breakMinutes = m;
      if (_sessionKind != SessionKind.work) {
        _remaining = Duration(minutes: _breakMinutes);
      }
    });
  }

  // ---------- TIMER CONTROLS ----------
  void _start() {
  if (_timerStatus == TimerStatus.running) return;

  // If we’re at 0 from a previous run, reset to full duration first
  if (_remaining.inSeconds == 0) {
    _remaining = Duration(
      minutes: _sessionKind == SessionKind.work ? _workMinutes : _breakMinutes,
    );
  }

  _timer?.cancel();
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!mounted) return;

    setState(() {
      final currentSecs = _remaining.inSeconds;
      final next = currentSecs - 1;

      if (next < 0) {
        return; // safety guard
      }

      if (next == 0) {
        // We are finishing the current session on this tick
        _remaining = Duration.zero;
        _playSessionEnd();

        if (_sessionKind == SessionKind.work) {
          // WORK → automatically start BREAK
          _sessionKind = _breakMinutes == 5
              ? SessionKind.shortBreak
              : SessionKind.longBreak;
          _catState = CatState.resting;
          _remaining = Duration(minutes: _breakMinutes);
        } else {
          // BREAK → automatically start WORK
          _sessionKind = SessionKind.work;
          _catState = CatState.working;
          _remaining = Duration(minutes: _workMinutes);
        }

        // Notice: we DO NOT cancel the timer here.
        // It keeps running into the next session automatically.
      } else {
        // Normal countdown tick
        _remaining = Duration(seconds: next);
        final secs = _remaining.inSeconds;

        // Alerts at 16, 8, 3 minutes remaining (for both work & break)
        if (secs == 16 * 60 || secs == 8 * 60 || secs == 3 * 60) {
          _playAlert();
        }

        // Countdown sound for last few seconds of any session (single beep at 5s)
        if (secs == 5) {
          _playCountdown();
        }
      }
    });
  });

  setState(() {
    _timerStatus = TimerStatus.running;
    _catState = _sessionKind == SessionKind.work
        ? CatState.working
        : CatState.resting;
  });
}


  void _pause() {
    if (_timerStatus != TimerStatus.running) return;

    _timer?.cancel();
    setState(() {
      _timerStatus = TimerStatus.paused;
      _catState = _sessionKind == SessionKind.work
          ? CatState.idle
          : CatState.resting;
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _timerStatus = TimerStatus.idle;
      _remaining = Duration(
        minutes: _sessionKind == SessionKind.work ? _workMinutes : _breakMinutes,
      );
      _catState = _sessionKind == SessionKind.work
          ? CatState.idle
          : CatState.resting;
    });
  }

  void _skipToFiveSecondsBeforeAudioCue() {
    _timer?.cancel();
    setState(() {
      // Start 6s out so the next tick hits 5s, triggering any countdown sound,
      // and finishes at 0 for the end-of-session audio.
      _remaining = const Duration(seconds: 6);
      _timerStatus = TimerStatus.idle;
      _catState = _sessionKind == SessionKind.work
          ? CatState.working
          : CatState.resting;
    });
    _start();
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

  // ---------- SETTINGS BOTTOM SHEET ----------
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            void syncState(VoidCallback fn) {
              setState(fn);
              modalSetState(() {});
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Settings",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      "Work duration",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [25, 30, 40].map((m) {
                        final selected =
                            _sessionKind == SessionKind.work && _workMinutes == m;
                        return ChoiceChip(
                          label: Text('$m min work'),
                          selected: selected,
                          onSelected: (_) {
                            syncState(() {
                              _setSession(SessionKind.work);
                              _selectWork(m);
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      "Break duration",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [5, 10].map((m) {
                        final selected =
                            _sessionKind != SessionKind.work && _breakMinutes == m;
                        return ChoiceChip(
                          label: Text('$m min break'),
                          selected: selected,
                          onSelected: (_) {
                            syncState(() {
                              // Update break length without forcing the current session
                              // into a break when the user is working.
                              _selectBreak(m);
                              if (_sessionKind != SessionKind.work) {
                                _sessionKind = m == 5
                                    ? SessionKind.shortBreak
                                    : SessionKind.longBreak;
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      "Theme background",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _backgroundKey,
                      isExpanded: true,
                      items: _backgroundOptions.map((option) {
                        return DropdownMenuItem(
                          value: option.key,
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: option.color,
                                  borderRadius: BorderRadius.circular(6),
                                  image: option.asset != null
                                      ? DecorationImage(
                                          image: AssetImage(option.asset!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  border: Border.all(color: Colors.black12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(option.label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        syncState(() => _backgroundKey = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Mute sounds",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _muted,
                          onChanged: (v) => syncState(() => _muted = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tomato Cat Pomodoro"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.orangeAccent.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black87, width: 1.5),
                ),
              ),
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
              ),
              tooltip: "Settings",
              onPressed: _openSettings,
            ),
          ),
        ],
      ),

      body: Container(
        decoration: _backgroundDecoration(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: _contentOverlayColor != null
                      ? BoxDecoration(
                          color: _contentOverlayColor,
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // ===== TOP TIMER AREA =====
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                                      Text(
                                        _sessionKind == SessionKind.work ? "WORK" : "BREAK",
                                        style: const TextStyle(
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
                              Container(
                                width: 120,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.black87, width: 2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _breakLabel,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _breakTimerText,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                                child: Image.asset(catImage, width: 70),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // CIRCLE BUTTONS under the timer only
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
                                icon: _timerStatus == TimerStatus.running
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                label: _timerStatus == TimerStatus.running ? "Pause" : "Start",
                                onPressed: _timerStatus == TimerStatus.running ? _pause : _start,
                                color: _timerStatus == TimerStatus.running
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PopupMenuButton<String>(
                              tooltip: "Developer tools",
                              position: PopupMenuPosition.under,
                              onSelected: (value) {
                                switch (value) {
                                  case 'skip5':
                                    _skipToFiveSecondsBeforeAudioCue();
                                    break;
                                  case 'alert':
                                    _playAlert();
                                    break;
                                  case 'countdown':
                                    _playCountdown();
                                    break;
                                  case 'end':
                                    _playSessionEnd();
                                    break;
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'skip5',
                                  child: Text("Skip to 5s before audio"),
                                ),
                                PopupMenuItem(
                                  value: 'alert',
                                  child: Text("Test alert (meow)"),
                                ),
                                PopupMenuItem(
                                  value: 'countdown',
                                  child: Text("Test countdown"),
                                ),
                                PopupMenuItem(
                                  value: 'end',
                                  child: Text("Test end"),
                                ),
                              ],
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bug_report, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      "Dev",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                      const SizedBox(height: 16),
                      const Divider(thickness: 2),
                      const SizedBox(height: 8),

                      // ===== TASK AREA =====
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
                                style: const TextStyle(color: Colors.black87),
                                decoration: const InputDecoration(
                                  hintText: "Type task here",
                                  hintStyle: TextStyle(color: Colors.black54),
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
                      Builder(builder: (context) {
                        final unfinished = _tasks.where((t) => !t.completed).toList();
                        final finished = _tasks.where((t) => t.completed).toList();

                        Widget buildTaskRow(Task task) {
                          final sourceIndex = _tasks.indexOf(task);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: task.completed,
                                  onChanged: (v) {
                                    setState(() {
                                      task.completed = v ?? false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: task.completed
                                          ? const Color(0xFFE6E4E4) // darker for completed items
                                          : Colors.white,
                                      border:
                                          Border.all(color: Colors.black, width: 2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      task.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.black87,
                                        decoration: task.completed
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        decorationColor: Colors.black87,
                                        decorationStyle: TextDecorationStyle.solid,
                                        decorationThickness: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline_outlined,
                                  ),
                                  onPressed: () => _removeTask(sourceIndex),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (unfinished.isNotEmpty) ...[
                              const Text(
                                "To do",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: unfinished.length,
                                itemBuilder: (context, index) =>
                                    buildTaskRow(unfinished[index]),
                              ),
                              const SizedBox(height: 12),
                            ],
                            const Text(
                              "Done",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (finished.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  "Nothing completed yet.",
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: finished.length,
                                itemBuilder: (context, index) =>
                                    buildTaskRow(finished[index]),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
