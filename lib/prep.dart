import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'practice.dart';
import 'schedule.dart';
import 'store.dart';
import 'study_round.dart';
import 'theme.dart';
import 'widgets.dart';

// เตรียมสอบ — final-exam preparation for this term's seven subjects.
// Each subject has an exam time, a weakness rank (from the midterm) and a
// checklist of topics rated 0 ยังไม่รู้ · 1 พอได้ · 2 ทำโจทย์ได้.
// The daily plan ranks subjects by weakness, how near the exam is and how
// ready the topics are; inside a subject it serves topics due for spaced
// review first (1, 3, 7, 14 days), then the weakest untouched ones.
// Study time runs through the practice focus screen and is logged per subject.

const _prepKey = 'prep-v1';
const _levels = ['ยังไม่รู้', 'พอได้', 'ทำโจทย์ได้'];
const _reviewGap = [1, 3, 7, 14];

class Topic {
  String t;
  int lv, n;
  String? last; // day key of the last study of this topic
  Topic(this.t, {this.lv = 0, this.n = 0, this.last});

  Map<String, dynamic> toJson() => {'t': t, 'lv': lv, 'n': n, 'last': last};
  factory Topic.fromJson(Map m) => Topic(m['t'] as String, lv: (m['lv'] as num?)?.toInt() ?? 0, n: (m['n'] as num?)?.toInt() ?? 0, last: m['last'] as String?);

  /// Studied before, and the gap for its review count has passed.
  bool dueOn(DateTime today) {
    if (n == 0 || last == null) return false;
    final gap = _reviewGap[min(n - 1, _reviewGap.length - 1)];
    return today.difference(dateOf(last!)).inDays >= gap;
  }
}

class Subject {
  final String code, name;
  final DateTime at;
  final int rank; // 7 = weakest at the midterm, 1 = strongest
  final List<Topic> topics;
  bool fav; // starred: a subject the reader likes, given the "fav" rounds
  Subject(this.code, this.name, this.at, this.rank, this.topics, {this.fav = false});

  Map<String, dynamic> toJson() =>
      {'code': code, 'name': name, 'at': at.toIso8601String(), 'rank': rank, 'fav': fav, 'topics': [for (final t in topics) t.toJson()]};
  factory Subject.fromJson(Map m) => Subject(
        m['code'] as String,
        m['name'] as String,
        DateTime.parse(m['at'] as String),
        (m['rank'] as num).toInt(),
        [for (final t in (m['topics'] as List)) Topic.fromJson(t as Map)],
        fav: m['fav'] == true,
      );

  /// 0..1: how many topic levels are already reached.
  double get ready => topics.isEmpty ? 0 : topics.fold<int>(0, (a, t) => a + t.lv) / (topics.length * 2);

  int daysLeft(DateTime today) => DateTime(at.year, at.month, at.day).difference(today).inDays;

  String get when => '${at.day} ${_months[at.month - 1]} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')} น.';
}

const _months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

// Final exams, term 1/2569. Topics are the usual outline for each course;
// the reader edits them to match what was actually taught.
List<Subject> _seed() => [
      Subject('CN320', 'Computer Network Configuration', DateTime(2026, 11, 26, 9), 7, [
        for (final t in [
          'คำสั่งพื้นฐาน Cisco IOS (โหมด, show, save config)',
          'IP addressing · Subnetting · VLSM',
          'Static routing',
          'Dynamic routing: RIP / OSPF',
          'VLAN · Trunk (802.1Q)',
          'Inter-VLAN routing',
          'STP',
          'DHCP · NAT · ACL บน router',
          'Troubleshooting: ping, traceroute, show ip route',
        ])
          Topic(t),
      ]),
      Subject('CN321', 'Data Communication & Computer Networks I', DateTime(2026, 11, 30, 9), 6, [
        for (final t in [
          'OSI 7 layers · TCP/IP model',
          'สัญญาณ · bandwidth · throughput · delay (คำนวณ)',
          'Encoding · Modulation',
          'Error detection: parity, CRC, checksum',
          'Data link: framing, flow control, MAC, Ethernet',
          'Circuit vs packet switching',
          'IPv4 · Subnetting · IPv6 เบื้องต้น',
          'Routing concepts',
          'TCP vs UDP · 3-way handshake · congestion',
          'Application layer: DNS, HTTP',
        ])
          Topic(t),
      ]),
      Subject('CN360', 'Digital & Microcontroller System Dev', DateTime(2026, 12, 3, 13), 5, [
        for (final t in [
          'ทบทวน digital: logic, combinational, sequential',
          'สถาปัตยกรรม MCU: register, memory map',
          'GPIO: input/output, pull-up, debounce',
          'Interrupt',
          'Timer · PWM',
          'ADC',
          'Serial: UART · I2C · SPI',
          'เขียนโค้ดคุมอุปกรณ์: LED, switch, display, sensor',
        ])
          Topic(t),
      ]),
      Subject('CN331', 'Software Engineering', DateTime(2026, 12, 2, 13), 4, [
        for (final t in [
          'SDLC: Waterfall, V-model, Spiral, Incremental',
          'Agile · Scrum',
          'Requirements: functional / non-functional · user story',
          'UML: use case, class, sequence, activity',
          'Design: architecture, cohesion/coupling, patterns',
          'Testing: unit/integration/system · black/white box',
          'Project management: estimation, risk',
          'Maintenance · version control',
        ])
          Topic(t),
      ]),
      Subject('CN330', 'Computer Application Development', DateTime(2026, 11, 25, 9), 3, [
        for (final t in [
          'OOP: class, object, encapsulation',
          'Inheritance · polymorphism',
          'Interface · abstract class',
          'Exception handling',
          'GUI · event-driven',
          'File I/O · database',
          'Collections ใช้งานจริง',
          'MVC · โครงสร้างแอป',
        ])
          Topic(t),
      ]),
      Subject('CN310', 'Computer Server Configuration', DateTime(2026, 12, 2, 9), 2, [
        for (final t in [
          'Linux พื้นฐาน: ไฟล์, permission, user',
          'Package · service (systemd)',
          'ตั้งค่า network บน server',
          'SSH',
          'DHCP server',
          'DNS server',
          'Web server: Apache / Nginx',
          'File sharing: Samba / NFS · FTP',
          'Firewall · log · backup',
        ])
          Topic(t),
      ]),
      Subject('CN361', 'Microprocessor Systems Design', DateTime(2026, 12, 4, 9), 1, [
        for (final t in [
          'CPU: register, ALU, bus, fetch-decode-execute',
          'Instruction set · addressing modes',
          'Assembly programming',
          'Stack · subroutine',
          'Memory interfacing · address decoding',
          'I/O: memory-mapped vs isolated',
          'Interrupt · DMA',
          'Timing diagram',
        ])
          Topic(t),
      ]),
    ];

List<Subject> loadPrep(Store store) {
  final raw = store.prefs.getString(_prepKey);
  if (raw != null) {
    try {
      return [for (final s in jsonDecode(raw) as List) Subject.fromJson(s as Map)];
    } catch (_) {}
  }
  return _seed();
}

void savePrep(Store store, List<Subject> subs) {
  store.prefs.setString(_prepKey, jsonEncode([for (final s in subs) s.toJson()]));
  store.touch();
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Minutes of focused study logged against each subject code.
Map<String, int> prepMinutes(Store store) {
  final m = <String, int>{};
  for (final d in store.days.values) {
    for (final s in items(d, 'sessions')) {
      final c = s['subject'] as String?;
      if (c != null) m[c] = (m[c] ?? 0) + ((s['min'] as num?)?.toInt() ?? 0);
    }
  }
  return m;
}

/// One suggestion in today's plan.
class PlanItem {
  final Subject s;
  final Topic? topic;
  final String why;
  final bool mock;
  PlanItem(this.s, this.topic, this.why, {this.mock = false});
}

List<PlanItem> todayPlan(List<Subject> subs, {int count = 3}) {
  final today = _today();
  final open = subs.where((s) => s.daysLeft(today) >= 0).toList();
  double score(Subject s) {
    final d = max(0, s.daysLeft(today));
    final weak = .55 + .45 * (s.rank / 7);
    final need = 1 - .8 * s.ready;
    final soon = 1 / sqrt(d + 1);
    return weak * need * (.35 + soon);
  }

  open.sort((a, b) => score(b).compareTo(score(a)));
  return [for (final s in open.take(count)) planFor(s)];
}

/// The next thing to study in [s]: a mock exam close to the exam once every
/// topic has been touched, else a topic due for review, else the weakest.
PlanItem planFor(Subject s) {
  final today = _today();
  final k = keyOf(today);
  final d = s.daysLeft(today);
  if (d <= 7 && s.topics.isNotEmpty && s.topics.every((t) => t.n > 0)) {
    return PlanItem(s, null, 'อีก $d วันสอบ · ซ้อมข้อสอบเก่าจับเวลา', mock: true);
  }
  final due = s.topics.where((t) => t.dueOn(today) && t.last != k).toList()..sort((a, b) => a.lv - b.lv);
  if (due.isNotEmpty) return PlanItem(s, due.first, 'ถึงรอบทวน');
  final fresh = s.topics.where((t) => t.last != k && t.lv < 2).toList()..sort((a, b) => a.lv != b.lv ? a.lv - b.lv : a.n - b.n);
  if (fresh.isNotEmpty) return PlanItem(s, fresh.first, fresh.first.n == 0 ? 'ยังไม่ได้เริ่ม' : 'ยังไม่แน่น');
  return PlanItem(s, null, 'หัวข้อครบแล้ว · ซ้อมข้อสอบเก่า', mock: true);
}

/// A subject's topic list, to pick a topic by hand.
Future<void> openSubject(BuildContext context, Store store, PracticeController practice, List<Subject> subs, Subject s) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Theme(data: Theme.of(context), child: _SubjectPage(store: store, practice: practice, subs: subs, s: s))));

/// Start what a plan item asks for: the five-step round on its topic, or a
/// timed mock exam when there is no topic left to learn.
Future<void> startPlanItem(BuildContext context, PracticeController c, Store store, List<Subject> subs, PlanItem it) async {
  if (it.topic == null) {
    _study(context, c, store, subs, it.s, null, 180);
  } else {
    await _round(context, store, subs, it.s, it.topic!);
  }
}

/// Start a focus-screen study block for [s], optionally on one topic.
void _study(BuildContext context, PracticeController c, Store store, List<Subject> subs, Subject s, Topic? t, int minutes) {
  final task = t == null ? '${s.code} · ซ้อมข้อสอบเก่า' : '${s.code} · ${t.t}';
  if (!c.startStudy(minutes: minutes, task: task, subject: s.code)) {
    toast(context, 'มีรอบฝึกค้างอยู่ในแท็บฝึก จบรอบนั้นก่อนนะ');
    return;
  }
  HapticFeedback.mediumImpact();
  openFocus(context, c);
  if (t != null) {
    t.last = todayKey();
    t.n++;
    savePrep(store, subs);
  }
}

/// Study one topic through the guided five-step round; the reader's rating
/// at the end becomes the topic's level.
Future<void> _round(BuildContext context, Store store, List<Subject> subs, Subject s, Topic t) => openStudyRound(
      context,
      store,
      subject: s.code,
      topic: t.t,
      onLevel: (lv) {
        t.lv = lv;
        t.last = todayKey();
        t.n++;
        savePrep(store, subs);
      },
    );

/// The study world's subjects tab: readiness, exam table, stars.
class PrepPage extends StatefulWidget {
  final Store store;
  final PracticeController practice;
  const PrepPage({super.key, required this.store, required this.practice});
  @override
  State<PrepPage> createState() => _PrepPageState();
}

class _PrepPageState extends State<PrepPage> {
  List<Subject> get subs => loadPrep(widget.store);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mins = prepMinutes(widget.store);
    final all = subs;
    final byDate = [...all]..sort((a, b) => a.at.compareTo(b.at));
    final allReady = all.fold<double>(0, (a, s) => a + s.ready) / all.length;
    final now = DateTime.now();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('วิชาและตารางสอบ', style: display(context, 22)),
            Text('แตะดาว ☆ ให้วิชาที่ชอบ · แอปจะสลับให้ได้อ่านวิชาที่ชอบกับวิชาที่ต้องทำ', style: TextStyle(color: p.muted, fontSize: 12.5)),
          ]),
        ),
        _Ring(value: allReady, label: 'พร้อม'),
      ]),
      const SizedBox(height: 16),
      for (final s in byDate)
        _subjectTile(context, all, s, mins[s.code] ?? 0, s.at.isAfter(now) ? studyMinutesBetween(widget.store, now, s.at, all) : 0),
    ]);
  }

  Widget _subjectTile(BuildContext context, List<Subject> all, Subject s, int min, int leftMin) {
    final p = Pal.of(context);
    final d = s.daysLeft(_today());
    final done = d < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Theme(data: Theme.of(context), child: _SubjectPage(store: widget.store, practice: widget.practice, subs: all, s: s))));
          if (mounted) setState(() {});
        },
        child: Panel(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(children: [
            SizedBox(
              width: 54,
              child: Column(children: [
                Text(done ? '✓' : '$d', style: number(context, 24).copyWith(color: done ? p.muted : d <= 7 ? p.lotus : p.ink)),
                Text(done ? 'สอบแล้ว' : 'วัน', style: TextStyle(color: p.muted, fontSize: 11)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(s.code, style: display(context, 16)),
                  const SizedBox(width: 6),
                  if (s.rank >= 6) Text('อ่อน', style: TextStyle(color: p.lotus, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]),
                Text(s.name, style: TextStyle(color: p.ink, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${s.when} · อ่านแล้ว ${(min / 60).toStringAsFixed(1)} ชม.', style: TextStyle(color: p.muted, fontSize: 12)),
                if (!done) Text('เวลาอ่านจริงก่อนสอบ ~${(leftMin / 60).round()} ชม. (ใช้ร่วมกับวิชาอื่น)', style: TextStyle(color: p.muted, fontSize: 12)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(value: s.ready, minHeight: 6, color: p.pond, backgroundColor: p.line.withValues(alpha: .6)),
                ),
              ]),
            ),
            IconButton(
              tooltip: s.fav ? 'เลิกติดดาว' : 'ติดดาว วิชาที่ชอบ',
              onPressed: () {
                HapticFeedback.selectionClick();
                s.fav = !s.fav;
                savePrep(widget.store, all);
                setState(() {});
              },
              icon: Icon(s.fav ? Icons.star_rounded : Icons.star_outline_rounded, color: s.fav ? p.gold : p.muted),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double value;
  final String label;
  const _Ring({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(child: CircularProgressIndicator(value: value, strokeWidth: 6, color: p.pond, backgroundColor: p.line.withValues(alpha: .6))),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${(value * 100).round()}%', style: number(context, 16)),
          Text(label, style: TextStyle(color: p.muted, fontSize: 10.5)),
        ]),
      ]),
    );
  }
}

class _SubjectPage extends StatefulWidget {
  final Store store;
  final PracticeController practice;
  final List<Subject> subs;
  final Subject s;
  const _SubjectPage({required this.store, required this.practice, required this.subs, required this.s});
  @override
  State<_SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<_SubjectPage> {
  Subject get s => widget.s;

  void _save() {
    savePrep(widget.store, widget.subs);
    setState(() {});
  }

  Future<void> _edit([Topic? t]) async {
    final c = TextEditingController(text: t?.t ?? '');
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t == null ? 'เพิ่มหัวข้อ' : 'แก้หัวข้อ'),
        content: TextField(controller: c, autofocus: true, maxLength: 100, decoration: const InputDecoration(hintText: 'เช่น OSPF single area')),
        actions: [
          if (t != null) TextButton(onPressed: () => Navigator.pop(ctx, '\u0000'), child: const Text('ลบหัวข้อนี้')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('บันทึก')),
        ],
      ),
    );
    if (r == null) return;
    if (r == '\u0000') {
      s.topics.remove(t);
    } else if (r.isEmpty) {
      return;
    } else if (t == null) {
      s.topics.add(Topic(r));
    } else {
      t.t = r;
    }
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final today = _today();
    final d = s.daysLeft(today);
    final min = prepMinutes(widget.store)[s.code] ?? 0;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: p.bg, title: Text(s.code, style: display(context, 19))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('เพิ่มหัวข้อ')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
        Text(s.name, style: display(context, 20)),
        Text('สอบ ${s.when}${d >= 0 ? ' · อีก $d วัน' : ' · สอบแล้ว'} · อ่านแล้ว ${(min / 60).toStringAsFixed(1)} ชม.', style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(value: s.ready, minHeight: 8, color: p.pond, backgroundColor: p.line.withValues(alpha: .6)),
        ),
        const SizedBox(height: 4),
        Text('พร้อม ${(s.ready * 100).round()}% · แตะสถานะเพื่อเปลี่ยน · แตะชื่อหัวข้อเพื่อแก้', style: TextStyle(color: p.muted, fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _study(context, widget.practice, widget.store, widget.subs, s, null, 180),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('ซ้อมข้อสอบเก่า 3 ชม.'),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        for (final t in s.topics) _topicRow(context, t, today),
        if (s.topics.isEmpty) Text('ยังไม่มีหัวข้อ กดเพิ่มหัวข้อด้านล่าง', style: TextStyle(color: p.muted)),
      ]),
    );
  }

  Widget _topicRow(BuildContext context, Topic t, DateTime today) {
    final p = Pal.of(context);
    final colors = [p.line, p.gold, p.pond];
    final due = t.dueOn(today);
    final note = t.n == 0
        ? 'ยังไม่ได้อ่าน'
        : 'อ่านแล้ว ${t.n} รอบ · ล่าสุด ${today.difference(dateOf(t.last!)).inDays == 0 ? 'วันนี้' : '${today.difference(dateOf(t.last!)).inDays} วันก่อน'}${due ? ' · ถึงรอบทวน' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              t.lv = (t.lv + 1) % 3;
              _save();
            },
            child: Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: colors[t.lv].withValues(alpha: t.lv == 0 ? .35 : .22),
                border: Border.all(color: colors[t.lv]),
              ),
              child: Text(_levels[t.lv], textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: p.ink, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _edit(t),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.t, style: TextStyle(color: p.ink, fontSize: 14.5)),
                Text(note, style: TextStyle(color: due ? p.lotus : p.muted, fontSize: 11.5)),
              ]),
            ),
          ),
          IconButton(
            tooltip: 'อ่านหัวข้อนี้ · รอบ 3 ขั้น',
            onPressed: () async {
              await _round(context, widget.store, widget.subs, s, t);
              if (mounted) setState(() {});
            },
            icon: Icon(Icons.play_circle_fill_rounded, color: p.lotus, size: 32),
          ),
        ]),
      ),
    );
  }
}

