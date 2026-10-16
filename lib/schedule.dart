import 'package:flutter/material.dart';

import 'prep.dart';
import 'store.dart';

// ตารางชีวิต — the reader's week as time blocks: sleep, class, travel, meals,
// study rounds, review and rest. Study rounds alternate between the subject
// the plan says must come first and a starred favourite, so liking a subject
// earns it time without letting the weak ones slip.
//
// The week (told by the reader, 16 Oct 2026): sleep 00:00–08:00, ~30 min
// travel each way; Mon / Wed / Thu classes all day until about 17:30;
// Tue classes in the morning; Sat ร.ด. 06:00–18:00 (up 05:50, own car to the
// shuttle); Fri and Sun free.
// From the first final exam on, weekdays have no class.
//
// Each day can be adapted: follow the plan, start later (the rounds slide and
// whatever no longer fits before bed is dropped), go free (no fixed times,
// only the day's target), or take a rest day (one a week, never a miss).

enum Kind { sleep, wake, travel, klass, rd, meal, rest, free, study, homework, review, exam, examPrep, flex }

/// Study rounds are either the plan's first pick or a starred favourite.
enum Role { must, fav }

class Block {
  final int start, end; // minutes from midnight
  final Kind kind;
  final String label;
  final Role? role;
  final String? examCode;
  final int? credit; // study minutes a flex block stands for
  const Block(this.start, this.end, this.kind, this.label, {this.role, this.examCode, this.credit});

  int get minutes => end - start;
  bool get isStudy => kind == Kind.study || kind == Kind.homework;
  bool get countsAsStudy => isStudy || kind == Kind.review || kind == Kind.examPrep;
  bool get fixed => const {Kind.sleep, Kind.wake, Kind.travel, Kind.klass, Kind.rd, Kind.exam, Kind.examPrep}.contains(kind);

  /// Minutes of study this block is worth toward the day's target.
  int get studyCredit => credit ?? (countsAsStudy ? minutes : 0);

  Block shifted(int by, {int? end}) => Block(start + by, end ?? this.end + by, kind, label, role: role, examCode: examCode, credit: credit);

  String get span => '${hm(start)}–${hm(end)}';
}

String hm(int m) => '${(m ~/ 60 % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

int _t(int h, [int m = 0]) => h * 60 + m;

const _icons = {
  Kind.sleep: Icons.bedtime_rounded,
  Kind.wake: Icons.wb_sunny_rounded,
  Kind.travel: Icons.directions_bus_rounded,
  Kind.klass: Icons.school_rounded,
  Kind.rd: Icons.military_tech_rounded,
  Kind.meal: Icons.restaurant_rounded,
  Kind.rest: Icons.self_improvement_rounded,
  Kind.free: Icons.celebration_rounded,
  Kind.study: Icons.menu_book_rounded,
  Kind.homework: Icons.assignment_rounded,
  Kind.review: Icons.style_rounded,
  Kind.exam: Icons.edit_document,
  Kind.examPrep: Icons.fact_check_rounded,
  Kind.flex: Icons.all_inclusive_rounded,
};

IconData iconOf(Kind k) => _icons[k]!;

Color colorOf(Kind k) => switch (k) {
      Kind.study || Kind.flex => const Color(0xFFE58BAB),
      Kind.homework => const Color(0xFFE2B866),
      Kind.review || Kind.examPrep => const Color(0xFFB48BD9),
      Kind.exam => const Color(0xFFE8857A),
      Kind.klass || Kind.rd => const Color(0xFF6FA8DC),
      Kind.sleep => const Color(0xFF5E6B9A),
      _ => const Color(0xFF82BAB0),
    };

/// A whole-day class template, Mon / Wed / Thu.
List<Block> _fullDay() => [
      Block(0, _t(8), Kind.sleep, 'นอน'),
      Block(_t(8), _t(8, 30), Kind.wake, 'ตื่น · เตรียมตัว'),
      Block(_t(8, 30), _t(9), Kind.travel, 'เดินทาง · ทวนการ์ดบนรถได้'),
      Block(_t(9), _t(17, 30), Kind.klass, 'เรียน · ใช้ "เรียนในห้อง"'),
      Block(_t(17, 30), _t(18), Kind.travel, 'เดินทางกลับ'),
      Block(_t(18), _t(19), Kind.meal, 'กินข้าว · พัก'),
      Block(_t(19), _t(20, 30), Kind.study, 'รอบอ่าน 1', role: Role.must),
      Block(_t(20, 30), _t(20, 45), Kind.rest, 'พักสั้น ลุกเดิน'),
      Block(_t(20, 45), _t(22, 15), Kind.study, 'รอบอ่าน 2', role: Role.fav),
      Block(_t(22, 15), _t(22, 45), Kind.review, 'ทวนการ์ด · ดูตารางพรุ่งนี้'),
      Block(_t(22, 45), _t(24), Kind.rest, 'ผ่อนคลาย · วางมือถือ'),
    ];

List<Block> _tuesday() => [
      Block(0, _t(8), Kind.sleep, 'นอน'),
      Block(_t(8), _t(8, 30), Kind.wake, 'ตื่น · เตรียมตัว'),
      Block(_t(8, 30), _t(9), Kind.travel, 'เดินทาง · ทวนการ์ดบนรถได้'),
      Block(_t(9), _t(12), Kind.klass, 'เรียน · ใช้ "เรียนในห้อง"'),
      Block(_t(12), _t(12, 30), Kind.travel, 'เดินทางกลับ'),
      Block(_t(12, 30), _t(13, 30), Kind.meal, 'กินข้าว · พัก'),
      Block(_t(13, 30), _t(15), Kind.study, 'รอบอ่าน 1', role: Role.must),
      Block(_t(15), _t(15, 30), Kind.rest, 'พัก'),
      Block(_t(15, 30), _t(17), Kind.study, 'รอบอ่าน 2', role: Role.fav),
      Block(_t(17), _t(19), Kind.rest, 'ออกกำลังกาย · กินข้าว'),
      Block(_t(19), _t(20, 30), Kind.study, 'รอบอ่าน 3', role: Role.must),
      Block(_t(20, 30), _t(21), Kind.rest, 'พัก'),
      Block(_t(21), _t(22), Kind.homework, 'การบ้าน · แล็บ · งานค้าง'),
      Block(_t(22), _t(22, 30), Kind.review, 'ทวนการ์ด · ดูตารางพรุ่งนี้'),
      Block(_t(22, 30), _t(24), Kind.rest, 'ผ่อนคลาย · วางมือถือ'),
    ];

/// A free day (Fri / Sun, and weekdays once exams begin). [early] ends the
/// day at 22:30: tomorrow is ร.ด., up at 05:50 to drive to the shuttle.
List<Block> _freeDay({bool early = false, bool sunday = false}) => [
      Block(0, _t(8), Kind.sleep, 'นอน'),
      Block(_t(8), _t(9), Kind.wake, 'ตื่น · กินข้าวเช้า'),
      Block(_t(9), _t(10, 30), Kind.study, 'รอบอ่าน 1', role: Role.must),
      Block(_t(10, 30), _t(10, 45), Kind.rest, 'พักสั้น'),
      Block(_t(10, 45), _t(12, 15), Kind.study, 'รอบอ่าน 2', role: Role.fav),
      Block(_t(12, 15), _t(13, 30), Kind.meal, 'กินข้าว · พัก'),
      Block(_t(13, 30), _t(15), Kind.study, 'รอบอ่าน 3', role: Role.must),
      Block(_t(15), _t(16), Kind.rest, 'ออกกำลังกาย · พัก'),
      Block(_t(16), _t(17, 30), Kind.homework, 'การบ้าน · แล็บ · ข้อสอบเก่า'),
      Block(_t(17, 30), _t(19, 30), Kind.free, 'เวลาว่าง · กินข้าว'),
      if (early) ...[
        Block(_t(19, 30), _t(21, 30), Kind.free, 'เวลาว่าง'),
        Block(_t(21, 30), _t(22), Kind.review, 'ทวนการ์ด'),
        Block(_t(22), _t(22, 30), Kind.rest, 'เตรียมของ ร.ด. · วางมือถือ'),
        Block(_t(22, 30), _t(24), Kind.sleep, 'นอนเร็ว · พรุ่งนี้ตื่น 05:50'),
      ] else ...[
        Block(_t(19, 30), _t(20, 30), sunday ? Kind.review : Kind.study, sunday ? 'เช็กตัวเองประจำสัปดาห์ · วางแผน' : 'รอบอ่าน 4', role: sunday ? null : Role.fav),
        Block(_t(20, 30), _t(22, 30), Kind.free, 'เวลาว่าง'),
        Block(_t(22, 30), _t(23), Kind.review, 'ทวนการ์ด · ดูตารางพรุ่งนี้'),
        Block(_t(23), _t(24), Kind.rest, 'ผ่อนคลาย · วางมือถือ'),
      ],
    ];

List<Block> _saturday() => [
      Block(0, _t(5, 50), Kind.sleep, 'นอน'),
      Block(_t(5, 50), _t(6), Kind.travel, 'ตื่น · ขับรถไปจุดรถรับส่ง'),
      Block(_t(6), _t(18), Kind.rd, 'เรียน ร.ด.'),
      Block(_t(18), _t(18, 30), Kind.travel, 'เดินทางกลับ'),
      Block(_t(18, 30), _t(20), Kind.meal, 'กินข้าว · อาบน้ำ · พัก'),
      Block(_t(20), _t(20, 30), Kind.review, 'ทวนการ์ดเบา ๆ (ไม่บังคับ)'),
      Block(_t(20, 30), _t(23), Kind.free, 'พักเต็มที่ · วันนี้เหนื่อยแล้ว'),
      Block(_t(23), _t(24), Kind.sleep, 'นอน'),
    ];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Weekday templates, with exam days carved out of them.
List<Block> blocksFor(DateTime date, List<Subject> subs) {
  final d = _day(date);
  final examsBegun = subs.isNotEmpty && !d.isBefore(_day(subs.map((s) => s.at).reduce((a, b) => a.isBefore(b) ? a : b)));
  var bs = switch (d.weekday) {
    DateTime.saturday => _saturday(),
    DateTime.friday => _freeDay(early: true),
    DateTime.sunday => _freeDay(sunday: true),
    _ when examsBegun => _freeDay(),
    DateTime.tuesday => _tuesday(),
    _ => _fullDay(),
  };
  for (final s in subs.where((s) => _day(s.at) == d)) {
    bs = _carveExam(bs, s);
  }
  return bs;
}

/// Replace whatever overlaps the exam (plus a light review before and travel
/// either side) with the exam itself.
List<Block> _carveExam(List<Block> bs, Subject s) {
  final st = s.at.hour * 60 + s.at.minute, en = st + 180;
  final from = st - 90, to = en + 30;
  final kept = <Block>[];
  for (final b in bs) {
    if (b.end <= from || b.start >= to) {
      kept.add(b);
    } else {
      if (b.start < from) kept.add(Block(b.start, from, b.kind, b.label, role: b.role));
      if (b.end > to) kept.add(Block(to, b.end, b.isStudy ? Kind.rest : b.kind, b.isStudy ? 'พักหลังสอบ' : b.label));
    }
  }
  kept.addAll([
    Block(from, st - 30, Kind.examPrep, 'ทวนสรุป 1 หน้า ${s.code} · ไม่อ่านเรื่องใหม่'),
    Block(st - 30, st, Kind.travel, 'เดินทางไปห้องสอบ'),
    Block(st, en, Kind.exam, 'สอบ ${s.code}', examCode: s.code),
    Block(en, to, Kind.travel, 'เดินทางกลับ · พัก'),
  ]);
  kept.sort((a, b) => a.start - b.start);
  return kept;
}

int nowMinutes([DateTime? at]) {
  final n = at ?? DateTime.now();
  return n.hour * 60 + n.minute;
}


// ---------------------------------------------------------------------------
// Adapting a day
// ---------------------------------------------------------------------------

enum DayMode { plan, shift, flex, rest }

const dayModeNames = {DayMode.plan: 'ตามตาราง', DayMode.shift: 'เลื่อนเวลา', DayMode.flex: 'อิสระ', DayMode.rest: 'วันพัก'};

class DayChoice {
  final DayMode mode;
  final int? start; // for shift: minutes from midnight
  const DayChoice(this.mode, [this.start]);
}

String _modeKey(DateTime d) => 'daymode-${keyOf(d)}';

DayChoice dayChoice(Store store, DateTime d) {
  final raw = store.prefs.getString(_modeKey(d));
  if (raw == null) return const DayChoice(DayMode.plan);
  final [m, ...rest] = raw.split(':');
  final mode = DayMode.values.firstWhere((x) => x.name == m, orElse: () => DayMode.plan);
  return DayChoice(mode, rest.isEmpty ? null : int.tryParse(rest.first));
}

void setDayChoice(Store store, DateTime d, DayChoice c) {
  if (c.mode == DayMode.plan) {
    store.prefs.remove(_modeKey(d));
  } else {
    store.prefs.setString(_modeKey(d), c.start == null ? c.mode.name : '${c.mode.name}:${c.start}');
  }
  store.touch();
}

/// One rest day per Mon–Sun week; [d]'s own choice does not count against it.
bool restDayUsedThisWeek(Store store, DateTime d) {
  final mon = _day(d).subtract(Duration(days: d.weekday - 1));
  for (var i = 0; i < 7; i++) {
    final x = mon.add(Duration(days: i));
    if (x != _day(d) && dayChoice(store, x).mode == DayMode.rest) return true;
  }
  return false;
}

/// The day's blocks after the reader's choice for it.
List<Block> blocksOn(Store store, DateTime date, List<Subject> subs) {
  final base = blocksFor(date, subs);
  final c = dayChoice(store, date);
  return switch (c.mode) {
    DayMode.plan => base,
    DayMode.shift => _shift(base, c.start ?? 0),
    DayMode.flex => _merge(base, Kind.flex, 'อิสระ · อ่านเมื่อพร้อม ให้ครบเป้าวันนี้', base.fold(0, (a, b) => a + b.studyCredit)),
    DayMode.rest => _merge(base, Kind.free, 'วันพัก · พักผ่อนเต็มที่ ไม่นับว่าพลาด', 0),
  };
}

/// Last block before night sleep: the wind-down that stays put.
int _windDown(List<Block> bs) {
  final night = bs.lastWhere((b) => b.kind == Kind.sleep && b.start > 0, orElse: () => Block(24 * 60, 24 * 60, Kind.sleep, ''));
  final before = bs.where((b) => b.end == night.start).firstOrNull;
  return before != null && (before.kind == Kind.rest) ? before.start : night.start;
}

/// Slide everything from the first study block onward so it starts at [start];
/// what no longer fits before the wind-down is dropped.
List<Block> _shift(List<Block> bs, int start) {
  final first = bs.where((b) => b.countsAsStudy).firstOrNull;
  if (first == null || start <= first.start) return bs;
  final wd = _windDown(bs);
  final seg = bs.where((b) => b.start >= first.start && b.end <= wd).toList();
  if (seg.any((b) => b.fixed)) return bs; // exam days keep their shape
  final out = [...bs.where((b) => b.end <= first.start)];
  final from = start > wd ? wd : start;
  out.add(Block(first.start, from, Kind.free, 'เวลาว่าง · วันนี้เริ่มอ่าน ${hm(start)}'));
  final by = from - first.start;
  var end = from;
  for (final b in seg) {
    if (b.start + by >= wd) break;
    final nb = b.shifted(by, end: b.end + by > wd ? wd : b.end + by);
    out.add(nb);
    end = nb.end;
  }
  if (end < wd) out.add(Block(end, wd, Kind.free, 'เวลาว่าง'));
  out.addAll(bs.where((b) => b.start >= wd));
  return out;
}

/// Keep fixed blocks; fold each run of the others into one block of [kind]
/// that together carry [credit] study minutes, split by length.
List<Block> _merge(List<Block> bs, Kind kind, String label, int credit) {
  final runs = <(int, int)>[];
  for (final b in bs) {
    if (b.fixed) continue;
    if (runs.isNotEmpty && runs.last.$2 == b.start) {
      runs[runs.length - 1] = (runs.last.$1, b.end);
    } else {
      runs.add((b.start, b.end));
    }
  }
  final span = runs.fold(0, (a, r) => a + r.$2 - r.$1);
  return [
    ...bs.where((b) => b.fixed),
    for (final (s, e) in runs) Block(s, e, kind, label, credit: span == 0 ? 0 : (credit * (e - s) / span).round()),
  ]..sort((a, b) => a.start - b.start);
}

/// Study minutes the day asks for, after the reader's choice.
int dayTarget(Store store, DateTime d, List<Subject> subs) => blocksOn(store, d, subs).fold(0, (a, b) => a + b.studyCredit);

/// Study minutes left from [from] until [until] in the blocks still ahead.
int studyMinutesBetween(Store store, DateTime from, DateTime until, List<Subject> subs) {
  var total = 0.0;
  for (var d = _day(from); !d.isAfter(_day(until)); d = d.add(const Duration(days: 1))) {
    final lo = d == _day(from) ? nowMinutes(from) : 0;
    final hi = d == _day(until) ? until.hour * 60 + until.minute : 24 * 60;
    for (final b in blocksOn(store, d, subs)) {
      if (b.studyCredit == 0) continue;
      final s = b.start < lo ? lo : b.start, e = b.end > hi ? hi : b.end;
      if (e > s) total += b.studyCredit * (e - s) / b.minutes;
    }
  }
  return total.round();
}

/// The block running now, and the next one that starts after it.
(Block, Block?) nowAndNext(Store store, List<Subject> subs, [DateTime? at]) {
  final n = at ?? DateTime.now();
  final m = nowMinutes(n);
  final bs = blocksOn(store, n, subs);
  final i = bs.indexWhere((b) => b.start <= m && m < b.end);
  final cur = i < 0 ? bs.last : bs[i];
  Block? next = i >= 0 && i + 1 < bs.length ? bs[i + 1] : null;
  next ??= blocksOn(store, n.add(const Duration(days: 1)), subs).firstWhere((b) => b.kind != Kind.sleep, orElse: () => bs.first);
  return (cur, next);
}

/// What each study round of [date] is for, by block start.
Map<int, PlanItem> assignRounds(Store store, DateTime date, List<Subject> subs) {
  final plan = todayPlan(subs, count: subs.length);
  final used = <String>{};
  final out = <int, PlanItem>{};
  PlanItem? take(bool fav) {
    final pool = plan.where((p) => !used.contains(p.s.code));
    final pick = (fav ? pool.where((p) => p.s.fav).firstOrNull : null) ?? pool.firstOrNull ?? plan.firstOrNull;
    if (pick != null) used.add(pick.s.code);
    return pick;
  }

  final bs = blocksOn(store, date, subs).where((b) => b.kind == Kind.study && b.role != null).toList();
  // Rounds the reader picked by hand come first, so the rest fill around them.
  for (final b in bs) {
    final code = store.prefs.getString(_pickKey(date, b.start));
    final s = subs.where((s) => s.code == code).firstOrNull;
    if (s != null) {
      out[b.start] = planFor(s);
      used.add(s.code);
    }
  }
  for (final b in bs) {
    if (out.containsKey(b.start)) continue;
    final it = take(b.role == Role.fav);
    if (it != null) out[b.start] = it;
  }
  return out;
}

String _pickKey(DateTime d, int start) => 'pick-${keyOf(d)}-$start';

/// Put [code] on the round starting at [start] on [date] (null clears it).
void pickRound(Store store, DateTime date, int start, String? code) {
  if (code == null) {
    store.prefs.remove(_pickKey(date, start));
  } else {
    store.prefs.setString(_pickKey(date, start), code);
  }
  store.touch();
}

bool isPicked(Store store, DateTime date, int start) => store.prefs.getString(_pickKey(date, start)) != null;