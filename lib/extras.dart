import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'content.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Daily dhamma card: face down until tapped, then flips to show the teaching
// and a small mission for the day.
// ---------------------------------------------------------------------------
class DhammaCardView extends StatefulWidget {
  final Store store;
  const DhammaCardView({super.key, required this.store});
  @override
  State<DhammaCardView> createState() => _DhammaCardViewState();
}

class _DhammaCardViewState extends State<DhammaCardView> with SingleTickerProviderStateMixin {
  late final AnimationController flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  Map get _state => (widget.store.day(todayKey())['card'] as Map?) ?? const {};

  @override
  void initState() {
    super.initState();
    if (_state['open'] == true) flip.value = 1;
  }

  @override
  void dispose() {
    flip.dispose();
    super.dispose();
  }

  void _open() {
    if (flip.value > 0) return;
    HapticFeedback.mediumImpact();
    flip.forward();
    widget.store.mutate(todayKey(), (d) => d['card'] = {'open': true, 'done': false});
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final k = todayKey();
    final card = cardOfDay(dateOf(k).millisecondsSinceEpoch ~/ 864e5);
    final done = _state['done'] == true;
    return AnimatedBuilder(
      animation: flip,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(flip.value);
        final showFront = t >= .5;
        final angle = t * pi;
        return GestureDetector(
          onTap: _open,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..rotateY(showFront ? angle - pi : angle),
            child: Container(
              height: 196,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: showFront
                    ? null
                    : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF14212A), Color(0xFF2B4A46)]),
                color: showFront ? (done ? p.lotus.withValues(alpha: .1) : p.surface) : null,
                border: Border.all(color: showFront ? (done ? p.lotus : p.line) : const Color(0xFF3A5652)),
              ),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
              child: showFront ? _front(context, card, done) : _back(),
            ),
          ),
        );
      },
    );
  }

  Widget _back() => Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _CardBackPainter())),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('ไพ่ธรรมประจำวัน', style: TextStyle(fontFamily: serif, fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFF2EDE4))),
            SizedBox(height: 2),
            Text('แตะเพื่อเปิด', style: TextStyle(fontSize: 12.5, color: Color(0xFF93A59D), letterSpacing: .4)),
          ]),
        ),
      ]);

  Widget _front(BuildContext context, DhammaCard card, bool done) {
    final p = Pal.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Eyebrow('ไพ่ธรรม · ${cardTags[card.tag]}'),
        const Spacer(),
        if (done) Icon(Icons.spa_rounded, size: 18, color: p.lotus),
      ]),
      const SizedBox(height: 8),
      Text(card.teaching, style: display(context, 21)),
      const SizedBox(height: 6),
      Text(card.mission, style: TextStyle(fontSize: 15, height: 1.55, color: p.ink.withValues(alpha: .85))),
      const Spacer(),
      Align(
        alignment: Alignment.centerRight,
        child: done
            ? Text('ภารกิจวันนี้ สำเร็จแล้ว', style: TextStyle(color: p.lotus, fontWeight: FontWeight.w600, fontSize: 13.5))
            : TextButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.store.mutate(todayKey(), (d) => d['card'] = {'open': true, 'done': true});
                  toast(context, 'ภารกิจสำเร็จ ดอกบัวรับรู้');
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('ทำแล้ว'),
              ),
      ),
    ]);
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height * .36;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFE58BAB).withValues(alpha: .8);
    for (var r = 26.0; r <= 74; r += 16) {
      c.drawCircle(Offset(cx, cy), r, stroke..color = const Color(0xFF82BAB0).withValues(alpha: .18));
    }
    for (var i = -3; i <= 3; i++) {
      c.save();
      c.translate(cx, cy + 22);
      c.rotate(i * .32);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(-9, -14, -7, -30, 0, -42)
        ..cubicTo(7, -30, 9, -14, 0, 0);
      c.drawPath(path, Paint()..color = const Color(0xFFE58BAB).withValues(alpha: i == 0 ? .9 : .35 + .1 * (3 - i.abs())));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ---------------------------------------------------------------------------
// Three breaths: the smallest possible practice, about thirty seconds.
// ---------------------------------------------------------------------------
Future<void> openThreeBreaths(BuildContext context, Store store) => Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, _, _) => BreathPage(store: store, breaths: 3),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));

class BreathPage extends StatefulWidget {
  final Store store;
  final int breaths;
  final String? doneText;
  final VoidCallback? onDone;
  const BreathPage({super.key, required this.store, required this.breaths, this.doneText, this.onDone});
  @override
  State<BreathPage> createState() => _BreathPageState();
}

class _BreathPageState extends State<BreathPage> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 10));
  int n = 0;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    c.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      n++;
      HapticFeedback.lightImpact();
      if (n >= widget.breaths) {
        _finish();
      } else {
        c.forward(from: 0);
      }
      setState(() {});
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) c.forward();
    });
  }

  void _finish() {
    finished = true;
    HapticFeedback.heavyImpact();
    widget.store.mutate(todayKey(), (d) => (d['sessions'] as List).add({
          'id': newId(),
          'at': DateTime.now().toIso8601String(),
          'min': widget.breaths >= 6 ? widget.breaths ~/ 6 : 0,
          'wander': 0,
          'types': <String, int>{},
          'done': true,
          'kind': 'breath',
        }));
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFF2EDE4), dim = Color(0xFF93A59D), lotus = Color(0xFFE58BAB), pond = Color(0xFF82BAB0);
    return Scaffold(
      backgroundColor: const Color(0xFF0B1418),
      body: SafeArea(
        child: Stack(children: [
          if (widget.onDone == null)
            Positioned(
              right: 8,
              top: 4,
              child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: dim)),
            ),
          Center(
            child: AnimatedBuilder(
              animation: c,
              builder: (_, _) {
                final v = c.value;
                double ease(double x) => .5 - .5 * cos(pi * x);
                final scale = finished ? 1.0 : (v < .4 ? .55 + .45 * ease(v / .4) : 1 - .45 * ease((v - .4) / .6));
                final label = finished ? (widget.doneText ?? 'ลมหายใจกลับบ้านแล้ว') : (v < .4 ? 'หายใจเข้า' : 'ผ่อนลมออก');
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: Center(
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              lotus.withValues(alpha: finished ? .55 : .35),
                              pond.withValues(alpha: .18),
                              Colors.transparent,
                            ], stops: const [0, .6, 1]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(label, key: ValueKey(label), textAlign: TextAlign.center, style: const TextStyle(fontFamily: serif, fontSize: 26, color: ink, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Text(finished ? '' : '${thaiNum(min(n + 1, widget.breaths))} / ${thaiNum(widget.breaths)}',
                      style: const TextStyle(color: dim, fontSize: 15, letterSpacing: 2)),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The garden: one lotus for every day practised. A day with all five vows
// kept grows a golden lotus.
// ---------------------------------------------------------------------------
class LotusGarden extends StatelessWidget {
  final Store store;
  const LotusGarden({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final days = store.days.entries.where((e) => isActive(e.value)).toList()..sort((a, b) => a.key.compareTo(b.key));
    final gold = days.where((e) => pillarsOf(e.value).every((x) => x == 2)).length;
    final today = todayKey();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 210,
          width: double.infinity,
          child: CustomPaint(
            painter: _GardenPainter([
              for (final e in days) (e.key, pillarsOf(e.value).every((x) => x == 2), e.key == today),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        days.isEmpty
            ? 'สระยังว่าง ทุกวันที่ฝึก บัวหนึ่งดอกจะผุดขึ้น'
            : 'บัว ${thaiNum(days.length)} ดอก${gold > 0 ? ' · บัวทอง ${thaiNum(gold)}' : ''} · วันที่ทำครบ 5 อย่าง บัวจะเป็นสีทอง',
        style: TextStyle(color: p.muted, fontSize: 13),
      ),
    ]);
  }
}

class _GardenPainter extends CustomPainter {
  final List<(String, bool, bool)> lotuses;
  _GardenPainter(this.lotuses);

  static const _cols = 9, _rows = 5;
  static final List<(int, int)> _cells = [
    for (var r = 0; r < _rows; r++)
      for (var c = 0; c < _cols; c++) (c, r)
  ]..sort((a, b) {
      double d((int, int) p) => pow((p.$1 - (_cols - 1) / 2) / _cols, 2) + pow((p.$2 - (_rows - 1) / 2) / _rows, 2).toDouble();
      return d(a).compareTo(d(b));
    });

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B3041), Color(0xFF0C1722)])
              .createShader(Offset.zero & s));
    // gentle water lines
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .05)
      ..strokeWidth = 1;
    for (var y = 18.0; y < s.height; y += 22) {
      c.drawLine(Offset(0, y), Offset(s.width, y + 4), line);
    }
    for (var i = 0; i < lotuses.length; i++) {
      final (key, gold, isToday) = lotuses[i];
      final h = key.hashCode & 0x7fffffff;
      final rnd = Random(h);
      // fill a loose grid from the middle of the pond outward
      final (col, row) = _cells[i % _cells.length];
      final x = (col + .5 + (rnd.nextDouble() - .5) * .7) / _cols * s.width;
      final y = 30 + (row + .5 + (rnd.nextDouble() - .5) * .6) / _rows * (s.height - 40);
      final sc = .75 + rnd.nextDouble() * .4;
      _lotus(c, Offset(x, y), sc, gold, isToday);
    }
  }

  void _lotus(Canvas c, Offset o, double sc, bool gold, bool today) {
    c.drawOval(Rect.fromCenter(center: o.translate(0, 4 * sc), width: 34 * sc, height: 8 * sc),
        Paint()..color = const Color(0xFF2B4E46));
    if (today) {
      c.drawCircle(o.translate(0, -6 * sc), 20 * sc,
          Paint()..color = (gold ? const Color(0xFFF2C45C) : const Color(0xFFE58BAB)).withValues(alpha: .18));
    }
    final c0 = gold ? const Color(0xFFE0A93B) : const Color(0xFFE58BAB);
    final c1 = gold ? const Color(0xFFFBE7B0) : const Color(0xFFFAD3E0);
    for (final a in const [-.9, .9, -.45, .45, 0.0]) {
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(a);
      final len = 16 * sc, wid = 6 * sc;
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(-wid, -len * .35, -wid * .6, -len * .85, 0, -len)
        ..cubicTo(wid * .6, -len * .85, wid, -len * .35, 0, 0);
      c.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c1, c0])
                .createShader(Rect.fromLTWH(-wid, -len, wid * 2, len)));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GardenPainter old) => old.lotuses.length != lotuses.length || old.lotuses != lotuses;
}

// ---------------------------------------------------------------------------
// First launch: name, the five vows, and a first minute of breathing.
// ---------------------------------------------------------------------------
Future<void> openOnboarding(BuildContext context, Store store) => Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => OnboardingPage(store: store),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));

class OnboardingPage extends StatefulWidget {
  final Store store;
  const OnboardingPage({super.key, required this.store});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final pages = PageController();
  final name = TextEditingController();
  late final goals = [for (var i = 0; i < vows.length; i++) TextEditingController(text: vows[i].goal)];
  int page = 0;

  static const ink = Color(0xFFF2EDE4), dim = Color(0xFF93A59D), lotus = Color(0xFFE58BAB);

  void _next() {
    FocusScope.of(context).unfocus();
    pages.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  }

  Future<void> _saveAndBreathe() async {
    final prefs = widget.store.prefs;
    if (name.text.trim().isNotEmpty) await prefs.setString('name', name.text.trim());
    for (var i = 0; i < vows.length; i++) {
      final t = goals[i].text.trim();
      if (t.isNotEmpty && t != vows[i].goal) await prefs.setString('goal-$i', t);
    }
    if (!mounted) return;
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => BreathPage(
        store: widget.store,
        breaths: 6,
        doneText: 'ลมหายใจแรก\nบนหนทางนี้',
        onDone: () => Future.delayed(const Duration(milliseconds: 2200), () {
          if (mounted) Navigator.of(context).pop();
        }),
      ),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
    if (mounted) _next();
  }

  Future<void> _finish() async {
    final prefs = widget.store.prefs;
    await prefs.setBool('onboarded', true);
    await prefs.setString('ritual-day', todayKey());
    widget.store.touch();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1418),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: PageView(
          controller: pages,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => page = i),
          children: [
            _frame(
              top: const SizedBox(height: 60),
              body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ฝึกตน', style: TextStyle(fontFamily: serif, fontSize: 52, fontWeight: FontWeight.w600, color: ink)),
                const SizedBox(height: 16),
                for (final l in creed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(l.replaceAll('\n', ' '), style: const TextStyle(fontFamily: serif, fontSize: 17, height: 1.5, color: dim)),
                  ),
              ]),
              action: 'เริ่มเดินทาง',
              onAction: _next,
            ),
            _frame(
              body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ชื่อของคุณ', style: TextStyle(fontFamily: serif, fontSize: 34, height: 1.35, fontWeight: FontWeight.w600, color: ink)),
                const SizedBox(height: 24),
                TextField(
                  controller: name,
                  autofocus: false,
                  style: const TextStyle(fontSize: 22, color: ink),
                  cursorColor: lotus,
                  decoration: const InputDecoration(
                    hintText: 'ชื่อของคุณ',
                    hintStyle: TextStyle(color: Color(0xFF51635D)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E4440))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: lotus)),
                  ),
                ),
              ]),
              action: 'ถัดไป',
              onAction: _next,
            ),
            _frame(
              body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ห้าสิ่งที่ตั้งใจ', style: TextStyle(fontFamily: serif, fontSize: 34, fontWeight: FontWeight.w600, color: ink)),
                const SizedBox(height: 4),
                const Text('เขียนเป้าหมายด้วยคำของคุณเอง แก้ภายหลังได้เสมอ', style: TextStyle(color: dim)),
                const SizedBox(height: 14),
                for (var i = 0; i < vows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 104,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(vows[i].vow, style: const TextStyle(fontFamily: serif, fontSize: 17, fontWeight: FontWeight.w600, color: lotus)),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: goals[i],
                          maxLines: 2,
                          minLines: 1,
                          style: const TextStyle(color: ink, fontSize: 14.5),
                          cursorColor: lotus,
                          decoration: const InputDecoration(
                            isDense: true,
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E4440))),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: lotus)),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ]),
              action: 'ถัดไป',
              onAction: _next,
            ),
            _frame(
              body: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ก้าวแรก', style: TextStyle(fontFamily: serif, fontSize: 34, fontWeight: FontWeight.w600, color: ink)),
                SizedBox(height: 12),
                Text('1 นาที 6 ลมหายใจ\nหายใจไปพร้อมกับวงกลม\nเข้า 4 วินาที ออก 6 วินาที',
                    style: TextStyle(fontSize: 18, height: 1.7, color: dim)),
              ]),
              action: 'หายใจด้วยกัน',
              onAction: _saveAndBreathe,
            ),
            _frame(
              body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.spa_rounded, color: lotus, size: 48),
                const SizedBox(height: 16),
                Text('กลีบแรกบานแล้ว${name.text.trim().isEmpty ? '' : '\n${name.text.trim()}'}',
                    style: const TextStyle(fontFamily: serif, fontSize: 32, height: 1.4, fontWeight: FontWeight.w600, color: ink)),
                const SizedBox(height: 14),
                const Text('ทุกเช้า กลับมาตั้งใจด้วยกันนะ\nทุกวันที่ฝึก บัวหนึ่งดอกจะผุดขึ้นในสระของคุณ',
                    style: TextStyle(fontSize: 16, height: 1.7, color: dim)),
              ]),
              action: 'เข้าสู่สระบัว',
              onAction: _finish,
            ),
          ],
        ),
      ),
    );
  }

  Widget _frame({Widget? top, required Widget body, required String action, required VoidCallback onAction}) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: i <= page ? lotus : const Color(0xFF2E4440),
                ),
              ),
          ]),
          if (top != null) top else const SizedBox(height: 40),
          Expanded(child: SingleChildScrollView(child: body)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: lotus,
              foregroundColor: const Color(0xFF0B1418),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: Text(action),
          ),
        ]),
      );
}
