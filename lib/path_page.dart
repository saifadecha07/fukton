import 'dart:math';

import 'package:flutter/material.dart';

import 'content.dart';
import 'extras.dart';
import 'store.dart';
import 'theme.dart';
import 'version.dart';
import 'widgets.dart';

class PathPage extends StatelessWidget {
  final Store store;
  const PathPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final days = store.days.values.toList();
    final totalMin = days.fold<int>(0, (a, d) => a + minutesOf(d));
    final studyMin = days.fold<int>(0, (a, d) => a + minutesOf(d, ['study']));
    final notes = [for (final d in days) for (final n in items(d, 'notes')) {...n, 'day': d['date'], 'type': 'note'}];
    final emos = [for (final d in days) for (final e in items(d, 'emotions')) {...e, 'day': d['date'], 'type': 'emo'}];
    final worries = [for (final d in days) for (final w in items(d, 'worries')) {...w, 'day': d['date'], 'type': 'worry'}];
    final caught = notes.where((n) => n['res'] != 'long').length;
    final best = store.longestStreak();

    final types = <String, int>{};
    for (final d in days) {
      for (final s in items(d, 'sessions')) {
        ((s['types'] as Map?) ?? const {}).forEach((k, v) => types[k as String] = (types[k] ?? 0) + (v as num).toInt());
      }
    }
    final ranked = types.entries.toList()..sort((a, b) => b.value - a.value);

    final stats = [
      (thaiNum(store.streak()), 'วันต่อเนื่อง'),
      (thaiNum(urgesWon(days)), 'ครั้งที่ชนะใจตน'),
      ('${detoxStreak(store.days)}', 'วันใจสะอาดติดกัน'),
      ('${detoxBest(store.days)}', 'ใจสะอาดนานที่สุด (วัน)'),
      (thaiNum(totalMin - studyMin), 'นาทีดูลม · จังหวะมือ'),
      (thaiNum(studyMin), 'นาทีเรียนอย่างมีสติ'),
      (notes.isEmpty ? '–' : '${thaiNum((caught * 100 / notes.length).round())}%', 'รู้ตัวทัน'),
      (thaiNum(days.fold<int>(0, (a, d) => a + exerciseMinutes(d))), 'นาทีออกกำลังกาย'),
      (thaiNum(days.where((d) => silaCount(d) == sila.length).length), 'วันที่ศีลครบห้า'),
      (thaiNum(days.where((d) => (d['card'] as Map?)?['done'] == true).length), 'ภารกิจไพ่ธรรม'),
    ];

    final recent = [...notes, ...emos, ...worries]..sort((a, b) => (b['t'] as String).compareTo(a['t'] as String));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text('เส้นทาง', style: display(context, 26)),
        const SizedBox(height: 4),
        Text('รอยเท้าเมื่อวาน คือทางของวันพรุ่ง', style: TextStyle(color: p.muted)),
        const SizedBox(height: 18),
        LotusGarden(store: store),
        const SizedBox(height: 22),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: [
            for (final (n, l) in stats)
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(n, style: number(context, 24)),
                  Text(l, style: TextStyle(color: p.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const Eyebrow('ยี่สิบแปดวันที่ผ่านมา'),
        const SizedBox(height: 10),
        _Grid28(store: store),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _legend(context, Color.lerp(p.surface, p.pond, .3)!, '๑–๙ นาที'),
          _legend(context, Color.lerp(p.surface, p.pond, .6)!, '๑๐–๑๙'),
          _legend(context, p.pond, '๒๐ ขึ้นไป'),
          _legend(context, p.lotus, 'มีบันทึก', dot: true),
        ]),
        if (ranked.isNotEmpty) ...[
          const SizedBox(height: 22),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('ความคิดที่มักพาใจไปไกล'),
              const SizedBox(height: 6),
              for (final e in ranked.take(3))
                Text.rich(TextSpan(children: [
                  TextSpan(text: e.key),
                  TextSpan(text: '  ·  ${thaiNum(e.value)} ครั้ง', style: TextStyle(color: p.muted)),
                ])),
              const SizedBox(height: 6),
              Text('รู้จักนิสัยของความคิด ก็จะรู้ทันได้ไวขึ้น', style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
        ],
        const SizedBox(height: 22),
        const Eyebrow('เหรียญแห่งความเพียร'),
        const SizedBox(height: 10),
        Row(children: [
          for (final (n, name) in badges)
            Expanded(
              child: Column(children: [
                CustomPaint(size: const Size.square(58), painter: _Medal(n, best >= n, p)),
                const SizedBox(height: 4),
                Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: best >= n ? p.ink : p.muted)),
                Text(best >= n ? 'ได้รับแล้ว' : 'อีก ${thaiNum(n - best)} วัน', style: TextStyle(fontSize: 11, color: p.muted)),
              ]),
            ),
        ]),
        const SizedBox(height: 24),
        const Eyebrow('บันทึกล่าสุด'),
        const SizedBox(height: 4),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Panel(
              child: Text('ยังไม่มีบันทึก ใจไหวเมื่อไหร่ เช่น ถูกตำหนิแล้วร้อนวูบ แตะ “จงสงบ” ในหน้าวันนี้ แล้วเลือกราชสีห์ สายลม หรือดอกบัว',
                  style: TextStyle(color: p.muted, height: 1.6)),
            ),
          ),
        for (final n in recent.take(30)) _entry(context, n),
        const SizedBox(height: 28),
        Center(child: Text('ฝึกตน เวอร์ชัน $appVersion (build $appBuild)', style: TextStyle(fontSize: 12, color: p.muted))),
      ],
    );
  }

  Widget _legend(BuildContext context, Color c, String t, {bool dot = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: dot ? BoxShape.circle : BoxShape.rectangle, borderRadius: dot ? null : BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(t, style: TextStyle(fontSize: 12, color: Pal.of(context).muted)),
      ]);

  Widget _entry(BuildContext context, Map<String, dynamic> n) {
    final p = Pal.of(context);
    final worry = n['type'] == 'worry';
    final emo = n['type'] == 'emo' || worry;
    final img = emo ? null : images3.firstWhere((i) => i.id == n['kind'], orElse: () => images3.first);
    final tag = worry ? 'ใจขุ่น · ${n['kind'] ?? ''}' : emo ? n['kind'] as String : img!.name;
    final sub = worry
        ? (n['can'] == true ? 'ก้าวแรก: ${n['step'] ?? ''}' : 'ปล่อยให้ลมพัดไป')
        : emo
            ? 'แรง ${thaiNum(n['before'])} → ${thaiNum(n['after'])}'
            : (responses[n['res']] ?? '');
    final col = worry ? const Color(0xFF8B93D9) : emo ? p.gold : {'lion': p.gold, 'wind': p.pond, 'lotus': p.lotus}[img!.id]!;
    final text = (n['text'] as String?) ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(thaiShortDateTime(DateTime.parse(n['t'] as String).toLocal()), style: TextStyle(fontSize: 12, color: p.muted)),
            const SizedBox(height: 2),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(border: Border.all(color: col), borderRadius: BorderRadius.circular(99)),
                child: Text(tag, style: TextStyle(fontSize: 12, color: col)),
              ),
              Text(sub, style: TextStyle(fontSize: 12.5, color: p.muted)),
            ]),
            const SizedBox(height: 4),
            Text(text.isEmpty ? (worry ? 'วางลงแล้ว' : emo ? 'พักใจแล้ว' : 'ไม่ได้บันทึกรายละเอียด') : text, style: TextStyle(color: text.isEmpty ? p.muted : p.ink)),
          ]),
        ),
        IconButton(
          tooltip: 'ลบ',
          icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('ลบบันทึกนี้?'),
                content: const Text('ลบแล้วกู้คืนไม่ได้'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('เก็บไว้')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ลบ')),
                ],
              ),
            );
            if (ok == true) {
              store.mutate(n['day'] as String, (d) {
                (d['notes'] as List).removeWhere((x) => (x as Map)['id'] == n['id']);
                (d['emotions'] as List).removeWhere((x) => (x as Map)['id'] == n['id']);
                (d['worries'] as List).removeWhere((x) => (x as Map)['id'] == n['id']);
              });
            }
          },
        ),
      ]),
    );
  }
}

class _Grid28 extends StatelessWidget {
  final Store store;
  const _Grid28({required this.store});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 27));
    const wk = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    return Column(children: [
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(child: Center(child: Text(wk[start.add(Duration(days: i)).weekday - 1], style: TextStyle(fontSize: 11, color: p.muted)))),
      ]),
      const SizedBox(height: 6),
      GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (var i = 0; i < 28; i++)
          Builder(builder: (_) {
            final dt = start.add(Duration(days: i));
            final d = store.days[keyOf(dt)];
            final m = d == null ? 0 : minutesOf(d);
            final hasNote = d != null && (items(d, 'notes').isNotEmpty || items(d, 'emotions').isNotEmpty);
            final c = m >= 20 ? p.pond : m >= 10 ? Color.lerp(p.surface, p.pond, .6)! : m > 0 ? Color.lerp(p.surface, p.pond, .3)! : p.surface;
            final isToday = i == 27;
            return Tooltip(
              message: '${dt.day} ${thaiMonthsShort[dt.month - 1]} · ${thaiNum(m)} นาที',
              child: Container(
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: isToday ? p.ink : (m > 0 ? Colors.transparent : p.line), width: isToday ? 2 : 1),
                ),
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(4),
                child: hasNote ? Container(width: 6, height: 6, decoration: BoxDecoration(color: p.lotus, shape: BoxShape.circle)) : null,
              ),
            );
          }),
      ],
    ),
    ]);
  }
}

class _Medal extends CustomPainter {
  final int n;
  final bool got;
  final Pal p;
  _Medal(this.n, this.got, this.p);

  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 64;
    c.scale(k);
    c.drawCircle(const Offset(32, 32), 30, Paint()..color = p.surface);
    c.drawCircle(
        const Offset(32, 32),
        30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = got ? p.gold : p.line);
    final petals = min(8, 3 + badges.indexWhere((b) => b.$1 == n));
    for (var i = 0; i < petals; i++) {
      final a = (i - (petals - 1) / 2) * (150 / petals) * pi / 180;
      c.save();
      c.translate(32, 40);
      c.rotate(a);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(-5, -10, -4, -18, 0, -25)
        ..cubicTo(4, -18, 5, -10, 0, 0);
      if (got) c.drawPath(path, Paint()..color = p.lotus.withValues(alpha: i.isEven ? .6 : 1));
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = p.lotus.withValues(alpha: got ? 1 : .55));
      c.restore();
    }
    final tp = TextPainter(
      text: TextSpan(text: thaiNum(n), style: TextStyle(fontFamily: sans, fontSize: 10, fontWeight: FontWeight.w600, color: got ? p.gold : p.muted)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(32 - tp.width / 2, 48));
  }

  @override
  bool shouldRepaint(covariant _Medal old) => old.got != got || old.p != p;
}
