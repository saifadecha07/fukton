import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'iq.dart';
import 'mascot.dart';
import 'store.dart';
import 'theme.dart';

// Five short practices dressed as games. Each one trains something real:
// counting breaths (mindfulness), pink/gold lotus (stopping before acting),
// reading hearts (EQ), lotus path (working memory), body check-in (body awareness).

const _bg = Color(0xFF0B1418);
const _ink = Color(0xFFF2EDE4);
const _dim = Color(0xFF93A59D);
const _lotus = Color(0xFFE58BAB);
const _gold = Color(0xFFE0B54A);
const _pond = Color(0xFF82BAB0);

class GameInfo {
  final String id, name, trains, how;
  final IconData icon;
  final Color color;
  const GameInfo(this.id, this.name, this.trains, this.how, this.icon, this.color);
}

const gameList = <GameInfo>[
  GameInfo('breath', 'นับลมหายใจ', 'ฝึกสติ · รู้ตัวต่อเนื่อง', 'แตะทุกครั้งที่หายใจออก นับ 1 ถึง 8 ในใจ ลมที่ 9 ให้แตะปุ่มดอกบัว ห้ามดูตัวเลข เพราะไม่มีให้ดู', Icons.air_rounded, _pond),
  GameInfo('gonogo', 'บัวชมพู บัวทอง', 'ฝึกยั้งใจ · หยุดก่อนกด', 'บัวชมพูโผล่ ให้แตะทันที บัวทองโผล่ ห้ามแตะ เหมือนตอนอยากเล่นเกม แล้วหยุดตัวเองได้', Icons.local_florist_rounded, _lotus),
  GameInfo('eq', 'อ่านใจ', 'ฝึก EQ · เข้าใจอารมณ์', 'อ่านเรื่องที่เกิดขึ้น เรียกชื่ออารมณ์ให้ถูก แล้วเลือกทางตอบที่ใจเย็นและฉลาด', Icons.favorite_rounded, Color(0xFFE8857A)),
  GameInfo('memory', 'จำทางดอกบัว', 'ฝึกสมาธิ · ความจำ', 'ดอกบัวสว่างทีละดอก จำลำดับไว้ แล้วแตะตาม ยิ่งผ่านยิ่งยาวขึ้น', Icons.grid_view_rounded, _gold),
  GameInfo('body', 'รู้กาย', 'ฝึกรู้สึกตัวทางกาย', 'สำรวจว่ากายตรงไหนรู้สึกอะไร แล้วส่งลมหายใจไปตรงนั้น', Icons.accessibility_new_rounded, Color(0xFF8B93D9)),
  // thinking practice
  GameInfo('puzzle', 'ไขปริศนา', 'ฝึกคิดเป็นเหตุผล · หากฎ', '', Icons.extension_rounded, Color(0xFF6FA8DC)),
  GameInfo('math', 'คิดเร็ว', 'ฝึกความเร็วในการคิด', '', Icons.calculate_rounded, Color(0xFF5FB3A6)),
  GameInfo('recall', 'การ์ดทวนจำ', 'จำบทเรียนได้นาน', '', Icons.style_rounded, Color(0xFFB48BD9)),
];

const mindGames = 5; // the first five train the heart; the rest train thinking

Future<void> openGame(BuildContext context, Store store, String id) => Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => switch (id) {
        'breath' => BreathCountGame(store: store),
        'gonogo' => LotusGoNoGo(store: store),
        'eq' => ReadHeartsGame(store: store),
        'memory' => LotusMemoryGame(store: store),
        'puzzle' => PuzzleGame(store: store),
        'math' => MathGame(store: store),
        'recall' => RecallPage(store: store),
        _ => BodyCheckGame(store: store),
      },
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));

void _record(Store store, String game, int score, [Map<String, dynamic>? extra]) =>
    store.mutate(todayKey(), (d) => (d['games'] as List).add({
          'id': newId(),
          't': DateTime.now().toIso8601String(),
          'game': game,
          'score': score,
          ...?extra,
        }));

int playsToday(Store s) => items(s.day(todayKey()), 'games').length;

ButtonStyle _primary() => FilledButton.styleFrom(
      backgroundColor: _lotus,
      foregroundColor: _bg,
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
    );

/// Shared frame: dark page, close button, and an intro → play → result flow.
class _GameFrame extends StatelessWidget {
  final GameInfo info;
  final Widget child;
  const _GameFrame({required this.info, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(info.icon, color: info.color, size: 20),
                const SizedBox(width: 8),
                Text(info.name, style: const TextStyle(fontFamily: cute, fontSize: 18, color: _ink, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: _dim)),
              ]),
              Expanded(child: child),
            ]),
          ),
        ),
      );
}

Widget _intro(GameInfo info, VoidCallback start) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      Center(child: Icon(info.icon, color: info.color, size: 72)),
      const SizedBox(height: 18),
      Text(info.trains, textAlign: TextAlign.center, style: TextStyle(color: info.color, fontSize: 14, letterSpacing: .4)),
      const SizedBox(height: 10),
      Text(info.how, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 17, height: 1.7)),
      const Spacer(),
      FilledButton(onPressed: start, style: _primary(), child: const Text('เริ่ม')),
    ]);

Widget _result(BuildContext context, {required String big, required String title, required String note, required Store store, VoidCallback? again}) {
  final plays = playsToday(store);
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Spacer(),
    const Center(child: BuaNoi(mood: BuaMood.happy, size: 110)),
    const SizedBox(height: 14),
    Text(big, textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 52, fontWeight: FontWeight.w600, color: _ink, height: 1.1)),
    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 20, color: _lotus, fontWeight: FontWeight.w600)),
    const SizedBox(height: 10),
    Text(note, textAlign: TextAlign.center, style: const TextStyle(color: _dim, fontSize: 15, height: 1.6)),
    const Spacer(),
    if (plays >= 3)
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('วันนี้ฝึกในลานครบ 3 รอบแล้ว\nลองเอาใจที่ฝึกไปใช้กับชีวิตจริงดูนะ', textAlign: TextAlign.center, style: TextStyle(color: _pond, fontSize: 14, height: 1.5)),
      ),
    FilledButton(onPressed: () => Navigator.of(context).pop(), style: _primary(), child: const Text('กลับสู่ลาน')),
    if (again != null) TextButton(onPressed: again, child: const Text('เล่นอีกรอบ', style: TextStyle(color: _dim))),
  ]);
}

// ===========================================================================
// 1. นับลมหายใจ — breath counting (a research measure of mindfulness)
// ===========================================================================
class BreathCountGame extends StatefulWidget {
  final Store store;
  const BreathCountGame({super.key, required this.store});
  @override
  State<BreathCountGame> createState() => _BreathCountGameState();
}

class _BreathCountGameState extends State<BreathCountGame> {
  static const rounds = 5;
  int phase = 0; // 0 intro, 1 play, 2 result
  int c = 0, correct = 0, missed = 0, lost = 0;
  String flash = '';
  double pulse = 0;

  int get done => correct + missed + lost;

  void _event(String msg, {bool good = false}) {
    setState(() {
      flash = msg;
      pulse = good ? 1 : .4;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => flash = '');
    });
    if (done >= rounds) {
      _record(widget.store, 'breath', (correct * 100 / rounds).round(), {'correct': correct});
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => phase = 2);
      });
    }
  }

  void _exhale() {
    HapticFeedback.selectionClick();
    c++;
    setState(() => pulse = .25);
    if (c >= 9) {
      c = 0;
      missed++;
      _event('เลยลมที่ 9 ไปแล้ว ไม่เป็นไร เริ่มนับ 1 ใหม่');
    }
  }

  void _ninth() {
    if (c == 8) {
      HapticFeedback.mediumImpact();
      correct++;
      c = 0;
      _event('ครบ 9 พอดี ใจอยู่กับลม', good: true);
    } else {
      HapticFeedback.lightImpact();
      missed++;
      c = 0;
      _event('ยังไม่ถึงลมที่ 9 นะ เริ่ม 1 ใหม่');
    }
  }

  void _lost() {
    lost++;
    c = 0;
    _event('รู้ว่าหลงนับ ก็คือมีสติแล้ว เริ่ม 1 ใหม่');
  }

  @override
  Widget build(BuildContext context) {
    final info = gameList[0];
    return _GameFrame(
      info: info,
      child: switch (phase) {
        0 => _intro(info, () => setState(() => phase = 1)),
        1 => Column(children: [
            const SizedBox(height: 8),
            Text('รอบที่ ${min(done + 1, rounds)} จาก $rounds', style: const TextStyle(color: _dim)),
            const Text('หายใจตามธรรมชาติ ไม่ต้องรีบ', style: TextStyle(color: _dim, fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: _exhale,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pulse),
                duration: const Duration(milliseconds: 350),
                onEnd: () => setState(() => pulse = 0),
                builder: (_, v, _) => Container(
                  width: 230,
                  height: 230,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _pond.withValues(alpha: .1 + .2 * v),
                    border: Border.all(color: _pond.withValues(alpha: .5 + .5 * v), width: 2),
                  ),
                  child: const Text('ลมออก', style: TextStyle(fontFamily: cute, fontSize: 30, color: _ink, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 44,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(flash, key: ValueKey(flash), textAlign: TextAlign.center, style: const TextStyle(color: _lotus, fontSize: 15)),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _ninth,
              style: _primary(),
              icon: const Icon(Icons.local_florist_rounded),
              label: const Text('ลมที่ 9'),
            ),
            TextButton(onPressed: _lost, child: const Text('หลงนับไปแล้ว', style: TextStyle(color: _dim))),
          ]),
        _ => _result(context,
            big: '$correct/$rounds',
            title: correct >= 4 ? 'ใจอยู่กับลมดีมาก' : correct >= 2 ? 'ใจเริ่มนิ่งแล้ว' : 'ทุกรอบที่รู้ว่าหลง คือการฝึก',
            note: 'หลงนับ $lost ครั้ง · นับคลาด $missed ครั้ง\nใจที่ลอยไปไม่ใช่ความล้มเหลว การรู้ตัวว่าลอยต่างหากคือสติ',
            store: widget.store,
            again: () => setState(() {
                  phase = 1;
                  c = correct = missed = lost = 0;
                })),
      },
    );
  }
}

// ===========================================================================
// 2. บัวชมพู บัวทอง — go / no-go (stop before you tap)
// ===========================================================================
class LotusGoNoGo extends StatefulWidget {
  final Store store;
  const LotusGoNoGo({super.key, required this.store});
  @override
  State<LotusGoNoGo> createState() => _LotusGoNoGoState();
}

class _Bloom {
  final Offset at; // 0..1
  final bool gold;
  final int born;
  bool tapped = false;
  _Bloom(this.at, this.gold, this.born);
}

class _LotusGoNoGoState extends State<LotusGoNoGo> with SingleTickerProviderStateMixin {
  static const playMs = 45000;
  int phase = 0;
  late final Ticker _ticker = createTicker(_tick);
  int now = 0, nextSpawn = 0;
  final blooms = <_Bloom>[];
  final rnd = Random();
  int hits = 0, misses = 0, falseTaps = 0, golds = 0, pinks = 0;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      phase = 1;
      blooms.clear();
      hits = misses = falseTaps = golds = pinks = 0;
      now = 0;
      nextSpawn = 600;
    });
    _ticker.start();
  }

  void _tick(Duration e) {
    now = e.inMilliseconds;
    final life = (1100 - now / playMs * 350).round(); // gets a little faster
    blooms.removeWhere((b) {
      if (now - b.born > life) {
        if (!b.gold && !b.tapped) misses++;
        return true;
      }
      return b.tapped && now - b.born > 220;
    });
    if (now >= nextSpawn && now < playMs - 800) {
      final gold = rnd.nextDouble() < .27;
      gold ? golds++ : pinks++;
      blooms.add(_Bloom(Offset(.12 + rnd.nextDouble() * .76, .08 + rnd.nextDouble() * .8), gold, now));
      nextSpawn = now + (780 - now / playMs * 260).round() + rnd.nextInt(220);
    }
    if (now >= playMs) {
      _ticker.stop();
      final inhibit = golds == 0 ? 100 : ((golds - falseTaps) * 100 / golds).round();
      _record(widget.store, 'gonogo', inhibit, {'hits': hits, 'false': falseTaps});
      phase = 2;
    }
    setState(() {});
  }

  void _tap(_Bloom b) {
    if (b.tapped) return;
    b.tapped = true;
    if (b.gold) {
      falseTaps++;
      HapticFeedback.heavyImpact();
    } else {
      hits++;
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = gameList[1];
    return _GameFrame(
      info: info,
      child: switch (phase) {
        0 => _intro(info, _start),
        1 => Column(children: [
            LinearProgressIndicator(value: (now / playMs).clamp(0, 1), color: _lotus, backgroundColor: _dim.withValues(alpha: .2)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('ชมพู $hits', style: const TextStyle(color: _lotus)),
              const SizedBox(width: 18),
              Text('ทองที่เผลอแตะ $falseTaps', style: const TextStyle(color: _gold)),
            ]),
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) => Stack(children: [
                  for (final b in blooms)
                    Positioned(
                      left: b.at.dx * (box.maxWidth - 80),
                      top: b.at.dy * (box.maxHeight - 80),
                      child: GestureDetector(
                        onTapDown: (_) => _tap(b),
                        child: AnimatedScale(
                          scale: b.tapped ? 1.35 : 1,
                          duration: const Duration(milliseconds: 180),
                          child: AnimatedOpacity(
                            opacity: b.tapped ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: CustomPaint(size: const Size(80, 80), painter: _BloomPainter(b.gold)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        _ => _result(context,
            big: golds == 0 ? '100%' : '${((golds - falseTaps) * 100 / golds).round()}%',
            title: falseTaps == 0 ? 'ยั้งใจได้ทุกครั้ง' : 'ยั้งใจได้ ${golds - falseTaps} จาก $golds ครั้ง',
            note: 'แตะบัวชมพูทัน $hits จาก $pinks ดอก\nช่วงเสี้ยววินาทีที่หยุดมือได้ คือกล้ามเนื้อเดียวกับที่ใช้หยุดตัวเองตอนอยากเล่นเกม',
            store: widget.store,
            again: _start),
      },
    );
  }
}

class _BloomPainter extends CustomPainter {
  final bool gold;
  _BloomPainter(this.gold);
  @override
  void paint(Canvas c, Size s) {
    final o = Offset(s.width / 2, s.height * .72);
    final c0 = gold ? const Color(0xFFE0A93B) : const Color(0xFFE77FA3);
    final c1 = gold ? const Color(0xFFFBE7B0) : const Color(0xFFFAD3E0);
    c.drawCircle(o.translate(0, -14), 34, Paint()..color = c0.withValues(alpha: .15));
    for (final a in const [-1.0, 1.0, -.5, .5, 0.0]) {
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(a);
      final p = Path()
        ..moveTo(0, 0)
        ..cubicTo(-11, -14, -9, -32, 0, -42)
        ..cubicTo(9, -32, 11, -14, 0, 0);
      c.drawPath(p, Paint()..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c1, c0]).createShader(const Rect.fromLTWH(-11, -42, 22, 42)));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BloomPainter old) => old.gold != gold;
}

// ===========================================================================
// 3. อ่านใจ — name the feeling, then choose the wise response (EQ)
// ===========================================================================
class _Scene {
  final String story;
  final List<String> feelings;
  final int feeling;
  final String feelingNote;
  final List<(String, String)> answers; // (response, feedback)
  final int best;
  const _Scene(this.story, this.feelings, this.feeling, this.feelingNote, this.answers, this.best);
}

const _scenes = <_Scene>[
  _Scene('เพื่อนแซวเรื่องหน้าตาเรากลางวง ทุกคนหัวเราะ', ['อายปนโกรธ', 'ดีใจ', 'เฉย ๆ'], 0, 'รู้สึกอายและโกรธเป็นเรื่องปกติ ไม่ต้องกดมันไว้ แค่รู้ว่ามันมา',
      [('ตอกกลับให้แรงกว่า', 'ได้สะใจแป๊บเดียว แต่ไฟลามทั้งวง'), ('เงียบ แล้วเก็บไปคิดทั้งคืน', 'ปิดไว้ข้างใน มันจะวนกลับมาตอนกลางคืน'), ('หายใจ ยิ้มเบา ๆ แล้วไปบอกเขาตอนอยู่กันสองคนว่าไม่ชอบ', 'ราชสีห์ไม่ตื่นเสียง ได้ยิน แต่เลือกตอบเอง')], 2),
  _Scene('ได้คะแนนสอบน้อยกว่าที่หวังไว้มาก', ['ผิดหวัง', 'ภูมิใจ', 'ตื่นเต้น'], 0, 'ความผิดหวังบอกว่าเราใส่ใจเรื่องนี้ นั่นเป็นสัญญาณที่ดี',
      [('บอกตัวเองว่าโง่ ไม่มีวันทำได้', 'การตำหนิตัวเองทำให้ไม่อยากลองอีก'), ('ดูว่าพลาดตรงไหน แล้ววางแผนอ่านทีละนิด', 'มองคะแนนเป็นข้อมูล ไม่ใช่คำตัดสินชีวิต'), ('เลิกสนใจวิชานี้ไปเลย', 'หนีวันนี้ ปัญหายังรออยู่พรุ่งนี้')], 1),
  _Scene('เพื่อนสนิทไม่ตอบแชทมาทั้งวัน ทั้งที่ออนไลน์อยู่', ['น้อยใจ กังวล', 'โล่งใจ', 'หิว'], 0, 'ใจมักแต่งเรื่องเติมเองเวลาไม่มีข้อมูล ลองแยกว่าอะไรคือความจริง อะไรคือความคิด',
      [('ส่งข้อความต่อว่ายาว ๆ', 'ยังไม่รู้เหตุผลเขาเลย อาจเสียเพื่อนเพราะเรื่องที่คิดไปเอง'), ('ถามสั้น ๆ ว่า “โอเคไหม วันนี้ยุ่งรึเปล่า”', 'ถามด้วยความห่วงใย ได้ความจริงโดยไม่ต้องเดา'), ('บล็อกไปเลย', 'ตัดก่อนจะรู้เรื่อง เสียดายมิตรภาพ')], 1),
  _Scene('พรุ่งนี้สอบ แต่ใจอยากเล่นเกมมาก', ['อยาก หงุดหงิด', 'เศร้า', 'ภูมิใจ'], 0, 'ความอยากเป็นคลื่น ขึ้นแรงแล้วก็ลดลงเอง',
      [('เล่นแค่ตาเดียว (แต่รู้ตัวว่ามักไม่ใช่ตาเดียว)', 'ใจมักต่อรองเสมอ ตาเดียวจึงกลายเป็นสามชั่วโมง'), ('ขยับมือหนึ่งรอบ แล้วอ่านก่อน 25 นาที ค่อยเล่นเป็นรางวัล', 'สายลมไม่ติดตาข่าย เห็นความอยาก แต่ไม่ถูกมันลากไป'), ('ลบเกมทิ้งด้วยความโมโห', 'ทำด้วยความโกรธ มักกลับไปลงใหม่ในคืนนั้น')], 1),
  _Scene('เลื่อนเห็นเพื่อนโพสต์เที่ยว ชีวิตดูดีไปหมด', ['อิจฉา ด้อยค่าตัวเอง', 'ง่วง', 'ขำ'], 0, 'เรากำลังเทียบเบื้องหลังของเรา กับฉากที่ดีที่สุดของคนอื่น',
      [('เลื่อนดูต่อไปเรื่อย ๆ', 'ยิ่งเลื่อน ยิ่งรู้สึกว่าชีวิตเราขาด'), ('ยินดีกับเขาในใจ แล้วปิดแอป ไปทำสิ่งเล็ก ๆ ที่เราชอบ', 'มุทิตาทำให้ใจเบา และเราได้เวลาคืนมา'), ('คอมเมนต์ประชด', 'ดอกบัวไม่แปดเปื้อน แต่การประชดคือการกระโดดลงโคลนเอง')], 1),
  _Scene('แม่โทรมาบ่นเรื่องผลการเรียน', ['หงุดหงิด เหนื่อยใจ', 'สนุก', 'หิว'], 0, 'ข้างใต้คำบ่น มักมีความห่วงที่พูดออกมาไม่เป็น',
      [('ตัดสายทิ้ง', 'ปัญหาไม่หาย และแม่จะยิ่งห่วง'), ('ฟังจนจบ แล้วบอกว่า “หนูรู้ว่าแม่ห่วง หนูกำลังพยายามอยู่”', 'ได้ทั้งความเข้าใจและความสงบ ภูเขาไม่สะท้านต่อลม'), ('เถียงกลับทุกประโยค', 'ทั้งสองฝ่ายเจ็บ และไม่มีใครฟังใคร')], 1),
  _Scene('เพื่อนในกลุ่มชวนแกล้งเพื่อนอีกคนให้อาย', ['ลำบากใจ', 'ภูมิใจ', 'ง่วง'], 0, 'ความลำบากใจคือเสียงของศีลที่บอกว่ามีอะไรไม่ถูก',
      [('ร่วมด้วยจะได้ไม่ถูกมองว่าไม่เข้าพวก', 'อยู่ในกลุ่มแลกกับการทำร้ายคนอื่น ใจจะไม่สะอาด'), ('ไม่ร่วม และเปลี่ยนเรื่องอย่างนุ่มนวล', 'บัวอยู่กลางน้ำแต่ไม่เปื้อน'), ('ไปฟ้องครูต่อหน้าทุกคนทันที', 'ตั้งใจดี แต่อาจทำให้เรื่องบานปลาย ลองคุยแบบส่วนตัวก่อน')], 1),
  _Scene('ทำงานกลุ่ม มีคนหนึ่งไม่ช่วยเลย', ['โมโห ไม่ยุติธรรม', 'ดีใจ', 'เฉย ๆ'], 0, 'ความรู้สึกไม่ยุติธรรมเป็นเรื่องจริง แต่วิธีพูดจะเป็นตัวกำหนดผล',
      [('ด่าในแชทกลุ่มให้ทุกคนเห็น', 'เขาจะอาย และป้องกันตัว แทนที่จะช่วย'), ('ทำแทนทั้งหมดแล้วเก็บความแค้นไว้', 'งานเสร็จ แต่ใจหนัก และเรื่องจะเกิดซ้ำ'), ('ทักไปส่วนตัว แบ่งงานชัด ๆ ให้เขาหนึ่งชิ้นพร้อมกำหนดส่ง', 'ชัดเจนและให้เกียรติกัน มิตรที่ดีพาเพื่อนไปด้วยกัน')], 2),
];

class ReadHeartsGame extends StatefulWidget {
  final Store store;
  const ReadHeartsGame({super.key, required this.store});
  @override
  State<ReadHeartsGame> createState() => _ReadHeartsGameState();
}

class _ReadHeartsGameState extends State<ReadHeartsGame> {
  late final List<_Scene> deck;
  int phase = 0, i = 0, step = 0, score = 0;
  int? picked;

  @override
  void initState() {
    super.initState();
    final seed = DateTime.now().millisecondsSinceEpoch ~/ 864e5;
    deck = (List.of(_scenes)..shuffle(Random(seed))).take(4).toList();
  }

  /// Options are shown in a shuffled order so the right answer is never always first.
  List<int> get _order {
    final n = step == 0 ? deck[i].feelings.length : deck[i].answers.length;
    return List.generate(n, (k) => k)..shuffle(Random(i * 31 + step * 7 + 5));
  }

  void _choose(int k) {
    if (picked != null) return;
    final s = deck[i];
    final good = step == 0 ? k == s.feeling : k == s.best;
    if (good) score++;
    HapticFeedback.selectionClick();
    setState(() => picked = k);
  }

  void _next() {
    setState(() {
      picked = null;
      if (step == 0) {
        step = 1;
      } else {
        step = 0;
        i++;
        if (i >= deck.length) {
          _record(widget.store, 'eq', (score * 100 / (deck.length * 2)).round());
          phase = 2;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = gameList[2];
    return _GameFrame(
      info: info,
      child: switch (phase) {
        0 => _intro(info, () => setState(() => phase = 1)),
        1 => _play(),
        _ => _result(context,
            big: '$score/${deck.length * 2}',
            title: score >= deck.length * 2 - 1 ? 'อ่านใจได้ลึกซึ้ง' : 'ใจเข้าใจโลกมากขึ้นอีกนิด',
            note: 'EQ ไม่ได้วัดว่าไม่เคยโกรธ\nแต่วัดว่าเมื่อโกรธแล้ว เราเลือกทางตอบได้ดีแค่ไหน',
            store: widget.store),
      },
    );
  }

  Widget _play() {
    final s = deck[i];
    final opts = step == 0 ? s.feelings : [for (final a in s.answers) a.$1];
    final best = step == 0 ? s.feeling : s.best;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('เรื่องที่ ${i + 1} จาก ${deck.length}', style: const TextStyle(color: _dim)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(20)),
          child: Text(s.story, style: const TextStyle(fontFamily: cute, fontSize: 21, height: 1.5, color: _ink, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 18),
        Text(step == 0 ? 'ตอนนั้น ใจน่าจะรู้สึกอะไร' : 'แล้วจะตอบสนองแบบไหนดี', style: const TextStyle(color: _lotus, fontSize: 15)),
        const SizedBox(height: 10),
        for (final k in _order)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _choose(k),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: picked == null
                      ? Colors.transparent
                      : k == best
                          ? _pond.withValues(alpha: .18)
                          : k == picked
                              ? _gold.withValues(alpha: .14)
                              : Colors.transparent,
                  border: Border.all(color: picked != null && k == best ? _pond : _dim.withValues(alpha: .4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(opts[k], style: const TextStyle(color: _ink, fontSize: 15.5, height: 1.5)),
                  if (picked != null && step == 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(s.answers[k].$2, style: TextStyle(color: k == best ? _pond : _dim, fontSize: 13.5, height: 1.5)),
                    ),
                ]),
              ),
            ),
          ),
        if (picked != null && step == 0)
          Text(s.feelingNote, style: const TextStyle(color: _pond, fontSize: 14, height: 1.6)),
        const SizedBox(height: 14),
        if (picked != null) FilledButton(onPressed: _next, style: _primary(), child: const Text('ต่อไป')),
      ]),
    );
  }
}

// ===========================================================================
// 4. จำทางดอกบัว — remember the order the lotuses light up
// ===========================================================================
class LotusMemoryGame extends StatefulWidget {
  final Store store;
  const LotusMemoryGame({super.key, required this.store});
  @override
  State<LotusMemoryGame> createState() => _LotusMemoryGameState();
}

class _LotusMemoryGameState extends State<LotusMemoryGame> {
  int phase = 0;
  final rnd = Random();
  List<int> seq = [];
  int lit = -1, inputAt = 0, best = 0;
  bool showing = false;
  String msg = '';

  Future<void> _round(int len) async {
    seq = [for (var k = 0; k < len; k++) rnd.nextInt(9)];
    inputAt = 0;
    setState(() {
      showing = true;
      msg = 'ดูให้ดี…';
    });
    await Future.delayed(const Duration(milliseconds: 700));
    for (final s in seq) {
      if (!mounted) return;
      setState(() => lit = s);
      await Future.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      setState(() => lit = -1);
      await Future.delayed(const Duration(milliseconds: 180));
    }
    if (mounted) {
      setState(() {
        showing = false;
        msg = 'แตะตามลำดับ';
      });
    }
  }

  void _tap(int k) async {
    if (showing || phase != 1) return;
    setState(() => lit = k);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => lit = -1);
    });
    if (seq[inputAt] != k) {
      HapticFeedback.heavyImpact();
      _record(widget.store, 'memory', best);
      setState(() => phase = 2);
      return;
    }
    HapticFeedback.selectionClick();
    inputAt++;
    if (inputAt == seq.length) {
      best = seq.length;
      setState(() => msg = 'ถูกต้อง!');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _round(seq.length + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = gameList[3];
    return _GameFrame(
      info: info,
      child: switch (phase) {
        0 => _intro(info, () {
            setState(() {
              phase = 1;
              best = 0;
            });
            _round(3);
          }),
        1 => Column(children: [
            const SizedBox(height: 10),
            Text('ความยาว ${seq.length}', style: const TextStyle(color: _dim)),
            Text(msg, style: const TextStyle(fontFamily: cute, fontSize: 22, color: _ink, fontWeight: FontWeight.w600)),
            const Spacer(),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.count(
                crossAxisCount: 3,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                children: [
                  for (var k = 0; k < 9; k++)
                    GestureDetector(
                      onTapDown: (_) => _tap(k),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: lit == k ? _gold.withValues(alpha: .35) : const Color(0xFF2B4E46),
                          boxShadow: lit == k ? [BoxShadow(color: _gold.withValues(alpha: .6), blurRadius: 24)] : null,
                        ),
                        child: CustomPaint(painter: _BloomPainter(lit == k)),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
          ]),
        _ => _result(context,
            big: '$best',
            title: best >= 7 ? 'สมาธิคมกริบ' : best >= 5 ? 'ใจจดจ่อได้ดี' : 'ฝึกบ่อย ๆ ใจจะนิ่งขึ้น',
            note: 'จำได้ยาวที่สุด $best ดอก\nความจำสั้นต้องอาศัยใจที่ไม่วอกแวก ยิ่งใจนิ่ง ยิ่งจำได้ยาว',
            store: widget.store,
            again: () {
              setState(() {
                phase = 1;
                best = 0;
              });
              _round(3);
            }),
      },
    );
  }
}

// ===========================================================================
// 5. รู้กาย — body check-in, then breathe into what you found
// ===========================================================================
class BodyCheckGame extends StatefulWidget {
  final Store store;
  const BodyCheckGame({super.key, required this.store});
  @override
  State<BodyCheckGame> createState() => _BodyCheckGameState();
}

class _BodyCheckGameState extends State<BodyCheckGame> with SingleTickerProviderStateMixin {
  static const parts = ['ศีรษะ', 'หน้า · กราม', 'คอ · บ่า', 'อก', 'ท้อง', 'แขน · มือ', 'ขา · เท้า'];
  static const feels = ['ตึง', 'ร้อน', 'เย็น', 'หนัก', 'เบา', 'สบาย', 'ปวด', 'ไม่รู้สึก'];
  int phase = 0;
  int part = 0;
  final found = <String, String>{};
  late final AnimationController breath = AnimationController(vsync: this, duration: const Duration(seconds: 10));
  int breaths = 0;

  @override
  void initState() {
    super.initState();
    breath.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      breaths++;
      HapticFeedback.lightImpact();
      if (breaths >= 3) {
        _record(widget.store, 'body', found.length, {'found': found});
        setState(() => phase = 3);
      } else {
        breath.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    breath.dispose();
    super.dispose();
  }

  void _pick(String f) {
    HapticFeedback.selectionClick();
    setState(() {
      found[parts[part]] = f;
      if (part < parts.length - 1) {
        part++;
      } else {
        phase = 2;
        breaths = 0;
        breath.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = gameList[4];
    final strongest = found.entries.where((e) => e.value != 'สบาย' && e.value != 'ไม่รู้สึก' && e.value != 'เบา').map((e) => e.key).toList();
    return _GameFrame(
      info: info,
      child: switch (phase) {
        0 => _intro(info, () => setState(() => phase = 1)),
        1 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (part + 1) / parts.length, color: info.color, backgroundColor: _dim.withValues(alpha: .2)),
            const SizedBox(height: 20),
            const Text('หลับตาสักครู่ แล้วรู้สึกที่', textAlign: TextAlign.center, style: TextStyle(color: _dim)),
            Text(parts[part], textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 40, color: _ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Center(child: CustomPaint(size: const Size(120, 190), painter: _BodyPainter(part, info.color))),
            const Spacer(),
            const Text('ตรงนั้นรู้สึกอย่างไร', textAlign: TextAlign.center, style: TextStyle(color: _dim)),
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              for (final f in feels)
                ActionChip(
                  label: Text(f),
                  onPressed: () => _pick(f),
                  backgroundColor: Colors.transparent,
                  labelStyle: const TextStyle(color: _ink),
                  side: BorderSide(color: _dim.withValues(alpha: .5)),
                ),
            ]),
            const SizedBox(height: 10),
          ]),
        2 => Column(children: [
            const SizedBox(height: 10),
            Text(strongest.isEmpty ? 'ทั้งกายดูสบายดี' : 'ส่งลมหายใจไปที่ ${strongest.take(2).join(' และ ')}',
                textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 22, color: _ink, fontWeight: FontWeight.w600)),
            const Text('หายใจเข้า นึกภาพลมไหลไปตรงนั้น\nหายใจออก ปล่อยให้มันคลาย', textAlign: TextAlign.center, style: TextStyle(color: _dim, height: 1.6)),
            const Spacer(),
            AnimatedBuilder(
              animation: breath,
              builder: (_, _) {
                final v = breath.value;
                double ease(double x) => .5 - .5 * cos(pi * x);
                final sc = v < .4 ? .6 + .4 * ease(v / .4) : 1 - .4 * ease((v - .4) / .6);
                return Transform.scale(
                  scale: sc,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [info.color.withValues(alpha: .4), Colors.transparent])),
                  ),
                );
              },
            ),
            Text('${min(breaths + 1, 3)} / 3', style: const TextStyle(color: _dim, letterSpacing: 2)),
            const Spacer(),
          ]),
        _ => _result(context,
            big: '${found.length}',
            title: 'รู้กายครบทุกส่วน',
            note: '${found.entries.map((e) => '${e.key}: ${e.value}').join('  ·  ')}'
                '\n\nกายมักรู้ก่อนใจ ความตึงที่บ่า ความแน่นที่อก คือสัญญาณแรกของความเครียด',
            store: widget.store),
      },
    );
  }
}

class _BodyPainter extends CustomPainter {
  final int part;
  final Color color;
  _BodyPainter(this.part, this.color);
  @override
  void paint(Canvas c, Size s) {
    final base = Paint()..color = Colors.white.withValues(alpha: .12);
    final hi = Paint()..color = color.withValues(alpha: .85);
    Paint p(int i) => i == part ? hi : base;
    final cx = s.width / 2;
    c.drawCircle(Offset(cx, 18), 15, p(0)); // head
    c.drawOval(Rect.fromCenter(center: Offset(cx, 30), width: 20, height: 10), p(1)); // face/jaw
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, 46), width: 50, height: 10), const Radius.circular(5)), p(2)); // neck & shoulders
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, 68), width: 42, height: 30), const Radius.circular(10)), p(3)); // chest
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, 97), width: 38, height: 26), const Radius.circular(10)), p(4)); // belly
    for (final dx in const [-31.0, 31.0]) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + dx, 80), width: 11, height: 60), const Radius.circular(6)), p(5)); // arms
    }
    for (final dx in const [-10.0, 10.0]) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + dx, 150), width: 14, height: 70), const Radius.circular(7)), p(6)); // legs
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) => old.part != part;
}
