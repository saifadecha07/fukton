import 'package:flutter/material.dart';

import 'content.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> _open(BuildContext context, Widget child) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => child,
    );

// ---------- note: lion / wind / lotus ----------
Future<void> openNoteSheet(BuildContext context, Store store, String kind) => _open(context, _NoteSheet(store, kind));

class _NoteSheet extends StatefulWidget {
  final Store store;
  final String kind;
  const _NoteSheet(this.store, this.kind);
  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late String kind = widget.kind;
  String res = 'now';
  final text = TextEditingController();

  @override
  Widget build(BuildContext context) => SheetFrame(
        title: 'บันทึกขณะใจไหว',
        action: 'บันทึกไว้',
        onSave: () {
          widget.store.mutate(todayKey(), (d) => (d['notes'] as List).add({
                'id': newId(),
                't': DateTime.now().toIso8601String(),
                'kind': kind,
                'res': res,
                'text': text.text.trim(),
              }));
          Navigator.pop(context);
          toast(context, res == 'long' ? 'รู้ว่าหลุด ก็คือเริ่มรู้แล้ว' : 'บันทึกไว้แล้ว');
        },
        children: [
          Choice<String>(
            options: [for (final i in images3) (i.id, i.name)],
            value: kind,
            onChanged: (v) => setState(() => kind = v),
          ),
          const Label('เกิดอะไรขึ้น'),
          Field(text, hint: 'เช่น ถูกแซวกลางวง ร้อนวูบขึ้นที่ใบหน้า'),
          const Label('ตอนนั้นใจเป็นยังไง'),
          Choice<String>(
            options: responses.entries.map((e) => (e.key, e.value)).toList(),
            value: res,
            onChanged: (v) => setState(() => res = v),
          ),
        ],
      );
}

// ---------- emotion ----------
Future<void> openEmotionSheet(BuildContext context, Store store) => _open(context, _EmotionSheet(store));

class _EmotionSheet extends StatefulWidget {
  final Store store;
  const _EmotionSheet(this.store);
  @override
  State<_EmotionSheet> createState() => _EmotionSheetState();
}

class _EmotionSheetState extends State<_EmotionSheet> {
  String kind = emotions.first;
  int before = 4, after = 2;
  final text = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const steps = [
      'หยุดก่อน ยังไม่เอ่ยวาจา ยังไม่พิมพ์ตอบผู้ใด',
      'หายใจเข้ายาว ผ่อนออกช้า สามครั้ง',
      'เรียกชื่อมันอย่างอ่อนโยน "นี่คือความโกรธ"',
      'สัมผัสว่ามันอยู่ตรงไหนของกาย ร้อนที่หน้า หนักที่อก',
      'อารมณ์ไม่ใช่เรา มันมาแล้วก็ไป แล้วค่อยเลือกว่าจะทำอะไร',
    ];
    return SheetFrame(
      title: 'พักใจ',
      action: 'บันทึกไว้',
      onSave: () {
        widget.store.mutate(todayKey(), (d) => (d['emotions'] as List).add({
              'id': newId(),
              't': DateTime.now().toIso8601String(),
              'kind': kind,
              'before': before,
              'after': after,
              'text': text.text.trim(),
            }));
        Navigator.pop(context);
        toast(context, after < before ? 'ใจเบาลงแล้ว' : 'เพียงรู้ว่าอารมณ์มา ก็คือมีสติแล้ว');
      },
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 24, child: Text(thaiNum(i + 1), style: TextStyle(fontFamily: serif, color: p.lotus, fontWeight: FontWeight.w600))),
              Expanded(child: Text(steps[i])),
            ]),
          ),
        const Label('อารมณ์ที่มาเยือน'),
        Choice<String>(options: [for (final e in emotions) (e, e)], value: kind, onChanged: (v) => setState(() => kind = v)),
        const Label('แรงแค่ไหน ก่อนพักใจ'),
        Choice<int>(options: [for (var n = 1; n <= 5; n++) (n, thaiNum(n))], value: before, onChanged: (v) => setState(() => before = v)),
        const Label('หลังพักใจ'),
        Choice<int>(options: [for (var n = 1; n <= 5; n++) (n, thaiNum(n))], value: after, onChanged: (v) => setState(() => after = v)),
        const Label('มาจากอะไร แล้วเราเลือกทำอะไรต่อ'),
        Field(text, lines: 2),
      ],
    );
  }
}

// ---------- exercise ----------
Future<void> openExerciseSheet(BuildContext context, Store store) => _open(context, _ExerciseSheet(store));

class _ExerciseSheet extends StatefulWidget {
  final Store store;
  const _ExerciseSheet(this.store);
  @override
  State<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<_ExerciseSheet> {
  String kind = exercises.first;
  int min = 30;
  bool mindful = true;

  @override
  Widget build(BuildContext context) => SheetFrame(
        title: 'จงแข็งแกร่ง',
        action: 'บันทึกไว้',
        onSave: () {
          widget.store.mutate(todayKey(), (d) => (d['exercise'] as List).add({
                'id': newId(),
                't': DateTime.now().toIso8601String(),
                'kind': kind,
                'min': min,
                'mindful': mindful,
              }));
          Navigator.pop(context);
          toast(context, 'กายมั่นคง ใจย่อมตั้งมั่น');
        },
        children: [
          const Label('ทำอะไร'),
          Choice<String>(options: [for (final e in exercises) (e, e)], value: kind, onChanged: (v) => setState(() => kind = v)),
          const Label('นานเท่าใด'),
          Choice<int>(options: [for (final m in exerciseMinuteOptions) (m, '${thaiNum(m)} นาที')], value: min, onChanged: (v) => setState(() => min = v)),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: mindful,
            onChanged: (v) => setState(() => mindful = v),
            title: const Text('เคลื่อนไหวอย่างรู้สึกตัว'),
            subtitle: const Text('รู้ลมหายใจ รู้ทุกย่างก้าว'),
          ),
        ],
      );
}

// ---------- evening review ----------
Future<void> openReviewSheet(BuildContext context, Store store) => _open(context, _ReviewSheet(store));

class _ReviewSheet extends StatefulWidget {
  final Store store;
  const _ReviewSheet(this.store);
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final Map<String, dynamic> r = Map<String, dynamic>.from((widget.store.day(todayKey())['review'] as Map?) ?? {});
  late final q1 = TextEditingController(text: r['q1'] as String? ?? '');
  late final friend = TextEditingController(text: r['friend'] as String? ?? '');
  late final q3 = TextEditingController(text: r['q3'] as String? ?? '');
  late bool metta = r['metta'] == true;
  late final Set<String> lok = {...((r['lok'] as List?) ?? const []).cast<String>()};

  @override
  Widget build(BuildContext context) => SheetFrame(
        title: 'ทบทวนก่อนนอน',
        action: 'บันทึกไว้',
        onSave: () {
          widget.store.mutate(todayKey(), (d) => d['review'] = {
                'at': DateTime.now().toIso8601String(),
                'q1': q1.text.trim(),
                'friend': friend.text.trim(),
                'q3': q3.text.trim(),
                'metta': metta,
                'lok': lok.toList(),
              });
          Navigator.pop(context);
          toast(context, 'ราตรีสวัสดิ์ ขอให้หลับเป็นสุข');
        },
        children: [
          const Label('วันนี้เรื่องไหนทำให้ใจไหวที่สุด'),
          Field(q1),
          const Label('โลกธรรมข้อใดมากระทบ'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in lokadhamma)
              FilterChip(
                label: Text(l),
                selected: lok.contains(l),
                showCheckmark: false,
                onSelected: (v) => setState(() => v ? lok.add(l) : lok.remove(l)),
              ),
          ]),
          const Label('วันนี้ใครเป็นกัลยาณมิตรของเรา หรือเราได้เป็นแก่ใคร'),
          Field(friend, lines: 2),
          const Label('พรุ่งนี้ ตั้งใจจะฝึกอะไร'),
          Field(q3, lines: 2),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: metta,
            onChanged: (v) => setState(() => metta = v ?? false),
            title: const Text('แผ่เมตตาแล้ว'),
            subtitle: const Text('ขอให้ตัวเราและสรรพสัตว์ทั้งปวง จงเป็นสุข พ้นจากทุกข์'),
          ),
        ],
      );
}

// ---------- sila ----------
Future<void> openSilaSheet(BuildContext context, Store store) => _open(
      context,
      ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final p = Pal.of(context);
          final d = store.day(todayKey());
          final m = (d['sila'] as Map?) ?? const {};
          final n = silaCount(d);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('จงบริสุทธิ์', style: display(context, 22)),
              Text('ศีลห้า คือผิวกลีบบัวที่หยดน้ำมิอาจเกาะ', style: TextStyle(color: p.muted)),
              const SizedBox(height: 14),
              for (var i = 0; i < sila.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => store.mutate(todayKey(), (x) => (x['sila'] as Map)['s$i'] = m['s$i'] != true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m['s$i'] == true ? p.lotus : Colors.transparent,
                          border: Border.all(color: m['s$i'] == true ? p.lotus : p.line, width: 1.5),
                        ),
                        child: Text(thaiNum(i + 1),
                            style: TextStyle(fontFamily: serif, fontWeight: FontWeight.w600, color: m['s$i'] == true ? p.onAccent : p.muted)),
                      ),
                      const SizedBox(width: 14),
                      Text(sila[i], style: TextStyle(fontSize: 16, color: m['s$i'] == true ? p.ink : p.muted)),
                    ]),
                  ),
                ),
              const SizedBox(height: 10),
              Text(n == sila.length ? 'ครบทั้งห้า ใจโปร่ง ไม่มีอะไรต้องกังวล' : 'แตะข้อที่รักษาไว้ได้ในวันนี้',
                  style: TextStyle(color: n == sila.length ? p.lotus : p.muted, fontSize: 13.5)),
            ]),
          );
        },
      ),
    );

// ---------- heart: the three images, calming, evening review ----------
Future<void> openHeartSheet(BuildContext context, Store store) => _open(context, Builder(builder: (context) {
      final p = Pal.of(context);
      Widget row(Widget lead, String title, String sub, VoidCallback onTap) => InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.pop(context);
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                SizedBox(width: 48, child: Center(child: lead)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: display(context, 17)),
                    Text(sub, style: TextStyle(color: p.muted, fontSize: 13)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: p.muted),
              ]),
            ),
          );
      final col = {'lion': p.gold, 'wind': p.pond, 'lotus': p.lotus};
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('จงสงบ', style: display(context, 22)),
          Text('ใจไหวเมื่อไหร่ บันทึกไว้ ก่อนนอนค่อยทบทวน', style: TextStyle(color: p.muted)),
          const SizedBox(height: 8),
          for (final img in images3)
            row(Glyph(img.id, col[img.id]!, size: 40), img.name, img.line, () => openNoteSheet(context, store, img.id)),
          row(Icon(Icons.air_rounded, color: p.pond, size: 30), 'พักใจ', 'หยุดหนึ่งนาที เรียกชื่ออารมณ์', () => openEmotionSheet(context, store)),
          row(Icon(Icons.nightlight_round, color: p.gold, size: 28), 'ทบทวนก่อนนอน', 'มองย้อนวันนี้ แล้วแผ่เมตตา', () => openReviewSheet(context, store)),
        ]),
      );
    }));

// ---------- personal goal for a vow ----------
Future<void> openGoalSheet(BuildContext context, Store store, int i) => _open(context, _GoalSheet(store, i));

class _GoalSheet extends StatefulWidget {
  final Store store;
  final int i;
  const _GoalSheet(this.store, this.i);
  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final text = TextEditingController(text: widget.store.prefs.getString('goal-${widget.i}') ?? vows[widget.i].goal);

  @override
  Widget build(BuildContext context) => SheetFrame(
        title: vows[widget.i].vow,
        action: 'บันทึก',
        onSave: () async {
          final t = text.text.trim();
          if (t.isEmpty) {
            await widget.store.prefs.remove('goal-${widget.i}');
          } else {
            await widget.store.prefs.setString('goal-${widget.i}', t);
          }
          widget.store.touch();
          if (context.mounted) Navigator.pop(context);
        },
        children: [
          Text(vows[widget.i].path, style: TextStyle(color: Pal.of(context).muted)),
          const Label('เป้าหมายของฉัน'),
          Field(text, lines: 2),
        ],
      );
}
