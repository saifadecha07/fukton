import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'classroom.dart';
import 'content.dart';
import 'guide.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class PracticeController extends ChangeNotifier {
  final Store store;
  PracticeController(this.store) {
    final saved = store.prefs.getString('mode');
    mode = modes.firstWhere((m) => m.id == saved, orElse: () => modes.first);
    task = store.prefs.getString('study-task') ?? '';
    _resetTotal();
  }

  late Mode mode;
  int total = 0, remain = 0, runMs = 0, wander = 0;
  bool running = false;
  bool breathGuide = true;

  /// The one small study task written before starting.
  String task = '';

  /// A "just two minutes" start: when it runs out, ask before going on.
  bool tiny = false, askContinue = false;

  void setTask(String t) {
    task = t.trim();
    store.prefs.setString('study-task', task);
  }

  void startTiny() {
    if (started != null) return;
    tiny = true;
    total = remain = 2 * 60000;
    startPause();
  }

  /// Exam subject code the running study block counts toward.
  String? subject;
  bool _oneOff = false;

  /// Start a study block from elsewhere (exam prep). False if one is running.
  bool startStudy({required int minutes, required String task, String? subject}) {
    if (started != null) return false;
    setMode('study');
    setTask(task);
    this.subject = subject;
    _oneOff = true;
    total = remain = minutes * 60000;
    startPause();
    return true;
  }

  /// Carry on after the two minutes, for [m] more minutes.
  void continueStudy(int m) {
    tiny = false;
    askContinue = false;
    total += m * 60000;
    remain = m * 60000;
    startPause();
  }
  DateTime? started;
  DateTime? _endAt, _lastTick;
  Map<String, int> types = {};
  Timer? _timer;
  String? result;
  final _bell1 = AudioPlayer(), _bell2 = AudioPlayer();

  void _resetTotal() {
    final m = store.prefs.getInt('min-${mode.id}') ?? mode.def;
    total = remain = (mode.presets.contains(m) ? m : mode.def) * 60000;
  }

  void setMode(String id) {
    if (started != null) return;
    mode = modes.firstWhere((m) => m.id == id);
    store.prefs.setString('mode', id);
    result = null;
    _resetTotal();
    notifyListeners();
  }

  void setMinutes(int m) {
    if (started != null) return;
    store.prefs.setInt('min-${mode.id}', m);
    total = remain = m * 60000;
    notifyListeners();
  }

  void toggleBreath(bool v) {
    breathGuide = v;
    notifyListeners();
  }

  bool get breathing => running && ((mode.id == 'sit' && breathGuide) || (mode.id == 'study' && runMs < 60000));

  String get phase {
    if (started == null) return 'พร้อมเมื่อไหร่ แตะเริ่ม';
    if (!running) return 'หยุดไว้ชั่วขณะ';
    if (mode.id == 'move') {
      final i = (runMs ~/ 5000) % moveSteps.length;
      return '${thaiNum(i + 1)} · ${moveSteps[i]}';
    }
    if (breathing) return (runMs % 10000) < 4000 ? 'หายใจเข้า…' : 'ผ่อนลมออก…';
    return mode.id == 'study' ? 'ใจอยู่ตรงนี้' : 'รู้ลมเข้า รู้ลมออก';
  }

  /// 0..1 breath scale curve: in 4s, out 6s.
  double get breathScale {
    final v = (runMs % 10000) / 10000;
    double ease(double x) => .5 - .5 * cos(pi * x);
    return v < .4 ? .72 + .28 * ease(v / .4) : 1 - .28 * ease((v - .4) / .6);
  }

  Future<void> _bell([int times = 1]) async {
    try {
      await _bell1.play(AssetSource('sounds/bell.wav'));
      if (times > 1) {
        await Future.delayed(const Duration(milliseconds: 2200));
        await _bell2.play(AssetSource('sounds/bell.wav'));
      }
    } catch (_) {}
  }

  void startPause() {
    if (running) {
      running = false;
      _timer?.cancel();
      remain = _endAt!.difference(DateTime.now()).inMilliseconds;
      WakelockPlus.disable();
      notifyListeners();
      return;
    }
    if (started == null) {
      started = DateTime.now();
      wander = 0;
      types = {};
      runMs = 0;
      result = null;
      _bell();
    }
    running = true;
    _lastTick = DateTime.now();
    _endAt = _lastTick!.add(Duration(milliseconds: remain));
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    WakelockPlus.enable();
    notifyListeners();
  }

  void _tick() {
    final now = DateTime.now();
    runMs += now.difference(_lastTick!).inMilliseconds;
    _lastTick = now;
    remain = _endAt!.difference(now).inMilliseconds;
    if (remain <= 0) {
      remain = 0;
      if (tiny) {
        // Hold here and ask; the screen stays on while the question waits.
        _timer?.cancel();
        running = false;
        askContinue = true;
        _bell();
        notifyListeners();
        return;
      }
      finish(true);
      return;
    }
    notifyListeners();
  }

  void noteThought(String t) {
    if (started == null) return;
    wander++;
    types[t] = (types[t] ?? 0) + 1;
    notifyListeners();
  }

  /// A drift caught on the focus screen: counted, but not sorted by kind.
  void noteDrift() {
    if (started == null) return;
    wander++;
    notifyListeners();
  }

  void finish(bool done) {
    _timer?.cancel();
    final left = running ? _endAt!.difference(DateTime.now()).inMilliseconds : remain;
    final elapsed = done ? total : total - max(0, left);
    final min = elapsed ~/ 60000;
    final w = wander, ty = Map<String, int>.from(types), at = started, kind = mode.id;
    final wasTiny = tiny, oneOff = _oneOff, subj = subject;
    running = false;
    tiny = false;
    _oneOff = false;
    subject = null;
    askContinue = false;
    started = null;
    if (wasTiny || oneOff) {
      _resetTotal();
    } else {
      remain = total;
    }
    runMs = 0;
    wander = 0;
    types = {};
    WakelockPlus.disable();
    if (done) _bell(2);
    if (min >= 1) {
      store.mutate(todayKey(), (d) => (d['sessions'] as List).add({
            'id': newId(),
            'at': at?.toIso8601String(),
            'min': min,
            'wander': w,
            'types': ty,
            'done': done,
            'kind': kind,
            if (kind == 'study' && task.isNotEmpty) 'task': task,
            'subject': ?subj,
          }));
      final top = ty.entries.isEmpty ? null : (ty.entries.toList()..sort((a, b) => b.value - a.value)).first.key;
      final label = {'study': 'เรียนอย่างมีสติ', 'move': 'เจริญสติด้วยจังหวะมือ', 'sit': 'ดูลมหายใจ'}[kind];
      result = wasTiny
          ? 'เริ่มได้แล้ว ${thaiNum(min)} นาที\nการเริ่มคือส่วนที่ยากที่สุด วันนี้ผ่านมาแล้ว'
          : '$label ${thaiNum(min)} นาที\n${w > 0 ? 'รู้ทันความคิดแล้วกลับมา ${thaiNum(w)} ครั้ง${top != null ? ' ใจมักไปที่ "$top"' : ''}\nทุกครั้งที่รู้ตัว คือการฝึกที่สำเร็จ' : 'ใจที่ตั้งมั่นแม้ชั่วครู่ ก็มีค่ายิ่ง'}';
    } else {
      result = 'ยังไม่ถึง 1 นาที เลยยังไม่บันทึก\nพร้อมเมื่อไหร่ เริ่มใหม่ได้เสมอ';
    }
    notifyListeners();
  }
}

class PracticePage extends StatelessWidget {
  final PracticeController c;
  const PracticePage({super.key, required this.c});

  String _fmt(int ms) {
    final s = max(0, (ms / 1000).ceil());
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final m = c.mode;
        final locked = c.started != null;
        final scale = c.breathing ? c.breathScale : .86;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (!locked) ...[
            Text('ฝึก', style: display(context, 26)),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => openClassroom(context, c.store),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(colors: [const Color(0xFF6FA8DC).withValues(alpha: .18), const Color(0xFF6FA8DC).withValues(alpha: .05)]),
                  border: Border.all(color: const Color(0xFF6FA8DC).withValues(alpha: .4)),
                ),
                child: Row(children: [
                  const Icon(Icons.school_rounded, color: Color(0xFF6FA8DC), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('เรียนในห้อง', style: display(context, 17)),
                      Text('ก่อนคาบ 1 นาที · ระหว่างคาบมีระฆังสติ · หลังคาบสรุปจากความจำ', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF6FA8DC)),
                ]),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openGuide(context, c.store),
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: const Text('วิธีเรียนให้ได้ผล'),
              ),
            ),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: [for (final x in modes) ButtonSegment(value: x.id, label: Text(x.tab))],
              selected: {m.id},
              showSelectedIcon: false,
              onSelectionChanged: locked ? null : (s) => c.setMode(s.first),
            ),
            const SizedBox(height: 18),
            Eyebrow(m.eyebrow),
            Text(m.title, style: display(context, 22)),
            const SizedBox(height: 4),
            Text(m.desc, style: TextStyle(color: p.muted, height: 1.6)),
            const SizedBox(height: 16),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              for (final n in m.presets)
                ChoiceChip(
                  label: Text('${thaiNum(n)} นาที'),
                  selected: c.total == n * 60000,
                  showCheckmark: false,
                  onSelected: locked ? null : (_) => c.setMinutes(n),
                ),
            ]),
            if (m.id == 'sit')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: c.breathGuide,
                onChanged: c.toggleBreath,
                title: const Text('วงกลมนำจังหวะลมหายใจ'),
                subtitle: const Text('เข้า 4 วินาที ออก 6 วินาที'),
              ),
            if (m.id == 'study') ...[
              const SizedBox(height: 16),
              TextFormField(
                initialValue: c.task,
                onChanged: c.setTask,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'งานชิ้นเล็กที่สุด ที่จะทำตอนนี้',
                  hintText: 'เช่น ทำการบ้านเลขข้อ 1 · อ่านหน้า 42 ย่อหน้าแรก',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            ] else ...[
              const SizedBox(height: 28),
              Center(child: Eyebrow(m.eyebrow)),
              Center(child: Text(m.title, style: display(context, 22))),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(alignment: Alignment.center, children: [
                  AnimatedScale(
                    scale: scale,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.line),
                        gradient: RadialGradient(
                          center: const Alignment(0, -.1),
                          colors: [
                            Color.lerp(p.surface, p.lotus, .24)!,
                            Color.lerp(p.surface, p.pond, .2)!,
                            p.surface,
                          ],
                          stops: const [0, .62, 1],
                        ),
                      ),
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_fmt(c.remain),
                        style: TextStyle(fontSize: 52, fontWeight: FontWeight.w500, fontFeatures: const [FontFeature.tabularFigures()], color: p.ink)),
                    SizedBox(
                      width: 220,
                      child: Text(c.phase, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 15)),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            if (c.askContinue)
              ContinueAsk(c: c)
            else
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton(
                onPressed: () {
                  final opening = !c.running && m.id == 'study';
                  c.startPause();
                  if (opening) openFocus(context, c);
                },
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                child: Text(c.running ? 'พัก' : locked ? 'ฝึกต่อ' : 'เริ่ม'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: locked ? () => c.finish(false) : null,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                child: const Text('จบ'),
              ),
            ]),
            if (!locked && m.id == 'study') ...[
              const SizedBox(height: 14),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    c.startTiny();
                    openFocus(context, c);
                  },
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('ไม่อยากเริ่ม? ลองแค่ 2 นาที'),
                ),
              ),
            ],
            if (locked && m.id == 'study') ...[
              const SizedBox(height: 14),
              Center(
                child: TextButton.icon(
                  onPressed: () => openFocus(context, c),
                  icon: const Icon(Icons.dark_mode_rounded),
                  label: const Text('เปิดจอโฟกัส (จอมืด ค้างไว้)'),
                ),
              ),
            ],
            if (locked) ...[
              const SizedBox(height: 22),
              Text('ใจเผลอไปที่ไหน · แตะ แล้วกลับมา',
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                for (final t in thoughts) ActionChip(label: Text(t), onPressed: () => c.noteThought(t)),
              ]),
              const SizedBox(height: 8),
              Text('รู้ทันแล้ว ${thaiNum(c.wander)} ครั้ง',
                  textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
            ],
            if (c.result != null) ...[
              const SizedBox(height: 20),
              Panel(child: Text(c.result!, textAlign: TextAlign.center, style: const TextStyle(height: 1.7))),
            ],
          ],
        );
      },
    );
  }
}

void openFocus(BuildContext context, PracticeController c) {
  Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    pageBuilder: (_, _, _) => FocusScreen(c: c),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 600),
  ));
}

/// Asked when a two-minute start runs out: carry on, or stop with no guilt.
class ContinueAsk extends StatelessWidget {
  final PracticeController c;
  final bool onDark;
  const ContinueAsk({super.key, required this.c, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? Colors.white.withValues(alpha: .85) : Pal.of(context).ink;
    final muted = onDark ? Colors.white.withValues(alpha: .5) : Pal.of(context).muted;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('ครบ 2 นาทีแล้ว', textAlign: TextAlign.center, style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text('เริ่มได้แล้ว ส่วนที่ยากที่สุดผ่านไปแล้ว\nไปต่ออีกนิดไหม', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.6)),
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        FilledButton(onPressed: () => c.continueStudy(10), child: const Text('ต่ออีก 10 นาที')),
        FilledButton.tonal(onPressed: () => c.continueStudy(25), child: const Text('ต่ออีก 25 นาที')),
        TextButton(
          onPressed: () => c.finish(true),
          child: Text('พอแค่นี้', style: TextStyle(color: muted)),
        ),
      ]),
    ]);
  }
}

/// Study focus screen: near-black, dimmed backlight, screen kept on.
/// Tap anywhere when the mind slips — one breath, then back to the book.
/// Long-press to leave.
class FocusScreen extends StatefulWidget {
  final PracticeController c;
  const FocusScreen({super.key, required this.c});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const _dim = .03;
  static const _back = .25;
  static const _lines = [
    'กลับมาแล้ว',
    'หายใจเข้าลึก… ผ่อนออกยาว',
    'เรากำลังเรียนอะไรอยู่',
    'ประโยคเมื่อครู่ อ่านซ้ำอีกครั้ง',
  ];

  Timer? _settle;
  bool _returning = false, _leaving = false, _asking = false;
  int _line = 0;

  PracticeController get c => widget.c;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _brightness(_dim);
    c.addListener(_onTick);
  }

  void _onTick() {
    // Session ended (time up or finished elsewhere): leave the dark screen.
    if (c.started == null && mounted && !_leaving) {
      _leaving = true;
      Navigator.of(context).maybePop();
      return;
    }
    // The two-minute question needs enough light to read and answer.
    if (c.askContinue != _asking) {
      _asking = c.askContinue;
      _settle?.cancel();
      _returning = false;
      _brightness(_asking ? _back : _dim);
    }
  }

  Future<void> _brightness(double v) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(v);
    } catch (_) {}
  }

  void _drift() {
    if (c.askContinue) return;
    if (!c.running) c.startPause();
    c.noteDrift();
    _settle?.cancel();
    setState(() {
      _returning = true;
      _line = (_line + 1) % _lines.length;
    });
    _brightness(_back);
    // One slow breath of light, then sink back into the dark.
    _settle = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _returning = false);
      _brightness(_dim);
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    c.removeListener(_onTick);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError((_) {});
    if (!c.running) WakelockPlus.disable();
    super.dispose();
  }

  String _fmt(int ms) {
    final s = max(0, (ms / 1000).ceil());
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _drift,
        onLongPress: () => Navigator.of(context).maybePop(),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final faint = Colors.white.withValues(alpha: .16);
            return SafeArea(
              child: Stack(children: [
                Positioned(
                  top: 18,
                  left: 0,
                  right: 0,
                  child: Text(
                    '${_fmt(c.remain)}${c.running || c.askContinue ? '' : ' · พักอยู่'}'
                    '${c.task.isEmpty ? '' : '\n${c.task}'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: faint, fontSize: 15, height: 1.6, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 900),
                    child: c.askContinue
                        ? Padding(
                            key: const ValueKey('ask'),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ContinueAsk(c: c, onDark: true),
                          )
                        : _returning
                        ? Column(key: const ValueKey('back'), mainAxisSize: MainAxisSize.min, children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: .6, end: 1),
                              duration: const Duration(seconds: 4),
                              curve: Curves.easeInOut,
                              builder: (_, s, _) => Transform.scale(
                                scale: s,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [p.lotus.withValues(alpha: .35), Colors.transparent]),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(_lines[_line],
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 20)),
                            if (c.task.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('กลับไปที่ · ${c.task}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withValues(alpha: .6), fontSize: 15)),
                            ],
                            const SizedBox(height: 8),
                            Text('รู้ทันแล้ว ${thaiNum(c.wander)} ครั้ง',
                                style: TextStyle(color: Colors.white.withValues(alpha: .4), fontSize: 13)),
                          ])
                        : Text('หลุดเมื่อไหร่ แตะจอ',
                            key: const ValueKey('rest'), style: TextStyle(color: faint, fontSize: 14)),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Text('กดค้างเพื่อออก',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .09), fontSize: 12)),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
