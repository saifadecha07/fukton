import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'content.dart';
import 'mascot.dart';
import 'store.dart';
import 'theme.dart';

const _bg = Color(0xFF0B1418);
const _ink = Color(0xFFF2EDE4);
const _dim = Color(0xFF93A59D);
const _lotus = Color(0xFFE58BAB);
const _pond = Color(0xFF82BAB0);

Route<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    );

ButtonStyle _primary() => FilledButton.styleFrom(
      backgroundColor: _lotus,
      foregroundColor: _bg,
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
    );

ButtonStyle _secondary() => OutlinedButton.styleFrom(
      foregroundColor: _ink,
      side: BorderSide(color: _dim.withValues(alpha: .5)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    );

// ===========================================================================
// ใจขุ่น · กังวล — a jar of muddy water settles while we breathe.
// Then name the thought, and ask: can I do something about it?
// ===========================================================================
Future<void> openCloudyMind(BuildContext context, Store store) => Navigator.of(context).push(_fade(CloudyMindPage(store: store)));

class CloudyMindPage extends StatefulWidget {
  final Store store;
  const CloudyMindPage({super.key, required this.store});
  @override
  State<CloudyMindPage> createState() => _CloudyMindPageState();
}

class _CloudyMindPageState extends State<CloudyMindPage> with TickerProviderStateMixin {
  static const settleSeconds = 60;
  late final AnimationController settle = AnimationController(vsync: this, duration: const Duration(seconds: settleSeconds));
  late final AnimationController shimmer = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  late final AnimationController drift = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  int phase = 0; // 0 settle, 1 name, 2 can I act, 3 step, 4 let go, 5 done
  String? kind;
  bool? can;
  final text = TextEditingController();
  final step = TextEditingController();

  @override
  void initState() {
    super.initState();
    settle.forward();
    settle.addStatusListener((s) {
      if (s == AnimationStatus.completed && phase == 0) {
        HapticFeedback.mediumImpact();
        setState(() => phase = 1);
      }
    });
  }

  @override
  void dispose() {
    settle.dispose();
    shimmer.dispose();
    drift.dispose();
    super.dispose();
  }

  void _save() => widget.store.mutate(todayKey(), (d) => (d['worries'] as List).add({
        'id': newId(),
        't': DateTime.now().toIso8601String(),
        'kind': kind,
        'text': text.text.trim(),
        'can': can,
        'step': step.text.trim(),
      }));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 4, 26, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: _dim)),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: switch (phase) {
                  0 => _settleView(),
                  1 => _nameView(),
                  2 => _canView(),
                  3 => _stepView(),
                  4 => _letGoView(),
                  _ => _doneView(),
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _settleView() => Column(key: const ValueKey(0), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ใจขุ่น', style: TextStyle(fontFamily: cute, fontSize: 38, fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 6),
        const Text('ดั่งน้ำในโหลที่ถูกเขย่า\nไม่ต้องกวน ไม่ต้องรีบใส\nเพียงตั้งไว้นิ่ง ๆ ตะกอนจะนอนก้นเอง',
            style: TextStyle(fontFamily: serif, fontSize: 17, height: 1.65, color: _dim)),
        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([settle, shimmer]),
              builder: (_, _) => CustomPaint(size: const Size(210, 250), painter: _JarPainter(settle.value, shimmer.value)),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: settle,
          builder: (_, _) {
            final s = (settle.value * settleSeconds).floor();
            final breathIn = (s % 10) < 4;
            return Column(children: [
              Text(breathIn ? 'หายใจเข้า…' : 'ผ่อนลมออกยาว ๆ…',
                  textAlign: TextAlign.center, style: const TextStyle(fontFamily: serif, fontSize: 22, color: _ink, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('อีก ${thaiNum(settleSeconds - s)} วินาที', textAlign: TextAlign.center, style: const TextStyle(color: _dim)),
            ]);
          },
        ),
        TextButton(
          onPressed: () {
            settle.value = 1;
            setState(() => phase = 1);
          },
          child: const Text('ข้ามไปขั้นต่อไป', style: TextStyle(color: _dim)),
        ),
      ]);

  Widget _nameView() => SingleChildScrollView(
        key: const ValueKey(1),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('ตั้งชื่อให้มัน', style: TextStyle(fontFamily: cute, fontSize: 34, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 6),
          const Text('ความคิดที่ถูกเรียกชื่อ จะเบาลงครึ่งหนึ่ง\nเพราะเรากลายเป็นผู้ดู ไม่ใช่ผู้จมอยู่ในมัน',
              style: TextStyle(fontSize: 15, height: 1.6, color: _dim)),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final w in worryKinds)
              GestureDetector(
                onTap: () => setState(() => kind = w),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: kind == w ? _lotus : Colors.transparent,
                    border: Border.all(color: kind == w ? _lotus : _dim.withValues(alpha: .45)),
                  ),
                  child: Text(w, style: TextStyle(color: kind == w ? _bg : _ink, fontWeight: kind == w ? FontWeight.w600 : FontWeight.w400)),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          _darkField(text, 'เขียนสั้น ๆ ว่าคิดเรื่องอะไรอยู่ (ไม่เขียนก็ได้)'),
          const SizedBox(height: 22),
          FilledButton(onPressed: kind == null ? null : () => setState(() => phase = 2), style: _primary(), child: const Text('ถัดไป')),
        ]),
      );

  Widget _canView() => Column(key: const ValueKey(2), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('เรื่องนี้\nเราทำอะไรกับมันได้ไหม', style: TextStyle(fontFamily: cute, fontSize: 32, height: 1.35, fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 10),
        const Text('บางเรื่องต้องลงมือ บางเรื่องต้องปล่อย\nปัญญาคือการรู้ว่าเรื่องไหนเป็นแบบไหน',
            style: TextStyle(fontSize: 15, height: 1.6, color: _dim)),
        const Spacer(),
        FilledButton(onPressed: () => setState(() { can = true; phase = 3; }), style: _primary(), child: const Text('ทำได้ · มีบางอย่างที่ลงมือได้')),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () {
            setState(() { can = false; phase = 4; });
            drift.forward(from: 0);
            HapticFeedback.lightImpact();
          },
          style: _secondary(),
          child: const Text('ทำไม่ได้ · อยู่นอกมือเรา'),
        ),
      ]);

  Widget _stepView() => SingleChildScrollView(
        key: const ValueKey(3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('ก้าวเล็กที่สุด', style: TextStyle(fontFamily: cute, fontSize: 34, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 6),
          const Text('ไม่ต้องแก้ทั้งหมด แค่ก้าวแรกที่ทำได้ภายในสิบนาที\nเมื่อเขียนแล้ว ใจจะวางมันลงได้',
              style: TextStyle(fontSize: 15, height: 1.6, color: _dim)),
          const SizedBox(height: 18),
          _darkField(step, 'เช่น ส่งข้อความถามอาจารย์ หรืออ่านบทที่ ๓ หนึ่งหน้า'),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () {
              _save();
              HapticFeedback.mediumImpact();
              setState(() => phase = 5);
            },
            style: _primary(),
            child: const Text('จดไว้ แล้ววางใจ'),
          ),
        ]),
      );

  Widget _letGoView() {
    final said = text.text.trim().isEmpty ? (kind ?? 'ความคิดนี้') : text.text.trim();
    return Column(key: const ValueKey(4), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('ปล่อยให้ลมพัดไป', style: TextStyle(fontFamily: cute, fontSize: 34, fontWeight: FontWeight.w600, color: _ink)),
      const SizedBox(height: 6),
      const Text('ดั่งสายลมที่ตาข่ายมิอาจจับได้\nเรื่องที่อยู่นอกมือ เรามีสิทธิ์วางมันลง',
          style: TextStyle(fontFamily: serif, fontSize: 16, height: 1.6, color: _dim)),
      Expanded(
        child: AnimatedBuilder(
          animation: drift,
          builder: (_, _) {
            final t = Curves.easeInCubic.transform(drift.value);
            return Center(
              child: Opacity(
                opacity: (1 - t).clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(t * 140, -t * 220),
                  child: Transform.rotate(
                    angle: t * .4,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _dim.withValues(alpha: .3)),
                      ),
                      child: Text(said, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 16)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      FilledButton(
        onPressed: () {
          _save();
          setState(() => phase = 5);
        },
        style: _primary(),
        child: const Text('วางลงแล้ว'),
      ),
    ]);
  }

  Widget _doneView() => Column(key: const ValueKey(5), children: [
        const Spacer(),
        const BuaNoi(mood: BuaMood.happy, size: 120),
        const SizedBox(height: 18),
        Text(can == true ? 'ก้าวแรกถูกจดไว้แล้ว\nตอนนี้ ใจพักได้' : 'ลมพัดผ่านไปแล้ว\nใจเบาลงอีกนิด',
            textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 26, height: 1.45, color: _ink, fontWeight: FontWeight.w600)),
        const Spacer(),
        FilledButton(onPressed: () => Navigator.of(context).pop(), style: _primary(), child: const Text('กลับสู่สระบัว')),
      ]);
}

Widget _darkField(TextEditingController c, String hint) => TextField(
      controller: c,
      minLines: 2,
      maxLines: 5,
      maxLength: 1000,
      style: const TextStyle(color: _ink, fontSize: 15.5, height: 1.5),
      cursorColor: _lotus,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5E716B)),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withValues(alpha: .05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );

class _JarPainter extends CustomPainter {
  final double settled; // 0 shaken .. 1 clear
  final double t;
  _JarPainter(this.settled, this.t);

  static final _grains = List.generate(140, (i) {
    final r = Random(i * 97 + 3);
    return (r.nextDouble(), r.nextDouble(), r.nextDouble(), .8 + r.nextDouble() * 2.2);
  });

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final jar = RRect.fromRectAndCorners(Rect.fromLTWH(18, 34, w - 36, h - 40),
        topLeft: const Radius.circular(22), topRight: const Radius.circular(22), bottomLeft: const Radius.circular(40), bottomRight: const Radius.circular(40));
    final ease = Curves.easeOutCubic.transform(settled);
    // water: murky brown fades to clear blue-green
    final murky = Color.lerp(const Color(0xFF6B5A44), const Color(0xFF2E5F5A), ease)!;
    c.save();
    c.clipRRect(jar);
    c.drawRect(Rect.fromLTWH(0, 50, w, h),
        Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [murky.withValues(alpha: .75), murky]).createShader(Rect.fromLTWH(0, 50, w, h)));
    // sediment pile grows at the bottom
    final pile = 6 + 22 * ease;
    c.drawOval(Rect.fromCenter(center: Offset(w / 2, h - 6), width: w - 50, height: pile * 1.6), Paint()..color = const Color(0xFF8A7556));
    // grains drift down as the water settles
    for (final (fx, fy, ph, r) in _grains) {
      final restY = h - 10 - (fx * 7 + ph * 9) * ease;
      final cloudY = 60 + fy * (h - 90);
      final y = cloudY + (restY - cloudY) * Curves.easeInOut.transform(min(1, settled * (1.1 + ph * .6)));
      final wob = (1 - ease) * 6 * sin(t * 2 * pi + ph * 9);
      final x = 30 + fx * (w - 60) + wob;
      c.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFFC9A774).withValues(alpha: .25 + .5 * (1 - ease)));
    }
    // surface shimmer
    c.drawLine(Offset(28, 52 + sin(t * 2 * pi) * 1.5), Offset(w - 28, 52 - sin(t * 2 * pi) * 1.5),
        Paint()
          ..color = Colors.white.withValues(alpha: .25)
          ..strokeWidth = 2);
    c.restore();
    // glass
    c.drawRRect(jar, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: .35));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(30, 18, w - 60, 20), const Radius.circular(8)),
        Paint()..color = Colors.white.withValues(alpha: .18));
    c.drawLine(Offset(34, 70), Offset(34, h - 50), Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
    // a little lotus floats once the water is clear
    if (ease > .6) {
      final a = (ease - .6) / .4;
      final o = Offset(w / 2 + 18, 58);
      for (final ang in const [-.7, .7, 0.0]) {
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(ang);
        final p = Path()
          ..moveTo(0, 0)
          ..cubicTo(-6, -7, -5, -15, 0, -20)
          ..cubicTo(5, -15, 6, -7, 0, 0);
        c.drawPath(p, Paint()..color = _lotus.withValues(alpha: a * (ang == 0 ? 1 : .7)));
        c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _JarPainter old) => true;
}

// ===========================================================================
// ก่อนนอน — empty the mind onto paper, long slow exhales, soften the body,
// send kindness, and let the rain carry you to sleep.
// ===========================================================================
Future<void> openSleep(BuildContext context, Store store) => Navigator.of(context).push(_fade(SleepPage(store: store)));

class SleepPage extends StatefulWidget {
  final Store store;
  const SleepPage({super.key, required this.store});
  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> with TickerProviderStateMixin {
  int phase = 0; // 0 empty the mind, 1 breathe, 2 body, 3 metta, 4 goodnight
  final dump = TextEditingController();
  late final AnimationController breath = AnimationController(vsync: this, duration: const Duration(seconds: 12)); // 4 in, 8 out
  int cycles = 0;
  static const totalCycles = 6;
  int line = 0;
  Timer? _t;
  final _rain = AudioPlayer();
  bool rainOn = false;
  int rainMinutes = 20;
  Timer? _rainTimer;
  double dim = 0;

  @override
  void initState() {
    super.initState();
    breath.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      cycles++;
      if (cycles >= totalCycles) {
        _go(2);
      } else {
        breath.forward(from: 0);
      }
      setState(() {});
    });
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _t?.cancel();
    _rainTimer?.cancel();
    breath.dispose();
    _rain.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _toggleRain() async {
    if (rainOn) {
      await _rain.stop();
      _rainTimer?.cancel();
      setState(() => rainOn = false);
      return;
    }
    try {
      await _rain.setReleaseMode(ReleaseMode.loop);
      await _rain.setVolume(.7);
      await _rain.play(AssetSource('sounds/rain.wav'));
      setState(() => rainOn = true);
      _rainTimer?.cancel();
      _rainTimer = Timer(Duration(minutes: rainMinutes), _fadeRain);
    } catch (_) {}
  }

  Future<void> _fadeRain() async {
    for (var v = .7; v > 0; v -= .05) {
      await _rain.setVolume(max(0, v));
      await Future.delayed(const Duration(seconds: 2));
    }
    await _rain.stop();
    if (mounted) setState(() => rainOn = false);
  }

  void _go(int p) {
    _t?.cancel();
    setState(() {
      phase = p;
      line = 0;
    });
    if (p == 1) {
      cycles = 0;
      breath.forward(from: 0);
    }
    if (p == 2 || p == 3) {
      final lines = p == 2 ? bodyScan : mettaLines;
      _t = Timer.periodic(const Duration(seconds: 7), (t) {
        if (line >= lines.length - 1) {
          t.cancel();
          _go(p + 1);
          return;
        }
        setState(() => line++);
      });
    }
    if (p == 4) {
      widget.store.mutate(todayKey(), (d) => (d['sleeps'] as List).add({
            'id': newId(),
            't': DateTime.now().toIso8601String(),
            'dump': dump.text.trim(),
          }));
      // slowly dim the screen
      Timer.periodic(const Duration(milliseconds: 120), (t) {
        if (!mounted || dim >= .85) {
          t.cancel();
          return;
        }
        setState(() => dim += .01);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070D12),
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _NightSky())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 4, 26, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                TextButton.icon(
                  onPressed: _toggleRain,
                  icon: Icon(rainOn ? Icons.water_drop_rounded : Icons.water_drop_outlined, color: rainOn ? _pond : _dim, size: 20),
                  label: Text(rainOn ? 'เสียงฝน · ${thaiNum(rainMinutes)} นาที' : 'เปิดเสียงฝน', style: TextStyle(color: rainOn ? _pond : _dim)),
                ),
                const Spacer(),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: _dim)),
              ]),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  child: switch (phase) {
                    0 => _dumpView(),
                    1 => _breathView(),
                    2 => _linesView('คลายกาย', bodyScan, const ValueKey(2)),
                    3 => _linesView('แผ่เมตตา', mettaLines, const ValueKey(3)),
                    _ => _nightView(),
                  },
                ),
              ),
            ]),
          ),
        ),
        IgnorePointer(child: Container(color: Colors.black.withValues(alpha: dim))),
      ]),
    );
  }

  Widget _dumpView() => SingleChildScrollView(
        key: const ValueKey(0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          const Center(child: BuaNoi(mood: BuaMood.sleepy, size: 96)),
          const SizedBox(height: 16),
          const Text('เทความคิดลงกระดาษ', style: TextStyle(fontFamily: cute, fontSize: 32, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 6),
          const Text('สิ่งที่ค้างในหัว เขียนลงตรงนี้ให้หมด\nพรุ่งนี้มันยังอยู่ตรงนี้ คืนนี้ใจไม่ต้องถือไว้',
              style: TextStyle(fontSize: 15, height: 1.6, color: _dim)),
          const SizedBox(height: 16),
          _darkField(dump, 'พรุ่งนี้ต้องส่งงาน… กังวลเรื่อง… ยังค้างใจเรื่อง…'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              _go(1);
            },
            style: _primary(),
            child: Text(dump.text.trim().isEmpty ? 'ไม่มีอะไรค้าง · ไปต่อ' : 'ฝากไว้กับพรุ่งนี้'),
          ),
        ]),
      );

  Widget _breathView() => Column(key: const ValueKey(1), children: [
        const SizedBox(height: 8),
        const Text('ผ่อนลมยาว', style: TextStyle(fontFamily: cute, fontSize: 30, fontWeight: FontWeight.w600, color: _ink)),
        const Text('เข้า 4 · ออก 8\nลมออกที่ยาว บอกกายว่าปลอดภัยแล้ว', textAlign: TextAlign.center, style: TextStyle(color: _dim, height: 1.6)),
        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: breath,
              builder: (_, _) {
                final v = breath.value;
                double ease(double x) => .5 - .5 * cos(pi * x);
                final inhale = v < 4 / 12;
                final scale = inhale ? .5 + .5 * ease(v / (4 / 12)) : 1 - .5 * ease((v - 4 / 12) / (8 / 12));
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [_pond.withValues(alpha: .35), const Color(0xFF6B7FD7).withValues(alpha: .12), Colors.transparent]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(inhale ? 'หายใจเข้า' : 'ผ่อนออก… ช้า ๆ',
                      style: const TextStyle(fontFamily: serif, fontSize: 24, color: _ink, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('${thaiNum(min(cycles + 1, totalCycles))} / ${thaiNum(totalCycles)}', style: const TextStyle(color: _dim, letterSpacing: 2)),
                ]);
              },
            ),
          ),
        ),
      ]);

  Widget _linesView(String title, List<String> lines, Key key) => Column(key: key, children: [
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontFamily: cute, fontSize: 30, fontWeight: FontWeight.w600, color: _ink)),
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1400),
              child: Text(lines[line],
                  key: ValueKey('$title$line'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: serif, fontSize: 26, height: 1.5, color: _ink, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        Text('${thaiNum(line + 1)} / ${thaiNum(lines.length)}', style: const TextStyle(color: _dim, letterSpacing: 2)),
        TextButton(onPressed: () => _go(phase + 1), child: const Text('ข้าม', style: TextStyle(color: _dim))),
      ]);

  Widget _nightView() => Column(key: const ValueKey(4), children: [
        const Spacer(),
        const BuaNoi(mood: BuaMood.sleepy, size: 130),
        const SizedBox(height: 20),
        const Text('ราตรีสวัสดิ์', style: TextStyle(fontFamily: cute, fontSize: 36, fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 8),
        const Text('วางโทรศัพท์ลง แล้วหลับตา\nตามดูลมหายใจ จนกว่าจะหลับไป', textAlign: TextAlign.center, style: TextStyle(color: _dim, height: 1.7, fontSize: 15)),
        const Spacer(),
        if (!rainOn)
          OutlinedButton(onPressed: _toggleRain, style: _secondary(), child: const Text('เปิดเสียงฝนกล่อม · ปิดเองใน ๒๐ นาที')),
      ]);
}

class _NightSky extends CustomPainter {
  static final _stars = List.generate(60, (i) {
    final r = Random(i * 31 + 7);
    return (r.nextDouble(), r.nextDouble() * .7, r.nextDouble() * 1.4 + .4);
  });
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A1220), Color(0xFF101C2A), Color(0xFF0B1418)])
              .createShader(Offset.zero & s));
    for (final (x, y, r) in _stars) {
      c.drawCircle(Offset(x * s.width, y * s.height), r, Paint()..color = const Color(0xFFF2EBD3).withValues(alpha: .35));
    }
    final m = Offset(s.width * .82, s.height * .1);
    c.drawCircle(m, 70, Paint()..shader = RadialGradient(colors: [const Color(0xFFF2EBD3).withValues(alpha: .12), Colors.transparent]).createShader(Rect.fromCircle(center: m, radius: 70)));
    c.drawCircle(m, 18, Paint()..color = const Color(0xFFF2EBD3).withValues(alpha: .9));
    c.drawCircle(m.translate(7, -5), 16, Paint()..color = const Color(0xFF0A1220));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
