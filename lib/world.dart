import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'classroom.dart';
import 'games.dart';
import 'guide.dart';
import 'notify.dart';
import 'practice.dart';
import 'prep.dart';
import 'schedule.dart';
import 'start.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

// สนามสอบ — the study world, apart from the mind-practice world. Three tabs:
// ตอนนี้ (what this moment is for, warnings, today's timeline, hours left),
// วิชา (exam table, stars), ความเพียร (the lotus of perseverance and stats).
//
// The lotus: a day with 30+ minutes of study grows it one step and lights a
// flame; meeting the whole day's target makes it a golden day and grows it
// two. A missed day wilts it two steps, and studying again brings it back.
// Saturdays (ร.ด.), exam days and the one chosen rest day a week never count
// against.

const _litMinutes = 30;
const _maxVigor = 40;
const _stageAt = [0, 2, 5, 9, 14, 20, 28];
const _stageNames = ['เมล็ดบัว', 'ดอกตูม', 'เริ่มแย้ม', 'กลีบแรกบาน', 'บานครึ่งดอก', 'บานเต็มดอก', 'บัวทองแห่งความเพียร'];

const _fire = Color(0xFFFF9F43);
const _warn = Color(0xFFFFB25B);

Future<void> openWorld(BuildContext context, Store store, PracticeController practice) => Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, _, _) => Theme(data: buildTheme(Brightness.dark), child: StudyWorld(store: store, practice: practice)),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .97, end: 1.0).animate(a), child: child)),
    ));

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
bool _same(DateTime a, DateTime b) => _day(a) == _day(b);

/// Minutes of real study on [d]: focus sessions and rounds, not class time.
int studyMinutesOn(Store store, DateTime d) => items(store.day(keyOf(d)), 'sessions')
    .where((s) => s['kind'] == 'study' && s['class'] != true)
    .fold(0, (a, s) => a + ((s['min'] as num?)?.toInt() ?? 0));

bool restDay(Store store, DateTime d, List<Subject> subs) =>
    d.weekday == DateTime.saturday || subs.any((s) => _same(s.at, d)) || dayChoice(store, d).mode == DayMode.rest;

/// A golden day: the whole target met, and the target was a real one.
bool goldDay(Store store, DateTime d, List<Subject> subs) {
  final t = dayTarget(store, d, subs);
  return t >= 60 && studyMinutesOn(store, d) >= t;
}

class Grit {
  final int vigor, streak, best, stage, goldDays;
  final bool wilted, litToday, goldToday;
  final int todayMin, target;
  const Grit(this.vigor, this.streak, this.best, this.stage, this.wilted, this.litToday, this.todayMin, this.target, this.goldToday, this.goldDays);
  String get name => _stageNames[stage];
  int? get toNext => stage + 1 < _stageAt.length ? _stageAt[stage + 1] - vigor : null;
}

Grit gritOf(Store store, List<Subject> subs) {
  final today = _day(DateTime.now());
  final saved = store.prefs.getString('world-start');
  if (saved == null) store.prefs.setString('world-start', keyOf(today));
  final start = saved == null ? today : dateOf(saved);
  var vigor = 0, streak = 0, best = 0, golds = 0;
  var wilted = false;
  for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
    final lit = studyMinutesOn(store, d) >= _litMinutes;
    final gold = lit && goldDay(store, d, subs);
    if (gold) golds++;
    if (d == today) {
      if (lit) {
        vigor = min(_maxVigor, vigor + (gold ? 2 : 1));
        streak++;
        wilted = false;
      }
      break;
    }
    if (lit) {
      vigor = min(_maxVigor, vigor + (gold ? 2 : 1));
      streak++;
      wilted = false;
    } else if (!restDay(store, d, subs)) {
      vigor = max(0, vigor - 2);
      streak = 0;
      wilted = true;
    }
    best = max(best, streak);
  }
  best = max(best, streak);
  var stage = 0;
  for (var i = 0; i < _stageAt.length; i++) {
    if (vigor >= _stageAt[i]) stage = i;
  }
  final tm = studyMinutesOn(store, today);
  final target = dayTarget(store, today, subs);
  return Grit(vigor, streak, best, stage, wilted, tm >= _litMinutes, tm, target, target >= 60 && tm >= target, golds);
}

/// Day key of the last session logged for each subject code.
Map<String, String> _lastStudied(Store store) {
  final m = <String, String>{};
  for (final d in store.days.values) {
    for (final s in items(d, 'sessions')) {
      final c = s['subject'] as String?;
      final k = d['date'] as String;
      if (c != null && (m[c] == null || k.compareTo(m[c]!) > 0)) m[c] = k;
    }
  }
  return m;
}

/// Hours still needed: untouched topics ~1 h, shaky ~30 min, solid ~10 min.
double _needHours(Subject s) => s.topics.fold(0.0, (a, t) => a + const [1.0, .5, .17][t.lv]);

class Warning {
  final IconData icon;
  final String text;
  final Color color;
  const Warning(this.icon, this.text, this.color);
}

/// The nudges: subjects left untouched, favourites eating the week, time
/// running tight, exams close and unready, today not started, lotus wilting.
List<Warning> warningsFor(Store store, List<Subject> subs, Grit g) {
  final now = DateTime.now();
  final today = _day(now);
  final open = subs.where((s) => s.daysLeft(today) >= 0).toList();
  final out = <Warning>[];
  if (open.isEmpty) return out;

  if (g.wilted && !g.litToday) {
    out.add(const Warning(Icons.local_florist_outlined, 'บัวแห่งความเพียรเหี่ยวลงเพราะเมื่อวานพลาด · อ่านวันนี้ให้ครบ 30 นาที บัวจะเริ่มฟื้น', _warn));
  }

  final bs = blocksOn(store, now, subs);
  final firstStudy = bs.where((b) => b.isStudy).firstOrNull;
  if (firstStudy != null && nowMinutes(now) > firstStudy.end && g.todayMin == 0) {
    out.add(Warning(Icons.alarm_rounded, 'เลยเวลา${firstStudy.label}มาแล้ว วันนี้ยังไม่ได้เริ่ม · เลื่อนเวลาเริ่มได้ด้านบน หรือกด "เริ่มแค่ 2 นาที"', _warn));
  }

  // Evening check: two and a half hours before bed and under half the target.
  final bed = bs.where((b) => b.kind == Kind.sleep && b.start > 0).firstOrNull?.start ?? 24 * 60;
  if (g.target >= 60 && nowMinutes(now) >= bed - 150 && g.todayMin < g.target / 2) {
    final miss = ((g.target - g.todayMin) / 60).toStringAsFixed(1);
    out.add(Warning(Icons.flag_rounded, 'เย็นแล้ว ยังขาดอีก $miss ชม. จากเป้าวันนี้ · ไม่ครบไม่เป็นไร ขอให้ถึง 30 นาที ไฟจะได้ไม่ดับ', _warn));
  }

  final last = _lastStudied(store);
  final start = dateOf(store.prefs.getString('world-start') ?? keyOf(today));
  for (final s in open.where((s) => !s.fav && s.rank >= 4)) {
    final k = last[s.code];
    final gap = k == null ? today.difference(start).inDays : today.difference(dateOf(k)).inDays;
    if (k == null && gap >= 2) {
      out.add(Warning(Icons.report_rounded, '${s.code} ยังไม่ได้เริ่มเลย ทั้งที่เป็นวิชาที่อ่อน · ให้รอบแรกของวันนี้เป็นวิชานี้', const Color(0xFFE8857A)));
    } else if (k != null && gap >= 3) {
      out.add(Warning(Icons.report_rounded, '${s.code} ไม่ได้แตะมา $gap วันแล้ว · อย่าปล่อยให้วิชาที่อ่อนถูกเลื่อน', const Color(0xFFE8857A)));
    }
  }

  var favMin = 0, allMin = 0;
  for (var i = 0; i < 7; i++) {
    for (final s in items(store.day(keyOf(today.subtract(Duration(days: i)))), 'sessions')) {
      final c = s['subject'] as String?;
      if (c == null) continue;
      final m = (s['min'] as num?)?.toInt() ?? 0;
      allMin += m;
      if (subs.any((x) => x.code == c && x.fav)) favMin += m;
    }
  }
  if (allMin >= 120 && favMin / allMin >= .6) {
    out.add(Warning(Icons.star_half_rounded, '7 วันที่ผ่านมา อ่านวิชาที่ชอบไป ${(favMin * 100 / allMin).round()}% · สนุกได้ แต่วิชาที่ต้องทำกำลังถูกทิ้ง', _warn));
  }

  for (final s in open) {
    final d = s.daysLeft(today);
    if (d <= 7 && s.ready < .5) {
      out.add(Warning(Icons.hourglass_bottom_rounded, '${s.code} สอบอีก $d วัน พร้อมแค่ ${(s.ready * 100).round()}% · เน้นหัวข้อที่ออกบ่อย และทำข้อสอบเก่า', const Color(0xFFE8857A)));
    }
  }

  final lastExam = open.map((s) => s.at).reduce((a, b) => a.isAfter(b) ? a : b);
  final leftH = studyMinutesBetween(store, now, lastExam, subs) / 60;
  final needH = open.fold(0.0, (a, s) => a + _needHours(s));
  if (needH > leftH * .85) {
    out.add(Warning(Icons.speed_rounded, 'เวลาเริ่มตึง: งานที่เหลือราว ${needH.round()} ชม. เวลาอ่านจริงเหลือ ${leftH.round()} ชม. · ใช้เวลาว่างช่วงเย็นเพิ่ม หรือตัดหัวข้อที่ไม่ออกสอบ', _warn));
  }
  return out;
}

/// One-line summary for the pond on the Today page: real hours left, what
/// this moment is for, and today's progress against the target.
(int hoursLeft, String now, String today)? worldGlance(Store store) {
  final subs = loadPrep(store);
  final n = DateTime.now();
  final open = subs.where((s) => s.at.isAfter(n)).toList();
  if (open.isEmpty) return null;
  final lastExam = open.map((s) => s.at).reduce((a, b) => a.isAfter(b) ? a : b);
  final (cur, _) = nowAndNext(store, subs, n);
  var label = cur.label;
  if (cur.kind == Kind.study) {
    final it = assignRounds(store, n, subs)[cur.start];
    if (it != null) label = '$label · ${it.s.code}';
  }
  final t = dayTarget(store, n, subs), m = studyMinutesOn(store, n);
  final today = t == 0 ? 'วันนี้ไม่มีเป้า' : 'วันนี้ ${(m / 60).toStringAsFixed(1)} / ${(t / 60).toStringAsFixed(1)} ชม.';
  return ((studyMinutesBetween(store, n, lastExam, subs) / 60).round(), label, today);
}

/// The door from the Today page into the study world.
class WorldPortal extends StatelessWidget {
  final Store store;
  final PracticeController practice;
  const WorldPortal({super.key, required this.store, required this.practice});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final subs = loadPrep(store);
    final today = _day(DateTime.now());
    final next = ([...subs]..sort((a, b) => a.at.compareTo(b.at))).where((s) => s.daysLeft(today) >= 0).firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final g = gritOf(store, subs);
    final glance = worldGlance(store);
    return InkWell(
      onTap: () => openWorld(context, store, practice),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF14233A), Color(0xFF2A2140)]),
          border: Border.all(color: const Color(0xFF6FA8DC).withValues(alpha: .5)),
        ),
        child: Row(children: [
          Column(children: [
            Icon(Icons.local_fire_department_rounded, color: g.streak > 0 ? _fire : Colors.white24, size: 30),
            Text('${g.streak}', style: number(context, 15).copyWith(color: Colors.white)),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('เข้าสนามสอบ', style: display(context, 17).copyWith(color: Colors.white)),
              Text('${next.code} สอบในอีก ${next.daysLeft(today)} วัน${glance == null ? '' : ' · เวลาอ่านจริงเหลือ ${glance.$1} ชม.'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: p.lotus),
        ]),
      ),
    );
  }
}

class StudyWorld extends StatefulWidget {
  final Store store;
  final PracticeController practice;
  const StudyWorld({super.key, required this.store, required this.practice});
  @override
  State<StudyWorld> createState() => _StudyWorldState();
}

class _StudyWorldState extends State<StudyWorld> {
  int tab = 0;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    if (widget.store.prefs.getBool('world-bells') == true) reschedule(widget.store);
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              IconButton(tooltip: 'กลับโลกฝึกใจ', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.spa_outlined)),
              Text('สนามสอบ', style: display(context, 20)),
              const Spacer(),
              IconButton(tooltip: 'วิธีเรียนให้ได้ผล', onPressed: () => openGuide(context, widget.store), icon: const Icon(Icons.lightbulb_outline_rounded)),
            ]),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) => IndexedStack(index: tab, children: [
                _NowTab(store: widget.store, practice: widget.practice),
                PrepPage(store: widget.store, practice: widget.practice),
                _GritTab(store: widget.store),
              ]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.schedule_rounded), label: 'ตอนนี้'),
          NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'วิชา'),
          NavigationDestination(icon: Icon(Icons.local_fire_department_rounded), label: 'ความเพียร'),
        ],
      ),
    );
  }
}

/// Reminders for the next seven days of blocks: class, ร.ด., rounds,
/// homework, exams, an evening check on the target, and the phone down
/// before sleep. Runs again whenever a day is adapted.
Future<bool> reschedule(Store store) {
  final subs = loadPrep(store);
  final bells = <(DateTime, String, String)>[];
  final today = _day(DateTime.now());
  for (var i = 0; i < 7; i++) {
    final d = today.add(Duration(days: i));
    final rounds = assignRounds(store, d, subs);
    final bs = blocksOn(store, d, subs);
    for (final b in bs) {
      final at = d.add(Duration(minutes: b.start));
      switch (b.kind) {
        case Kind.study:
          final it = rounds[b.start];
          bells.add((at, 'ถึงเวลา${b.label}', it == null ? 'เปิดสนามสอบดูว่าอ่านอะไร' : '${it.s.code} · ${it.topic?.t ?? 'ซ้อมข้อสอบเก่า'}'));
        case Kind.homework:
          bells.add((at, 'ถึงเวลา${b.label}', 'ไม่อยากเริ่ม กด "เริ่มแค่ 2 นาที"'));
        case Kind.klass:
          bells.add((at.subtract(const Duration(minutes: 10)), 'อีก 10 นาทีเข้าเรียน', 'วางมือถือไว้บนโต๊ะ เปิด "เรียนในห้อง" ใจลอยเมื่อไหร่แตะจอ'));
        case Kind.rd:
          bells.add((at.subtract(const Duration(minutes: 10)), 'วันนี้ ร.ด.', 'ขับรถไปจุดรถรับส่ง ขับปลอดภัย · วันนี้ไม่นับว่าพลาด'));
        case Kind.exam:
          bells.add((at.subtract(const Duration(minutes: 90)), 'วันนี้สอบ ${b.examCode}', 'ทวนสรุป 1 หน้า ไม่อ่านเรื่องใหม่ · เตรียมบัตรและอุปกรณ์'));
        default:
      }
    }
    final bedAt = bs.where((b) => b.kind == Kind.sleep && b.start > 0).firstOrNull?.start ?? 24 * 60;
    if (dayTarget(store, d, subs) >= 60) {
      bells.add((d.add(Duration(minutes: bedAt - 120)), 'เช็กเป้าวันนี้', 'อ่านครบเป้าหรือยัง · ครบได้วันบัวทอง ไม่ครบขอให้ถึง 30 นาที'));
    }
    bells.add((d.add(Duration(minutes: bedAt - 15)), 'วางมือถือได้แล้ว', 'อีก 15 นาทีถึงเวลานอน สมองจะเก็บสิ่งที่อ่านวันนี้ตอนหลับ'));
  }
  bells.sort((a, b) => a.$1.compareTo(b.$1));
  return scheduleStudyBells(bells);
}

class _NowTab extends StatelessWidget {
  final Store store;
  final PracticeController practice;
  const _NowTab({required this.store, required this.practice});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final subs = loadPrep(store);
    final now = DateTime.now();
    final today = _day(now);
    final open = subs.where((s) => s.at.isAfter(now)).toList()..sort((a, b) => a.at.compareTo(b.at));
    final g = gritOf(store, subs);
    final warns = warningsFor(store, subs, g);
    final blocks = blocksOn(store, now, subs);
    final rounds = assignRounds(store, now, subs);
    final (cur, next) = nowAndNext(store, subs, now);
    final m = nowMinutes(now);
    final doneCodes = items(store.day(todayKey()), 'sessions').map((s) => s['subject']).whereType<String>().toSet();
    final choice = dayChoice(store, now);

    final leftAll = open.isEmpty ? 0 : studyMinutesBetween(store, now, open.last.at, subs);
    final leftFirst = open.isEmpty ? 0 : studyMinutesBetween(store, now, open.first.at, subs);

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
      // hours left
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B2D4A), Color(0xFF2E2547)]),
        ),
        child: open.isEmpty
            ? Text('สอบครบทุกวิชาแล้ว พักให้เต็มที่', style: display(context, 20))
            : Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('เวลาอ่านจริงที่เหลือ', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    Text('${(leftAll / 60).round()} ชม.', style: number(context, 38).copyWith(color: Colors.white)),
                    Text('ก่อน ${open.first.code} (${open.first.when}) เหลือ ${(leftFirst / 60).round()} ชม.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    const Text('นับเฉพาะช่วงรอบอ่าน การบ้าน และทวน ในตารางด้านล่าง ไม่นับเวลานอน เรียน เดินทาง พัก',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ),
                Column(children: [
                  Icon(Icons.local_fire_department_rounded, size: 36, color: g.streak > 0 ? _fire : Colors.white24),
                  Text('${g.streak} วัน', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(g.litToday ? 'วันนี้ติดไฟแล้ว' : 'อีก ${max(0, _litMinutes - g.todayMin)} นาที', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ]),
      ),
      const SizedBox(height: 12),

      // today's target and how the day is run
      _DayBar(store: store, subs: subs, g: g, choice: choice),
      const SizedBox(height: 14),

      // now
      _NowCard(
        store: store,
        practice: practice,
        subs: subs,
        block: cur,
        next: next,
        item: cur.kind == Kind.study ? rounds[cur.start] : cur.kind == Kind.flex ? todayPlan(subs, count: 1).firstOrNull : null,
        minutesNow: m,
      ),
      const SizedBox(height: 14),

      // warnings
      if (warns.isNotEmpty) ...[
        Text('พี่เตือน', style: display(context, 17).copyWith(color: _warn)),
        const SizedBox(height: 6),
        for (final w in warns)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: w.color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(16),
                border: Border(left: BorderSide(color: w.color, width: 4)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(w.icon, color: w.color, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(w.text, style: TextStyle(color: p.ink, height: 1.5, fontSize: 13.5))),
              ]),
            ),
          ),
        const SizedBox(height: 8),
      ],

      // timeline
      Row(children: [
        Text('ตารางวันนี้', style: display(context, 18)),
        const Spacer(),
        Text(today.weekday == DateTime.saturday ? 'วัน ร.ด. · ไม่นับว่าพลาด' : '', style: TextStyle(color: p.muted, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      for (final b in blocks.where((b) => !(b.kind == Kind.sleep && b.start == 0)))
        _blockRow(context, subs, b, b.start <= m && m < b.end, b.end <= m, rounds[b.start], doneCodes),
      const SizedBox(height: 16),
      _BellSwitch(store: store),
      const SizedBox(height: 6),
      Text('แตะรอบอ่านในตารางเพื่อเปลี่ยนวิชาได้ · รอบที่มีดาวคือวิชาที่ชอบ · ที่เหลือแอปเลือกตามความสำคัญ และพี่จะเตือนถ้าวิชาที่อ่อนถูกทิ้งนานเกินไป',
          style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
    ]);
  }

  Widget _blockRow(BuildContext context, List<Subject> subs, Block b, bool isNow, bool past, PlanItem? it, Set<String> doneCodes) {
    final p = Pal.of(context);
    final c = colorOf(b.kind);
    final done = it != null && doneCodes.contains(it.s.code);
    final mine = b.kind == Kind.study && isPicked(store, DateTime.now(), b.start);
    final title = it == null ? b.label : '${b.label}${b.role == Role.fav && it.s.fav ? ' ★' : ''} · ${it.s.code}${mine ? ' (เลือกเอง)' : ''}';
    return Opacity(
      opacity: past && !isNow ? .45 : 1,
      child: GestureDetector(
        // Study rounds still ahead can be given another subject.
        onTap: b.kind == Kind.study && !past ? () => pickSubject(context, store, practice, subs, block: b, startNow: isNow) : null,
        child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: isNow ? c.withValues(alpha: .16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isNow ? c : Colors.transparent),
        ),
        child: Row(children: [
          SizedBox(width: 92, child: Text(b.span, style: TextStyle(color: p.muted, fontSize: 12.5, fontFeatures: const [FontFeature.tabularFigures()]))),
          Icon(iconOf(b.kind), size: 18, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: p.ink, fontSize: 13.5, fontWeight: b.isStudy ? FontWeight.w600 : FontWeight.w400)),
              if (it?.topic != null) Text(it!.topic!.t, style: TextStyle(color: p.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (done) Icon(Icons.check_circle_rounded, size: 18, color: c),
          if (b.kind == Kind.study && !past && !done) Icon(Icons.swap_horiz_rounded, size: 16, color: p.muted),
        ]),
      ),
      ),
    );
  }
}

/// Choose the subject for a round (or for now, on a free day). The plan's
/// order is kept as the suggestion; the pick sticks to that round today.
Future<void> pickSubject(BuildContext context, Store store, PracticeController practice, List<Subject> subs, {Block? block, bool startNow = false}) {
  final today = DateTime.now();
  final order = todayPlan(subs, count: subs.length).map((it) => it.s).toList();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) {
      final p = Pal.of(sheet);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(block == null ? 'อยากอ่านวิชาไหน' : 'เลือกวิชาให้${block.label} (${block.span})', style: display(sheet, 19)),
          Text('เรียงตามที่แอปแนะนำ · แตะเพื่อเลือก · แตะไอคอนรายการเพื่อเลือกหัวข้อเอง', style: TextStyle(color: p.muted, fontSize: 12.5)),
          const SizedBox(height: 10),
          for (final (i, s) in order.indexed)
            () {
              final it = planFor(s);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  border: i == 0 ? p.lotus.withValues(alpha: .6) : null,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (block != null) pickRound(store, today, block.start, s.code);
                      Navigator.pop(sheet);
                      if (startNow) startPlanItem(context, practice, store, subs, it);
                    },
                    title: Row(children: [
                      Text(s.code, style: display(sheet, 16)),
                      if (s.fav) Icon(Icons.star_rounded, size: 16, color: p.gold),
                      const SizedBox(width: 6),
                      Text('อีก ${s.daysLeft(DateTime(today.year, today.month, today.day))} วัน · พร้อม ${(s.ready * 100).round()}%',
                          style: TextStyle(color: p.muted, fontSize: 12)),
                      if (i == 0) ...[
                        const SizedBox(width: 6),
                        Text('แนะนำ', style: TextStyle(color: p.lotus, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                    subtitle: Text(it.topic?.t ?? 'ซ้อมข้อสอบเก่า', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: 'เลือกหัวข้อเอง',
                      onPressed: () {
                        if (block != null) pickRound(store, today, block.start, s.code);
                        Navigator.pop(sheet);
                        openSubject(context, store, practice, subs, s);
                      },
                      icon: const Icon(Icons.list_rounded),
                    ),
                  ),
                ),
              );
            }(),
          if (block != null && isPicked(store, today, block.start))
            TextButton(
              onPressed: () {
                pickRound(store, today, block.start, null);
                Navigator.pop(sheet);
              },
              child: const Text('กลับไปใช้วิชาที่แอปแนะนำ'),
            ),
        ]),
      );
    },
  );
}

class _NowCard extends StatelessWidget {
  final Store store;
  final PracticeController practice;
  final List<Subject> subs;
  final Block block;
  final Block? next;
  final PlanItem? item;
  final int minutesNow;
  const _NowCard({required this.store, required this.practice, required this.subs, required this.block, required this.next, required this.item, required this.minutesNow});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = colorOf(block.kind);
    final left = block.end - minutesNow;
    final (String hint, String? action, VoidCallback? go) = switch (block.kind) {
      Kind.study when item != null => (
          '${item!.s.code} · ${item!.topic?.t ?? 'ซ้อมข้อสอบเก่า'}\n${item!.why}',
          item!.topic == null ? 'เริ่มซ้อมสอบ' : 'เริ่ม 3 ขั้น',
          () => startPlanItem(context, practice, store, subs, item!),
        ),
      Kind.flex when item != null => (
          'วันอิสระ: อ่านตอนไหนก็ได้ ให้ครบเป้า\nแนะนำเริ่มที่ ${item!.s.code} · ${item!.topic?.t ?? 'ซ้อมข้อสอบเก่า'}',
          item!.topic == null ? 'เริ่มซ้อมสอบ' : 'เริ่ม 3 ขั้น',
          () => startPlanItem(context, practice, store, subs, item!),
        ),
      Kind.homework => ('ทำการบ้านหรือแล็บที่ค้าง ถ้าไม่มี ทำข้อสอบเก่าหรือโจทย์ท้ายบท', 'เริ่มแค่ 2 นาที', () => openStart(context, store)),
      Kind.review || Kind.examPrep => ('ทวนการ์ดทวนจำที่ถึงรอบ และดูว่าพรุ่งนี้ต้องอ่านอะไร', 'เปิดการ์ดทวนจำ', () => openGame(context, store, 'recall')),
      Kind.klass => ('อยู่ในห้องให้ใจอยู่ด้วย วางมือถือไว้บนโต๊ะ ใจลอยเมื่อไหร่แตะจอ', 'เรียนในห้อง', () => openClassroom(context, store)),
      Kind.exam => ('ทำข้อที่มั่นใจก่อน ข้อที่ติดข้ามไปแล้วค่อยกลับมา หายใจช้า ๆ 3 ครั้งก่อนเริ่ม', null, null),
      Kind.sleep => ('ช่วงนอน · วางมือถือ สมองจะเก็บสิ่งที่อ่านวันนี้ตอนหลับ', null, null),
      Kind.rd => ('วันนี้เรียน ร.ด. ไม่นับว่าพลาด · กลับมาพักให้เต็มที่', null, null),
      Kind.free => ('เวลาว่างของจริง เล่นได้เต็มที่ไม่ต้องรู้สึกผิด เพราะถึงเวลาอ่าน เราจะกลับมาอ่าน', null, null),
      _ => ('พักให้เป็นพัก ลุกเดิน ดื่มน้ำ ไม่ต้องไถมือถือ', null, null),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.withValues(alpha: .6), width: 1.4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('ตอนนี้', style: TextStyle(color: c, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${block.span} · เหลือ ${left >= 60 ? '${left ~/ 60} ชม. ${left % 60} นาที' : '$left นาที'}', style: TextStyle(color: p.muted, fontSize: 12.5)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Icon(iconOf(block.kind), color: c, size: 30),
          const SizedBox(width: 10),
          Expanded(child: Text(block.label, style: display(context, 22))),
        ]),
        const SizedBox(height: 6),
        Text(hint, style: TextStyle(color: p.ink, height: 1.6)),
        if (action != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                go!();
              },
              style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: const Color(0xFF0B1418), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(action),
            ),
          ),
        ],
        if (block.kind == Kind.study || block.kind == Kind.flex)
          Center(
            child: TextButton.icon(
              onPressed: () => pickSubject(context, store, practice, subs, block: block.kind == Kind.study ? block : null, startNow: true),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('อยากอ่านวิชาอื่น · เลือกเอง'),
            ),
          ),
        if (next != null) ...[
          const SizedBox(height: 10),
          Text('ต่อไป ${hm(next!.start)} · ${next!.label}', style: TextStyle(color: p.muted, fontSize: 12.5)),
        ],
      ]),
    );
  }
}

/// Today's target with its progress, and the four ways to run the day.
class _DayBar extends StatelessWidget {
  final Store store;
  final List<Subject> subs;
  final Grit g;
  final DayChoice choice;
  const _DayBar({required this.store, required this.subs, required this.g, required this.choice});

  void _set(BuildContext context, DayChoice c) {
    HapticFeedback.selectionClick();
    setDayChoice(store, DateTime.now(), c);
    if (store.prefs.getBool('world-bells') == true) reschedule(store);
  }

  Future<void> _pick(BuildContext context, DayMode m) async {
    final now = DateTime.now();
    switch (m) {
      case DayMode.plan || DayMode.flex:
        _set(context, DayChoice(m));
      case DayMode.shift:
        final q = (nowMinutes(now) ~/ 15 + 1) * 15;
        final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: q ~/ 60 % 24, minute: q % 60), helpText: 'วันนี้จะเริ่มอ่านกี่โมง');
        if (t == null || !context.mounted) return;
        final first = blocksFor(now, subs).where((b) => b.countsAsStudy).firstOrNull;
        final start = t.hour * 60 + t.minute;
        if (first != null && start <= first.start) {
          toast(context, 'ตามตารางเริ่ม ${hm(first.start)} อยู่แล้ว · เลื่อนได้เฉพาะให้ช้าลง');
          return;
        }
        _set(context, DayChoice(DayMode.shift, start));
      case DayMode.rest:
        if (subs.any((s) => _same(s.at, now))) {
          toast(context, 'วันสอบไม่ต้องใช้วันพัก แอปไม่นับว่าพลาดอยู่แล้ว');
          return;
        }
        if (restDayUsedThisWeek(store, now)) {
          toast(context, 'สัปดาห์นี้ใช้วันพักไปแล้ว · ลองโหมดอิสระ หรือเลื่อนเวลาแทน');
          return;
        }
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ใช้วันพักวันนี้?'),
            content: const Text('สัปดาห์ละ 1 วัน ไม่มีเป้า ไม่นับว่าพลาด ไฟไม่ดับ\nพักให้เป็นพัก แล้วพรุ่งนี้กลับมาเต็มที่'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยังก่อน')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('พักวันนี้')),
            ],
          ),
        );
        if (ok == true && context.mounted) _set(context, const DayChoice(DayMode.rest));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final t = g.target;
    final explain = switch (choice.mode) {
      DayMode.plan => 'ตามตาราง · เป้ามาจากรอบอ่านในตารางวันนี้',
      DayMode.shift => 'เลื่อนเริ่มเป็น ${hm(choice.start ?? 0)} · ส่วนที่ล้นเวลานอนตัดออก เป้าคิดใหม่ตามเวลาที่เหลือ',
      DayMode.flex => 'อิสระ · ไม่ล็อกเวลา อ่านตอนไหนก็ได้ ขอให้ครบเป้า',
      DayMode.rest => 'วันพัก · ไม่มีเป้า ไม่นับว่าพลาด',
    };
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      border: g.goldToday ? p.gold : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('เป้าวันนี้', style: display(context, 16)),
          const Spacer(),
          Text(t == 0 ? 'ไม่มีเป้า' : '${(g.todayMin / 60).toStringAsFixed(1)} / ${(t / 60).toStringAsFixed(1)} ชม.',
              style: number(context, 15).copyWith(color: g.goldToday ? p.gold : p.ink)),
        ]),
        if (t > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(children: [
              LinearProgressIndicator(value: (g.todayMin / t).clamp(0.0, 1.0), minHeight: 10, color: g.goldToday ? p.gold : _fire, backgroundColor: p.line.withValues(alpha: .6)),
              // the 30-minute line that keeps the flame alight
              Positioned.fill(
                child: Align(
                  alignment: Alignment(((_litMinutes / t).clamp(0.0, 1.0)) * 2 - 1, 0),
                  child: Container(width: 2, color: Colors.white70),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(
            g.goldToday
                ? 'วันบัวทอง! ครบเป้าแล้ว บัวโต 2 ขั้น'
                : g.litToday
                    ? 'ไฟติดแล้ว · อ่านอีก ${((t - g.todayMin) / 60).toStringAsFixed(1)} ชม. ได้วันบัวทอง'
                    : 'ขีดขาว = 30 นาที ไฟติด · ครบเป้า = วันบัวทอง',
            style: TextStyle(color: g.goldToday ? p.gold : p.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in DayMode.values)
            ChoiceChip(
              label: Text(dayModeNames[m]!),
              selected: choice.mode == m,
              showCheckmark: false,
              onSelected: (_) => _pick(context, m),
            ),
        ]),
        const SizedBox(height: 6),
        Text(explain, style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
      ]),
    );
  }
}

class _BellSwitch extends StatefulWidget {
  final Store store;
  const _BellSwitch({required this.store});
  @override
  State<_BellSwitch> createState() => _BellSwitchState();
}

class _BellSwitchState extends State<_BellSwitch> {
  late bool on = widget.store.prefs.getBool('world-bells') ?? false;

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: on,
          title: const Text('เตือนเมื่อถึงเวลาในตาราง'),
          subtitle: const Text('เข้าเรียน · ร.ด. · รอบอ่าน · การบ้าน · วันสอบ · เช็กเป้าตอนเย็น · วางมือถือก่อนนอน'),
          onChanged: (v) async {
            setState(() => on = v);
            await widget.store.prefs.setBool('world-bells', v);
            if (v) {
              final ok = await reschedule(widget.store);
              if (!ok && mounted) {
                setState(() => on = false);
                await widget.store.prefs.setBool('world-bells', false);
                if (context.mounted) toast(context, 'ยังไม่ได้อนุญาตการแจ้งเตือน เปิดได้ที่การตั้งค่าของโทรศัพท์');
              }
            } else {
              await cancelStudyBells();
            }
          },
        ),
      );
}

// ---------------------------------------------------------------------------
// ความเพียร — the lotus, its flames, and the numbers behind them.
// ---------------------------------------------------------------------------

class _GritTab extends StatelessWidget {
  final Store store;
  const _GritTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final subs = loadPrep(store);
    final g = gritOf(store, subs);
    final today = _day(DateTime.now());
    final mins = prepMinutes(store);
    final start = dateOf(store.prefs.getString('world-start') ?? keyOf(today));
    var total = 0, week = 0;
    for (final d in store.days.values) {
      for (final s in items(d, 'sessions')) {
        if (s['kind'] != 'study' || s['class'] == true) continue;
        final m = (s['min'] as num?)?.toInt() ?? 0;
        total += m;
        if (today.difference(dateOf(d['date'] as String)).inDays < 7) week += m;
      }
    }
    final solid = subs.fold<int>(0, (a, s) => a + s.topics.where((t) => t.lv == 2).length);
    final allTopics = subs.fold<int>(0, (a, s) => a + s.topics.length);
    final maxMin = max(1, mins.values.fold<int>(0, (a, b) => a > b ? a : b));

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
      Container(
        height: 330,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const RadialGradient(center: Alignment(0, .2), radius: 1.1, colors: [Color(0xFF243B55), Color(0xFF0E1726)]),
        ),
        child: Stack(children: [
          Positioned.fill(child: _LotusOfGrit(stage: g.stage, streak: g.streak, wilted: g.wilted && !g.litToday)),
          Positioned(
            left: 18,
            top: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name, style: display(context, 22).copyWith(color: Colors.white)),
              Text(g.wilted && !g.litToday ? 'กำลังเหี่ยว · อ่านวันนี้เพื่อให้ฟื้น' : g.toNext == null ? 'ขั้นสูงสุดแล้ว รักษาไว้' : 'อีก ${g.toNext} วันที่อ่าน จะโตขึ้นอีกขั้น',
                  style: TextStyle(color: g.wilted && !g.litToday ? _warn : Colors.white70, fontSize: 12.5)),
            ]),
          ),
          Positioned(
            right: 16,
            top: 14,
            child: Column(children: [
              Icon(Icons.local_fire_department_rounded, color: g.streak > 0 ? _fire : Colors.white24, size: 30),
              Text('${g.streak} วัน', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text('ยาวสุด ${g.best}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(value: g.litToday ? 1 : g.todayMin / _litMinutes, minHeight: 6, color: _fire, backgroundColor: Colors.white12),
              ),
              const SizedBox(height: 4),
              Text(g.litToday ? 'วันนี้ไฟติดแล้ว อ่านไป ${g.todayMin} นาที' : 'วันนี้อ่านแล้ว ${g.todayMin} / $_litMinutes นาที ให้ไฟติด',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Text('อ่านวันละ $_litMinutes นาทีขึ้นไป ไฟติดและบัวโต 1 ขั้น · ครบเป้าของวัน = วันบัวทอง โต 2 ขั้น · พลาดหนึ่งวัน บัวเหี่ยว 2 ขั้น ไฟดับ · กลับมาอ่านก็ฟื้นได้เสมอ · ร.ด. วันสอบ และวันพักสัปดาห์ละ 1 วัน ไม่นับว่าพลาด',
          style: TextStyle(color: p.muted, fontSize: 12, height: 1.6)),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.3,
        children: [
          for (final (n, l) in [
            ((total / 60).toStringAsFixed(1), 'ชั่วโมงอ่านทั้งหมด'),
            ((week / 60).toStringAsFixed(1), 'ชั่วโมง 7 วันล่าสุด'),
            ('${g.goldDays}', 'วันบัวทอง'),
            ('$solid/$allTopics', 'หัวข้อที่ทำโจทย์ได้'),
          ])
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(n, style: number(context, 24)),
                Text(l, style: TextStyle(color: p.muted, fontSize: 12)),
              ]),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Text('28 วันล่าสุด', style: display(context, 17)),
      const SizedBox(height: 8),
      _FireGrid(store: store, subs: subs, start: start),
      const SizedBox(height: 20),
      Text('แต่ละวิชา', style: display(context, 17)),
      const SizedBox(height: 8),
      for (final s in [...subs]..sort((a, b) => a.at.compareTo(b.at)))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(s.code, style: TextStyle(color: p.ink, fontWeight: FontWeight.w600)),
              if (s.fav) Icon(Icons.star_rounded, size: 15, color: p.gold),
              const Spacer(),
              Text('${((mins[s.code] ?? 0) / 60).toStringAsFixed(1)} ชม. · พร้อม ${(s.ready * 100).round()}%', style: TextStyle(color: p.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Stack(children: [
              Container(height: 10, decoration: BoxDecoration(color: p.line.withValues(alpha: .6), borderRadius: BorderRadius.circular(9))),
              FractionallySizedBox(
                widthFactor: ((mins[s.code] ?? 0) / maxMin).clamp(0.0, 1.0),
                child: Container(height: 10, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE58BAB), _fire]), borderRadius: BorderRadius.circular(9))),
              ),
            ]),
          ]),
        ),
    ]);
  }
}

class _FireGrid extends StatelessWidget {
  final Store store;
  final List<Subject> subs;
  final DateTime start;
  const _FireGrid({required this.store, required this.subs, required this.start});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final today = _day(DateTime.now());
    return Column(children: [
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: [
          for (var i = 27; i >= 0; i--)
            () {
              final d = today.subtract(Duration(days: i));
              final m = studyMinutesOn(store, d);
              final rest = restDay(store, d, subs);
              final before = d.isBefore(start);
              final gold = m >= _litMinutes && goldDay(store, d, subs);
              final heat = m >= 120 ? 1.0 : m >= _litMinutes ? .65 : m > 0 ? .3 : 0.0;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: gold ? p.gold : heat > 0 ? Color.lerp(p.surface, _fire, heat) : p.surface,
                  border: Border.all(color: d == today ? p.ink : rest ? p.muted.withValues(alpha: .5) : p.line),
                ),
                alignment: Alignment.center,
                child: gold
                    ? const Icon(Icons.local_florist_rounded, size: 15, color: Colors.white)
                    : m >= _litMinutes
                        ? const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white)
                        : Text(rest && !before ? 'พัก' : '${d.day}', style: TextStyle(fontSize: 10, color: p.muted)),
              );
            }(),
        ],
      ),
      const SizedBox(height: 6),
      Text('🔥 = อ่าน $_litMinutes นาทีขึ้นไป · ช่องทองมีดอกไม้ = วันบัวทอง ครบเป้า · พัก = ร.ด. วันสอบ หรือวันพักที่เลือก',
          style: TextStyle(color: p.muted, fontSize: 11.5)),
    ]);
  }
}

/// The lotus of perseverance: opens with [stage] (0..6), ringed by up to
/// twelve flickering flames for the current [streak]; droops when [wilted].
class _LotusOfGrit extends StatefulWidget {
  final int stage, streak;
  final bool wilted;
  const _LotusOfGrit({required this.stage, required this.streak, required this.wilted});
  @override
  State<_LotusOfGrit> createState() => _LotusOfGritState();
}

class _LotusOfGritState extends State<_LotusOfGrit> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _a,
          builder: (_, _) => CustomPaint(painter: _LotusPainter(widget.stage, widget.streak, widget.wilted, _a.value)),
        ),
      );
}

class _LotusPainter extends CustomPainter {
  final int stage, streak;
  final bool wilted;
  final double t;
  _LotusPainter(this.stage, this.streak, this.wilted, this.t);

  @override
  void paint(Canvas c, Size s) {
    final base = Offset(s.width / 2, s.height * .66);
    final open = stage / 6;

    // water and leaves
    c.drawOval(Rect.fromCenter(center: base.translate(0, 26), width: s.width * .8, height: 34), Paint()..color = const Color(0xFF2B5A6B).withValues(alpha: .55));
    final leaf = Paint()..color = const Color(0xFF3F7A5C);
    c.drawOval(Rect.fromCenter(center: base.translate(-70, 20), width: 110, height: 26), leaf);
    c.drawOval(Rect.fromCenter(center: base.translate(74, 22), width: 96, height: 22), leaf);

    // flames behind the flower
    final n = min(streak, 12);
    final grow = min(streak, 30) / 30;
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 + (n == 1 ? 0 : (-1.15 + 2.3 * i / (n - 1)));
      final r = 92 + open * 26;
      final pos = base.translate(cos(a) * r, sin(a) * r * .95 - 10);
      final flick = .82 + .18 * sin(t * 2 * pi * 3 + i * 1.7);
      _flame(c, pos, (12 + grow * 10) * flick);
    }

    final petal = Color.lerp(const Color(0xFFE77FA3), const Color(0xFFF2C46B), stage >= 6 ? 1 : open * .35)!;
    final inner = Color.lerp(petal, Colors.white, .45)!;
    final grey = const Color(0xFF8D8A8F);
    Color tone(Color x) => wilted ? Color.lerp(x, grey, .5)! : x;

    if (stage == 0) {
      // a seed pod waiting under the water line
      c.drawOval(Rect.fromCenter(center: base.translate(0, -8), width: 30, height: 22), Paint()..color = tone(const Color(0xFF8F6D2C)));
      return;
    }

    final len = 46.0 + stage * 9;
    final wid = 16.0 + stage * 2.4;
    final droop = wilted ? .35 : 0.0;
    // outer ring then inner ring; each petal fans out further as it opens
    for (final (ring, count, scale, col) in [(1, 3 + stage, 1.0, petal), (0, 2 + (stage + 1) ~/ 2, .72, inner)]) {
      final spread = (.25 + open * (ring == 1 ? 1.25 : .8)) + droop;
      for (var i = 0; i < count; i++) {
        final f = count == 1 ? 0.0 : (i / (count - 1)) * 2 - 1;
        final ang = f * spread;
        final sway = sin(t * 2 * pi + i) * .02;
        _petal(c, base, ang + sway, len * scale * (wilted ? .9 : 1), wid * scale, tone(col).withValues(alpha: wilted ? .75 : .95));
      }
    }
    // the heart of the flower
    c.drawCircle(base.translate(0, -len * .28), 6 + stage * .8, Paint()..color = tone(const Color(0xFFF7D774)));
  }

  void _petal(Canvas c, Offset base, double ang, double len, double wid, Color col) {
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(ang);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-wid, -len * .45, 0, -len)
      ..quadraticBezierTo(wid, -len * .45, 0, 0);
    c.drawPath(path, Paint()..color = col);
    c.drawPath(path, Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    c.restore();
  }

  void _flame(Canvas c, Offset at, double size) {
    final path = Path()
      ..moveTo(at.dx, at.dy - size * 1.4)
      ..quadraticBezierTo(at.dx + size * .9, at.dy - size * .2, at.dx, at.dy + size * .5)
      ..quadraticBezierTo(at.dx - size * .9, at.dy - size * .2, at.dx, at.dy - size * 1.4);
    c.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFFFF5E3A), Color(0xFFFFC94A)])
              .createShader(Rect.fromCenter(center: at, width: size * 2, height: size * 2.2)));
    c.drawCircle(at.translate(0, size * .1), size * .28, Paint()..color = const Color(0xFFFFF1B8).withValues(alpha: .9));
  }

  @override
  bool shouldRepaint(covariant _LotusPainter o) => o.t != t || o.stage != stage || o.streak != streak || o.wilted != wilted;
}
