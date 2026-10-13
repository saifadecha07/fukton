import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'classroom.dart';
import 'content.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class PracticeController extends ChangeNotifier {
  final Store store;
  PracticeController(this.store) {
    final saved = store.prefs.getString('mode');
    mode = modes.firstWhere((m) => m.id == saved, orElse: () => modes.first);
    _resetTotal();
  }

  late Mode mode;
  int total = 0, remain = 0, runMs = 0, wander = 0;
  bool running = false;
  bool breathGuide = true;
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

  void finish(bool done) {
    _timer?.cancel();
    final left = running ? _endAt!.difference(DateTime.now()).inMilliseconds : remain;
    final elapsed = done ? total : total - max(0, left);
    final min = elapsed ~/ 60000;
    final w = wander, ty = Map<String, int>.from(types), at = started, kind = mode.id;
    running = false;
    started = null;
    remain = total;
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
          }));
      final top = ty.entries.isEmpty ? null : (ty.entries.toList()..sort((a, b) => b.value - a.value)).first.key;
      final label = {'study': 'เรียนอย่างมีสติ', 'move': 'เจริญสติด้วยจังหวะมือ', 'sit': 'ดูลมหายใจ'}[kind];
      result = '$label ${thaiNum(min)} นาที\n${w > 0 ? 'รู้ทันความคิดแล้วกลับมา ${thaiNum(w)} ครั้ง${top != null ? ' ใจมักไปที่ "$top"' : ''}\nทุกครั้งที่รู้ตัว คือการฝึกที่สำเร็จ' : 'ใจที่ตั้งมั่นแม้ชั่วครู่ ก็มีค่ายิ่ง'}';
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
            const SizedBox(height: 14),
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
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton(
                onPressed: c.startPause,
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
