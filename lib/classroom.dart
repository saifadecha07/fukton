import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'iq.dart';
import 'mascot.dart';
import 'notify.dart';
import 'store.dart';
import 'theme.dart';

// เรียนในห้อง — be present in class, not just in the room.
// Before: set a question (pre-questioning primes attention) and breathe.
// During: phone face-up on the desk, screen near-black and kept on; tap it
//         each time the mind wanders, take one breath of light, back to class.
//         A silent vibration every few minutes asks "are you here?".
// After:  write the key points from memory before opening the notebook
//         (free recall is the strongest known way to remember), name what is
//         still unclear, and turn the points into review cards.

const _bg = Color(0xFF0B1418);
const _ink = Color(0xFFF2EDE4);
const _dim = Color(0xFF93A59D);
const _lotus = Color(0xFFE58BAB);
const _pond = Color(0xFF82BAB0);
const _sky = Color(0xFF6FA8DC);

Future<void> openClassroom(BuildContext context, Store store) => Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => ClassroomPage(store: store),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));

ButtonStyle _primary() => FilledButton.styleFrom(
      backgroundColor: _lotus,
      foregroundColor: _bg,
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
    );

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF5E716B)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: .05),
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );

Widget _chips<T>(List<(T, String)> opts, T value, ValueChanged<T> on) => Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (v, l) in opts)
        GestureDetector(
          onTap: () => on(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: v == value ? _sky : Colors.transparent,
              border: Border.all(color: v == value ? _sky : _dim.withValues(alpha: .45)),
            ),
            child: Text(l, style: TextStyle(color: v == value ? _bg : _ink, fontWeight: v == value ? FontWeight.w600 : FontWeight.w400)),
          ),
        ),
    ]);

const _howTo = <(IconData, String, String)>[
  (Icons.hearing_rounded, 'ฟัง', 'รู้ว่ากำลังฟัง จับว่าครูกำลังพูดเรื่องหลักอะไร ตัวอย่างคืออะไร และ “ทำไม” ถึงเป็นแบบนั้น'),
  (Icons.visibility_rounded, 'ดู', 'สังเกตสิ่งที่ครูเน้น: เขียนซ้ำ ชี้ พูดช้าลง หรือบอกว่า “ตรงนี้ออกสอบ” นั่นคือแก่นของคาบ'),
  (Icons.edit_note_rounded, 'จด', 'จดด้วยคำของตัวเอง ไม่ต้องลอกทุกคำ เขียนคำถามที่สงสัยไว้ข้างกระดาษ แล้วถามเมื่อมีจังหวะ'),
  (Icons.touch_app_rounded, 'แตะ', 'วางมือถือไว้บนโต๊ะ จอจะมืดค้างไว้ ใจลอยเมื่อไหร่ แตะจอหนึ่งที แล้วกลับมาฟังทันที ไม่ต้องตำหนิตัวเอง'),
];

class ClassroomPage extends StatefulWidget {
  final Store store;
  const ClassroomPage({super.key, required this.store});
  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> with SingleTickerProviderStateMixin {
  int phase = 0; // 0 set up, 1 arrive (3 breaths), 2 in class, 3 after-class recall, 4 done
  final subject = TextEditingController();
  final intent = TextEditingController();
  int minutes = 50, bell = 15;
  DateTime? startedAt;
  Timer? _tick;
  int tipAt = 0;

  late final AnimationController breath = AnimationController(vsync: this, duration: const Duration(seconds: 10));
  int breaths = 0;

  final points = [TextEditingController(), TextEditingController(), TextEditingController()];
  final makeCard = [true, true, true];
  final unclear = TextEditingController();
  int dots = 0, focus = 3;

  // Desk screen: near-black while listening, a breath of light after a tap.
  static const _dark = .03, _lit = .25;
  static const _backLines = ['กลับมาที่ห้อง', 'ครูกำลังพูดเรื่องอะไรอยู่', 'หายใจหนึ่งครั้ง แล้วฟังต่อ', 'จดคำเดียวที่ได้ยินตอนนี้'];
  bool _back = false;
  int _line = 0;
  Timer? _settle;

  Future<void> _bright(double v) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(v);
    } catch (_) {}
  }

  void _deskOn() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _bright(_dark);
  }

  void _deskOff() {
    _settle?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError((_) {});
  }

  void _drift() {
    HapticFeedback.selectionClick();
    _settle?.cancel();
    setState(() {
      dots++;
      _back = true;
      _line = (_line + 1) % _backLines.length;
    });
    _bright(_lit);
    _settle = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _back = false);
      _bright(_dark);
    });
  }

  @override
  void initState() {
    super.initState();
    subject.text = widget.store.prefs.getString('class-last-subject') ?? '';
    breath.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      breaths++;
      HapticFeedback.lightImpact();
      if (breaths >= 3) {
        _enterClass();
      } else {
        breath.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (phase == 2) _deskOff();
    breath.dispose();
    super.dispose();
  }

  Future<void> _enterClass() async {
    if (phase == 2) return;
    breath.stop();
    setState(() {
      phase = 2;
      startedAt = DateTime.now();
    });
    _deskOn();
    try {
      await scheduleClassBells(everyMinutes: bell, totalMinutes: minutes);
    } catch (_) {}
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => tipAt++);
    });
  }

  Future<void> _endClass() async {
    _tick?.cancel();
    _deskOff();
    _back = false;
    try {
      await cancelClassBells();
    } catch (_) {}
    HapticFeedback.mediumImpact();
    setState(() => phase = 3);
  }

  Future<void> _save() async {
    final store = widget.store;
    final subj = subject.text.trim().isEmpty ? 'คาบเรียน' : subject.text.trim();
    final mins = startedAt == null ? 0 : max(1, DateTime.now().difference(startedAt!).inMinutes);
    final kept = [for (final c in points) c.text.trim()].where((t) => t.isNotEmpty).toList();
    await store.prefs.setString('class-last-subject', subj);
    store.mutate(todayKey(), (d) {
      (d['sessions'] as List).add({
        'id': newId(),
        'at': startedAt?.toIso8601String(),
        'min': mins,
        'wander': dots,
        'types': <String, int>{},
        'done': true,
        'kind': 'study',
        'class': true,
      });
      d['classes'] = [
        ...((d['classes'] as List?) ?? const []),
        {
          'id': newId(),
          't': DateTime.now().toIso8601String(),
          'subject': subj,
          'min': mins,
          'intent': intent.text.trim(),
          'points': kept,
          'unclear': unclear.text.trim(),
          'dots': dots,
          'focus': focus,
        },
      ];
    });
    // turn key points into recall cards
    final cards = loadCards(store);
    final date = DateTime.now();
    var n = 0;
    for (var i = 0; i < points.length; i++) {
      final t = points[i].text.trim();
      if (t.isEmpty || !makeCard[i]) continue;
      n++;
      cards.add({
        'id': newId(),
        'q': '[$subj ${date.day}/${date.month}] ประเด็นสำคัญข้อ ${i + 1} ของคาบนี้คืออะไร',
        'a': t,
        'box': 0,
        'due': keyOf(date.add(const Duration(days: 1))),
      });
    }
    if (unclear.text.trim().isNotEmpty) {
      cards.add({
        'id': newId(),
        'q': '[$subj] เรื่องที่เคยสงสัย: ${unclear.text.trim()} · ตอนนี้อธิบายได้หรือยัง',
        'a': 'ถ้ายังอธิบายไม่ได้ ไปถามครูหรือเพื่อน แล้วเขียนคำตอบเพิ่มในการ์ดนี้',
        'box': 0,
        'due': keyOf(date.add(const Duration(days: 1))),
      });
      n++;
    }
    if (n > 0) await saveCards(store, cards);
    setState(() => phase = 4);
  }

  @override
  Widget build(BuildContext context) {
    // A stray back swipe mid-class should not throw the class away.
    if (phase == 2) return PopScope(canPop: false, child: Scaffold(backgroundColor: Colors.black, body: _inClass()));
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.school_rounded, color: _sky, size: 20),
              const SizedBox(width: 8),
              const Text('เรียนในห้อง', style: TextStyle(fontFamily: cute, fontSize: 18, color: _ink, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: _dim)),
            ]),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: switch (phase) {
                  0 => _setup(),
                  1 => _arrive(),
                  3 => _after(),
                  _ => _done(),
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _setup() => SingleChildScrollView(
        key: const ValueKey(0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 6),
          const Text('อยู่ในห้อง\nให้ใจอยู่ด้วย', style: TextStyle(fontFamily: cute, fontSize: 30, height: 1.35, color: _ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('นั่งเรียนหนึ่งชั่วโมง ถ้าใจไม่อยู่ ก็เท่ากับเผาเวลาทิ้ง\nเตรียมใจหนึ่งนาที คาบนี้จะคุ้มขึ้นมาก', style: TextStyle(color: _dim, height: 1.6)),
          const SizedBox(height: 18),
          const Text('วิชาอะไร', style: TextStyle(color: _ink, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(controller: subject, style: const TextStyle(color: _ink), decoration: _dec('เช่น ฟิสิกส์ บทที่ 4'), maxLength: 60),
          const SizedBox(height: 14),
          const Text('อยากรู้อะไรจากคาบนี้ (คำถามหนึ่งข้อ)', style: TextStyle(color: _ink, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          const Text('ตั้งคำถามไว้ก่อน ใจจะคอยหาคำตอบตลอดคาบ', style: TextStyle(color: _dim, fontSize: 12.5)),
          const SizedBox(height: 6),
          TextField(controller: intent, style: const TextStyle(color: _ink), decoration: _dec('เช่น แรงเสียดทานเกิดจากอะไร'), maxLength: 200, minLines: 1, maxLines: 3),
          const SizedBox(height: 14),
          const Text('คาบยาวกี่นาที', style: TextStyle(color: _ink, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _chips<int>([(50, '50'), (60, '60'), (90, '90'), (120, '120')], minutes, (v) => setState(() => minutes = v)),
          const SizedBox(height: 14),
          const Text('ระฆังสติ (สั่นเบา ๆ)', style: TextStyle(color: _ink, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _chips<int>([(0, 'ปิด'), (10, 'ทุก 10 นาที'), (15, 'ทุก 15 นาที'), (20, 'ทุก 20 นาที')], bell, (v) => setState(() => bell = v)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ระหว่างเรียน', style: TextStyle(color: _sky, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final (icon, t, d) in _howTo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(icon, size: 18, color: _pond),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: '$t  ', style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                        TextSpan(text: d, style: const TextStyle(color: _dim, height: 1.5)),
                      ])),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() {
                phase = 1;
                breaths = 0;
              });
              breath.forward(from: 0);
            },
            style: _primary(),
            child: const Text('หายใจ 3 ครั้ง แล้วเข้าคาบ'),
          ),
        ]),
      );

  Widget _arrive() => Column(key: const ValueKey(1), children: [
        const SizedBox(height: 20),
        const Text('มาถึงแล้ว', style: TextStyle(fontFamily: cute, fontSize: 30, color: _ink, fontWeight: FontWeight.w600)),
        const Text('ปล่อยเรื่องก่อนหน้าไว้หน้าห้อง', style: TextStyle(color: _dim)),
        const Spacer(),
        AnimatedBuilder(
          animation: breath,
          builder: (_, _) {
            final v = breath.value;
            double ease(double x) => .5 - .5 * cos(pi * x);
            final sc = v < .4 ? .55 + .45 * ease(v / .4) : 1 - .45 * ease((v - .4) / .6);
            return Column(children: [
              Transform.scale(
                scale: sc,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_sky.withValues(alpha: .4), Colors.transparent])),
                ),
              ),
              const SizedBox(height: 14),
              Text(v < .4 ? 'หายใจเข้า' : 'ผ่อนลมออก', style: const TextStyle(fontFamily: serif, fontSize: 24, color: _ink, fontWeight: FontWeight.w600)),
              Text('${min(breaths + 1, 3)} / 3', style: const TextStyle(color: _dim, letterSpacing: 2)),
            ]);
          },
        ),
        const Spacer(),
        TextButton(onPressed: _enterClass, child: const Text('ข้าม', style: TextStyle(color: _dim))),
      ]);

  Widget _inClass() {
    final mins = startedAt == null ? 0 : DateTime.now().difference(startedAt!).inMinutes;
    final q = intent.text.trim();
    final faint = Colors.white.withValues(alpha: .16);
    // Only the listen / look / note tips; the tap tip is what is happening now.
    final tip = _howTo[_line % 3];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _drift,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${subject.text.trim().isEmpty ? 'คาบเรียน' : subject.text.trim()} · $mins / $minutes นาที',
                textAlign: TextAlign.center, style: TextStyle(color: faint, fontSize: 14)),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 900),
                  child: _back
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
                                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_sky.withValues(alpha: .35), Colors.transparent])),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(_backLines[_line],
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: cute, fontSize: 22, color: _ink.withValues(alpha: .85), fontWeight: FontWeight.w600)),
                          if (q.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text('คำถามของคาบนี้ · $q',
                                textAlign: TextAlign.center, style: TextStyle(color: _ink.withValues(alpha: .6), height: 1.5)),
                          ],
                          const SizedBox(height: 14),
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '${tip.$2}  ', style: TextStyle(color: _pond.withValues(alpha: .8), fontWeight: FontWeight.w600)),
                              TextSpan(text: tip.$3, style: TextStyle(color: _dim.withValues(alpha: .8), height: 1.5)),
                            ]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text('ใจลอย $dots ครั้ง · กลับมาได้ทุกครั้ง', style: TextStyle(color: _dim.withValues(alpha: .6), fontSize: 13)),
                        ])
                      : Column(key: const ValueKey('rest'), mainAxisSize: MainAxisSize.min, children: [
                          Text('ใจลอยเมื่อไหร่ แตะจอ', style: TextStyle(color: faint, fontSize: 15)),
                          if (q.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(q, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .1), fontSize: 13)),
                          ],
                        ]),
                ),
              ),
            ),
            GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _endClass();
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('กดค้างที่นี่เพื่อจบคาบ', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .1), fontSize: 12)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _after() => SingleChildScrollView(
        key: const ValueKey(3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 6),
          const Text('ยังไม่ต้องเปิดสมุด', style: TextStyle(fontFamily: cute, fontSize: 28, color: _ink, fontWeight: FontWeight.w600)),
          const Text('เขียน 3 เรื่องสำคัญจากความจำก่อน\nการดึงออกมาเองตอนนี้ ทำให้จำได้นานกว่าการอ่านซ้ำหลายเท่า', style: TextStyle(color: _dim, height: 1.6)),
          const SizedBox(height: 14),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextField(
                    controller: points[i],
                    style: const TextStyle(color: _ink, height: 1.5),
                    decoration: _dec('เรื่องสำคัญข้อ ${i + 1}'),
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 400,
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'ทำเป็นการ์ดทวนจำ',
                  child: IconButton(
                    onPressed: () => setState(() => makeCard[i] = !makeCard[i]),
                    icon: Icon(makeCard[i] ? Icons.style_rounded : Icons.style_outlined, color: makeCard[i] ? _sky : _dim),
                  ),
                ),
              ]),
            ),
          const Text('การ์ดสีฟ้า = จะทำเป็นการ์ดทวนจำ ให้ทวนพรุ่งนี้', style: TextStyle(color: _dim, fontSize: 12)),
          const SizedBox(height: 14),
          const Text('ยังสงสัยอะไรอยู่', style: TextStyle(color: _ink, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(controller: unclear, style: const TextStyle(color: _ink), decoration: _dec('ไว้ถามครูหรือเพื่อน'), maxLength: 300, minLines: 1, maxLines: 3),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(child: Text('จุดที่ขอบสมุด (ใจลอยกี่ครั้ง)', style: TextStyle(color: _ink, fontWeight: FontWeight.w500))),
            IconButton(onPressed: dots > 0 ? () => setState(() => dots--) : null, icon: const Icon(Icons.remove_circle_outline, color: _dim)),
            Text('$dots', style: const TextStyle(fontFamily: sans, fontSize: 20, color: _ink, fontWeight: FontWeight.w600)),
            IconButton(onPressed: () => setState(() => dots++), icon: const Icon(Icons.add_circle_outline, color: _dim)),
          ]),
          const SizedBox(height: 6),
          const Text('คาบนี้ใจอยู่กับห้องแค่ไหน', style: TextStyle(color: _ink, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _chips<int>([(1, '1'), (2, '2'), (3, '3'), (4, '4'), (5, '5')], focus, (v) => setState(() => focus = v)),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, style: _primary(), child: const Text('บันทึกคาบนี้')),
        ]),
      );

  Widget _done() {
    final n = points.where((c) => c.text.trim().isNotEmpty).length;
    return Column(key: const ValueKey(4), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      const Center(child: BuaNoi(mood: BuaMood.happy, size: 110)),
      const SizedBox(height: 14),
      Text(n == 3 ? 'จำได้ครบ 3 เรื่อง' : n > 0 ? 'จำได้ $n เรื่อง' : 'คาบนี้ผ่านไปแล้ว',
          textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 28, color: _ink, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(
        '${dots == 0 ? 'ไม่มีจุดที่ขอบสมุดเลย ใจอยู่กับห้องตลอด' : 'ใจลอย $dots ครั้ง และกลับมาได้ทุกครั้ง'}\n'
        '${makeCard.where((x) => x).isNotEmpty && n > 0 ? 'การ์ดทวนจำจะรอให้ทวนพรุ่งนี้ในแท็บลาน' : ''}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _dim, height: 1.6),
      ),
      const Spacer(),
      FilledButton(onPressed: () => Navigator.of(context).pop(), style: _primary(), child: const Text('เสร็จ')),
    ]);
  }
}
