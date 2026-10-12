import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mascot.dart';
import 'store.dart';
import 'theme.dart';

// ฝึกคิด — thinking practice that actually helps study:
// pattern reasoning, quick mental arithmetic, and spaced-repetition recall
// cards filled with the reader's own lessons.

const _bg = Color(0xFF0B1418);
const _ink = Color(0xFFF2EDE4);
const _dim = Color(0xFF93A59D);
const _lotus = Color(0xFFE58BAB);
const _pond = Color(0xFF82BAB0);
const _sky = Color(0xFF6FA8DC);

ButtonStyle _primary() => FilledButton.styleFrom(
      backgroundColor: _lotus,
      foregroundColor: _bg,
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
    );

void _record(Store store, String game, int score) => store.mutate(todayKey(), (d) => (d['games'] as List).add({
      'id': newId(),
      't': DateTime.now().toIso8601String(),
      'game': game,
      'score': score,
    }));

Widget _frame(BuildContext context, String title, IconData icon, Widget child) => Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, color: _sky, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontFamily: cute, fontSize: 18, color: _ink, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: _dim)),
            ]),
            Expanded(child: child),
          ]),
        ),
      ),
    );

Widget _done(BuildContext context, String big, String title, String note, VoidCallback again) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      const Center(child: BuaNoi(mood: BuaMood.happy, size: 110)),
      const SizedBox(height: 14),
      Text(big, textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 52, fontWeight: FontWeight.w600, color: _ink, height: 1.1)),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 20, color: _sky, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Text(note, textAlign: TextAlign.center, style: const TextStyle(color: _dim, fontSize: 15, height: 1.6)),
      const Spacer(),
      FilledButton(onPressed: () => Navigator.of(context).pop(), style: _primary(), child: const Text('กลับสู่ลาน')),
      TextButton(onPressed: again, child: const Text('เล่นอีกรอบ', style: TextStyle(color: _dim))),
    ]);

// ===========================================================================
// ไขปริศนา — find the rule behind a sequence
// ===========================================================================
class _Puzzle {
  final List<int> shown;
  final int answer;
  final List<int> options;
  final String rule;
  _Puzzle(this.shown, this.answer, this.options, this.rule);
}

_Puzzle _makePuzzle(Random r, int level) {
  late List<int> s;
  late String rule;
  final kind = r.nextInt(level < 2 ? 4 : level < 4 ? 6 : 8);
  switch (kind) {
    case 0:
      final a = r.nextInt(10) + 1, d = r.nextInt(6) + 2;
      s = [for (var i = 0; i < 6; i++) a + d * i];
      rule = 'บวกเพิ่มทีละ $d';
    case 1:
      final a = r.nextInt(30) + 40, d = r.nextInt(5) + 3;
      s = [for (var i = 0; i < 6; i++) a - d * i];
      rule = 'ลดลงทีละ $d';
    case 2:
      final a = r.nextInt(3) + 1, m = r.nextInt(2) + 2;
      s = [for (var i = 0; i < 6; i++) a * pow(m, i).toInt()];
      rule = 'คูณ $m ทุกครั้ง';
    case 3:
      final a = r.nextInt(5) + 1;
      s = [a];
      for (var i = 1; i < 6; i++) {
        s.add(s.last + i);
      }
      rule = 'บวกเพิ่มทีละ 1, 2, 3, 4, … (ระยะห่างโตขึ้นเรื่อย ๆ)';
    case 4:
      final x = r.nextInt(4) + 2, y = r.nextInt(5) + 3, a = r.nextInt(8) + 1;
      s = [a];
      for (var i = 1; i < 6; i++) {
        s.add(s.last + (i.isOdd ? x : y));
      }
      rule = 'บวกสลับกัน +$x, +$y, +$x, +$y';
    case 5:
      final o = r.nextInt(3);
      s = [for (var i = 1; i <= 6; i++) i * i + o];
      rule = o == 0 ? 'เลขยกกำลังสอง 1, 4, 9, 16, …' : 'เลขยกกำลังสอง แล้วบวก $o';
    case 6:
      final a = r.nextInt(3) + 1, b = r.nextInt(3) + 2;
      s = [a, b];
      for (var i = 2; i < 6; i++) {
        s.add(s[i - 1] + s[i - 2]);
      }
      rule = 'สองตัวก่อนหน้าบวกกัน (แบบฟีโบนักชี)';
    default:
      final a = r.nextInt(3) + 1;
      s = [a];
      for (var i = 1; i < 6; i++) {
        s.add(s.last * 2 + 1);
      }
      rule = 'คูณ 2 แล้วบวก 1';
  }
  final shown = s.sublist(0, 5), ans = s[5];
  final opts = <int>{ans};
  while (opts.length < 4) {
    final int delta = (r.nextInt(5) + 1) * (r.nextBool() ? 1 : -1) * max(1, (ans.abs() / 20).round());
    opts.add(ans + delta);
  }
  return _Puzzle(shown, ans, opts.toList()..shuffle(r), rule);
}

class PuzzleGame extends StatefulWidget {
  final Store store;
  const PuzzleGame({super.key, required this.store});
  @override
  State<PuzzleGame> createState() => _PuzzleGameState();
}

class _PuzzleGameState extends State<PuzzleGame> {
  static const total = 8;
  final r = Random();
  int i = 0, score = 0, level = 0;
  int? picked;
  late _Puzzle q = _makePuzzle(r, level);
  bool over = false;

  void _pick(int v) {
    if (picked != null) return;
    final ok = v == q.answer;
    if (ok) {
      score++;
      level++;
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() => picked = v);
  }

  void _next() {
    if (i + 1 >= total) {
      _record(widget.store, 'puzzle', (score * 100 / total).round());
      setState(() => over = true);
      return;
    }
    setState(() {
      i++;
      picked = null;
      q = _makePuzzle(r, level);
    });
  }

  @override
  Widget build(BuildContext context) => _frame(
        context,
        'ไขปริศนา',
        Icons.extension_rounded,
        over
            ? _done(context, '$score/$total', score >= 7 ? 'คิดเป็นระบบมาก' : score >= 5 ? 'จับรูปแบบได้ดี' : 'สมองกำลังอุ่นเครื่อง',
                'ทุกข้อคือการหากฎที่ซ่อนอยู่\nทักษะเดียวกับการแก้โจทย์คณิตและวิทยาศาสตร์', () {
                setState(() {
                  over = false;
                  i = score = level = 0;
                  picked = null;
                  q = _makePuzzle(r, level);
                });
              })
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                Text('ข้อ ${i + 1} จาก $total', style: const TextStyle(color: _dim)),
                const SizedBox(height: 6),
                const Text('ตัวต่อไปคืออะไร', style: TextStyle(fontFamily: cute, fontSize: 24, color: _ink, fontWeight: FontWeight.w600)),
                const Spacer(),
                Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 10, children: [
                  for (final n in q.shown) _numBox('$n', _pond),
                  _numBox(picked == null ? '?' : '${q.answer}', picked == null ? _dim : _lotus),
                ]),
                const Spacer(),
                if (picked != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text('${picked == q.answer ? 'ถูกต้อง' : 'คำตอบคือ ${q.answer}'} · กฎคือ ${q.rule}',
                        textAlign: TextAlign.center, style: TextStyle(color: picked == q.answer ? _pond : _lotus, fontSize: 15, height: 1.5)),
                  ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: [
                    for (final o in q.options)
                      OutlinedButton(
                        onPressed: () => _pick(o),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          backgroundColor: picked != null && o == q.answer ? _pond.withValues(alpha: .2) : null,
                          side: BorderSide(color: picked != null && o == q.answer ? _pond : _dim.withValues(alpha: .5)),
                          textStyle: const TextStyle(fontFamily: sans, fontSize: 22, fontWeight: FontWeight.w600),
                        ),
                        child: Text('$o'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (picked != null) FilledButton(onPressed: _next, style: _primary(), child: const Text('ข้อต่อไป')),
              ]),
      );

  Widget _numBox(String t, Color c) => Container(
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(color: c.withValues(alpha: .14), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: .5))),
        child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontFamily: sans, fontSize: 20, fontWeight: FontWeight.w600, color: _ink)),
      );
}

// ===========================================================================
// คิดเร็ว — sixty seconds of mental arithmetic that gets harder as you go
// ===========================================================================
class MathGame extends StatefulWidget {
  final Store store;
  const MathGame({super.key, required this.store});
  @override
  State<MathGame> createState() => _MathGameState();
}

class _MathGameState extends State<MathGame> {
  static const seconds = 60;
  final r = Random();
  int phase = 0, left = seconds, score = 0, wrong = 0;
  Timer? _t;
  String q = '';
  int ans = 0;
  List<int> opts = [];
  Color flash = Colors.transparent;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      phase = 1;
      left = seconds;
      score = wrong = 0;
    });
    _newQ();
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (left <= 1) {
        t.cancel();
        _record(widget.store, 'math', score);
        setState(() => phase = 2);
        return;
      }
      setState(() => left--);
    });
  }

  void _newQ() {
    final lv = score ~/ 4;
    final op = r.nextInt(lv < 1 ? 2 : 3);
    int a, b;
    switch (op) {
      case 0:
        a = r.nextInt(10 + lv * 15) + 2;
        b = r.nextInt(10 + lv * 15) + 2;
        ans = a + b;
        q = '$a + $b';
      case 1:
        a = r.nextInt(15 + lv * 15) + 10;
        b = r.nextInt(a - 1) + 1;
        ans = a - b;
        q = '$a − $b';
      default:
        a = r.nextInt(8 + lv) + 2;
        b = r.nextInt(8) + 2;
        ans = a * b;
        q = '$a × $b';
    }
    final s = <int>{ans};
    while (s.length < 4) {
      s.add(ans + (r.nextInt(9) - 4 == 0 ? 5 : r.nextInt(9) - 4) * (op == 2 ? r.nextInt(2) + 1 : 1));
    }
    opts = s.toList()..shuffle(r);
  }

  void _pick(int v) {
    final ok = v == ans;
    HapticFeedback.selectionClick();
    setState(() {
      if (ok) {
        score++;
      } else {
        wrong++;
      }
      flash = ok ? _pond.withValues(alpha: .25) : _lotus.withValues(alpha: .2);
      _newQ();
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => flash = Colors.transparent);
    });
  }

  @override
  Widget build(BuildContext context) => _frame(
        context,
        'คิดเร็ว',
        Icons.calculate_rounded,
        switch (phase) {
          0 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Spacer(),
              const Icon(Icons.calculate_rounded, color: _sky, size: 72),
              const SizedBox(height: 16),
              const Text('60 วินาที ตอบให้ได้มากที่สุด\nยิ่งตอบถูก โจทย์ยิ่งยากขึ้น\nฝึกความเร็วในการคิดและความจำระยะสั้น',
                  textAlign: TextAlign.center, style: TextStyle(color: _ink, fontSize: 17, height: 1.7)),
              const Spacer(),
              FilledButton(onPressed: _start, style: _primary(), child: const Text('เริ่ม')),
            ]),
          1 => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(color: flash, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                LinearProgressIndicator(value: left / seconds, color: _sky, backgroundColor: _dim.withValues(alpha: .2)),
                const SizedBox(height: 8),
                Text('ถูก $score · เหลือ $left วินาที', textAlign: TextAlign.center, style: const TextStyle(color: _dim)),
                const Spacer(),
                Text(q, textAlign: TextAlign.center, style: const TextStyle(fontFamily: sans, fontSize: 56, fontWeight: FontWeight.w600, color: _ink)),
                const Spacer(),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    for (final o in opts)
                      OutlinedButton(
                        onPressed: () => _pick(o),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          side: BorderSide(color: _dim.withValues(alpha: .5)),
                          textStyle: const TextStyle(fontFamily: sans, fontSize: 26, fontWeight: FontWeight.w600),
                        ),
                        child: Text('$o'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ]),
            ),
          _ => _done(context, '$score', score >= 25 ? 'สมองว่องไวมาก' : score >= 15 ? 'คิดเร็วดี' : 'ฝึกทุกวัน จะเร็วขึ้นเอง',
              'ตอบผิด $wrong ข้อ\nความเร็วสำคัญ แต่ความแม่นสำคัญกว่า', _start),
        },
      );
}

// ===========================================================================
// การ์ดทวนจำ — the reader's own lesson cards, reviewed on a growing schedule
// (Leitner boxes: 1, 2, 4, 8, 16 days)
// ===========================================================================
const _intervals = [1, 2, 4, 8, 16];

List<Map<String, dynamic>> loadCards(Store s) {
  try {
    return (jsonDecode(s.prefs.getString('flashcards') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveCards(Store s, List<Map<String, dynamic>> cards) async {
  await s.prefs.setString('flashcards', jsonEncode(cards));
  s.touch();
}

List<Map<String, dynamic>> dueCards(Store s) {
  final today = todayKey();
  return loadCards(s).where((c) => ((c['due'] as String?) ?? today).compareTo(today) <= 0).toList();
}

class RecallPage extends StatefulWidget {
  final Store store;
  const RecallPage({super.key, required this.store});
  @override
  State<RecallPage> createState() => _RecallPageState();
}

class _RecallPageState extends State<RecallPage> {
  int phase = 0; // 0 deck, 1 review, 2 done
  List<Map<String, dynamic>> queue = [];
  bool shown = false;
  int remembered = 0, reviewed = 0;

  void _startReview() {
    setState(() {
      queue = dueCards(widget.store)..shuffle();
      phase = queue.isEmpty ? 0 : 1;
      shown = false;
      remembered = reviewed = 0;
    });
  }

  Future<void> _grade(bool ok) async {
    final all = loadCards(widget.store);
    final c = queue.first;
    final i = all.indexWhere((x) => x['id'] == c['id']);
    if (i >= 0) {
      final box = ok ? min(((all[i]['box'] as num?)?.toInt() ?? 0) + 1, _intervals.length - 1) : 0;
      all[i]['box'] = box;
      all[i]['due'] = keyOf(DateTime.now().add(Duration(days: ok ? _intervals[box] : 1)));
      await saveCards(widget.store, all);
    }
    HapticFeedback.selectionClick();
    reviewed++;
    if (ok) remembered++;
    setState(() {
      queue.removeAt(0);
      if (!ok) queue.add(c); // see it again before the session ends
      shown = false;
      if (queue.isEmpty) {
        _record(widget.store, 'recall', reviewed);
        phase = 2;
      }
    });
  }

  Future<void> _addCard() async {
    final q = TextEditingController(), a = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('เพิ่มการ์ด'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: q, decoration: const InputDecoration(labelText: 'คำถาม', hintText: 'เช่น สูตรพื้นที่วงกลม'), maxLines: 2, minLines: 1),
          const SizedBox(height: 8),
          TextField(controller: a, decoration: const InputDecoration(labelText: 'คำตอบ', hintText: 'เช่น πr²'), maxLines: 3, minLines: 1),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('เพิ่ม')),
        ],
      ),
    );
    if (ok == true && q.text.trim().isNotEmpty && a.text.trim().isNotEmpty) {
      final all = loadCards(widget.store)..add({'id': newId(), 'q': q.text.trim(), 'a': a.text.trim(), 'box': 0, 'due': todayKey()});
      await saveCards(widget.store, all);
      setState(() {});
    }
  }

  Future<void> _delete(String id) async {
    final all = loadCards(widget.store)..removeWhere((x) => x['id'] == id);
    await saveCards(widget.store, all);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => _frame(
        context,
        'การ์ดทวนจำ',
        Icons.style_rounded,
        switch (phase) {
          0 => _deck(),
          1 => _review(),
          _ => _done(context, '$remembered/$reviewed', 'ทวนจำวันนี้เสร็จแล้ว',
              'การดึงความรู้ออกมาจากความจำ ทำให้จำได้นานกว่าอ่านซ้ำหลายเท่า\nการ์ดที่จำได้จะเว้นระยะห่างขึ้น 1, 2, 4, 8, 16 วัน', _startReview),
        },
      );

  Widget _deck() {
    final all = loadCards(widget.store);
    final due = dueCards(widget.store).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 6),
      const Text('ใส่สิ่งที่ต้องจำจากบทเรียน: สูตร คำศัพท์ วันที่ นิยาม\nทวนวันละไม่กี่นาที แอปจะเลือกการ์ดที่ใกล้ลืมให้เอง',
          style: TextStyle(color: _dim, height: 1.6)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: FilledButton(
            onPressed: due == 0 ? null : _startReview,
            style: _primary(),
            child: Text(due == 0 ? 'วันนี้ไม่มีการ์ดต้องทวน' : 'ทวนวันนี้ $due ใบ'),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(onPressed: _addCard, icon: const Icon(Icons.add_rounded)),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: all.isEmpty
            ? const Center(child: Text('ยังไม่มีการ์ด กด + เพื่อเพิ่มใบแรก', style: TextStyle(color: _dim)))
            : ListView(children: [
                for (final c in all)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c['q'] as String, style: const TextStyle(color: _ink, fontSize: 15)),
                          Text('กล่อง ${((c['box'] as num?)?.toInt() ?? 0) + 1} · ทวนครั้งต่อไป ${c['due']}', style: const TextStyle(color: _dim, fontSize: 12)),
                        ]),
                      ),
                      IconButton(onPressed: () => _delete(c['id'] as String), icon: const Icon(Icons.close_rounded, color: _dim, size: 18)),
                    ]),
                  ),
              ]),
      ),
    ]);
  }

  Widget _review() {
    final c = queue.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      Text('เหลือ ${queue.length} ใบ', style: const TextStyle(color: _dim)),
      const Spacer(),
      GestureDetector(
        onTap: () => setState(() => shown = true),
        child: Container(
          constraints: const BoxConstraints(minHeight: 260),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(24), border: Border.all(color: _sky.withValues(alpha: .4))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(c['q'] as String, textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 24, color: _ink, fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 18),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: shown ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const Text('นึกคำตอบในใจก่อน แล้วแตะเพื่อดู', style: TextStyle(color: _dim)),
              secondChild: Text(c['a'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: _pond, height: 1.5)),
            ),
          ]),
        ),
      ),
      const Spacer(),
      if (shown)
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _grade(false),
              style: OutlinedButton.styleFrom(foregroundColor: _ink, side: BorderSide(color: _dim.withValues(alpha: .5)), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('ยังจำไม่ได้'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: () => _grade(true), style: _primary(), child: const Text('จำได้'))),
        ]),
    ]);
  }
}
