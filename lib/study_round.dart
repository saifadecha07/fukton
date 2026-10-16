import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

// รอบอ่าน 3 ขั้น — the reader's own method: read the topic yourself and ask
// AI the moment something nags; then close the slides and explain it to AI
// for checking; then fix what was wrong and try again. No step is timed;
// each says when it is done and gives a tip.

class _Step {
  final String title, how, doneWhen, tip;
  final IconData icon;
  final Color color;
  const _Step(this.title, this.how, this.doneWhen, this.tip, this.icon, this.color);
}

const _steps = [
  _Step(
    'อ่านเอง',
    'อ่านสไลด์ทีละหัวข้อด้วยตัวเอง\nงงตรงไหนจนค้างใจ ถาม AI ได้เลย ไม่ต้องเก็บไว้\nงงนิดหน่อยแต่ยังอ่านต่อได้ ปล่อยไปก่อนก็ได้',
    'อ่านจบหัวข้อ และรู้สึกว่าพอเล่าได้',
    'เรื่องที่ต้องใช้ต่อกันเป็นลำดับ เช่น เลขฐานสองก่อน subnet ต้องเคลียร์ก่อนไปต่อ',
    Icons.menu_book_rounded,
    Color(0xFF82BAB0),
  ),
  _Step(
    'ปิดแล้วดึงออก',
    'ปิดสไลด์ก่อน แล้วเอาออกมาจากหัวเอง:\nเขียนหรือวาดภาพลง iPad · เล่าด้วยคำของตัวเอง · ทำโจทย์\nเสร็จแล้วส่งให้ AI ตรวจว่าตรงไหนถูก ผิด หรือขาด',
    'เขียนหรือเล่าจนนึกไม่ออกแล้ว และ AI ตรวจแล้วว่าตรงไหนยังไม่ถูก',
    'วาดได้ = เห็นภาพ · เล่าได้ = เข้าใจ · ทำโจทย์ได้ = ใช้เป็น ถ้าเปิดสไลด์ไว้ จะไม่รู้ว่าเข้าใจจริงหรือแค่ลอก',
    Icons.draw_rounded,
    Color(0xFFE58BAB),
  ),
  _Step(
    'แก้แล้วลองใหม่',
    'กลับไปอ่านเฉพาะตรงที่ผิดหรือขาด\nแล้วปิดสไลด์ อธิบายหรือทำโจทย์ตรงนั้นใหม่อีกครั้ง',
    'ตรงที่เคยผิด ตอนนี้อธิบายหรือทำได้เองโดยไม่ดู',
    'ตรงที่เคยผิดแล้วแก้ได้ คือตรงที่จะจำได้นานที่สุด',
    Icons.replay_rounded,
    Color(0xFFB48BD9),
  ),
];

const _levels = ['ยังไม่รู้', 'พอได้', 'ทำโจทย์ได้'];
final _last = _steps.length - 1, _rateStep = _steps.length;

/// [onLevel] receives the reader's own rating of the topic at the end.
Future<void> openStudyRound(BuildContext context, Store store, {String? subject, String? topic, void Function(int level)? onLevel}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudyRoundPage(store: store, subject: subject, topic: topic, onLevel: onLevel)));

class StudyRoundPage extends StatefulWidget {
  final Store store;
  final String? subject, topic;
  final void Function(int level)? onLevel;
  const StudyRoundPage({super.key, required this.store, this.subject, this.topic, this.onLevel});
  @override
  State<StudyRoundPage> createState() => _StudyRoundPageState();
}

class _StudyRoundPageState extends State<StudyRoundPage> {
  int step = 0; // the steps, then the rating, then done
  late DateTime started = DateTime.now();
  Timer? _tick;
  bool _logged = false;

  String get _what => [widget.subject, widget.topic].whereType<String>().join(' · ');
  String get _topic => widget.topic ?? '[หัวข้อ]';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    // Only to keep the elapsed time fresh; nothing is timed.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && step <= _last) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _go(int to) {
    HapticFeedback.selectionClick();
    setState(() => step = to);
    if (step == _rateStep) _log(true);
  }

  void _log(bool done) {
    if (_logged) return;
    _logged = true;
    final min = DateTime.now().difference(started).inMinutes;
    if (min < 1) return;
    widget.store.mutate(todayKey(), (d) => (d['sessions'] as List).add({
          'id': newId(),
          'at': started.toIso8601String(),
          'min': min,
          'wander': 0,
          'types': <String, int>{},
          'done': done,
          'kind': 'study',
          'round': true,
          if (_what.isNotEmpty) 'task': _what,
          'subject': ?widget.subject,
        }));
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    toast(context, 'คัดลอกแล้ว เปิดแอป AI แล้ววางพร้อมสไลด์');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final el = DateTime.now().difference(started);
    return PopScope(
      onPopInvokedWithResult: (_, _) => _log(false),
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          backgroundColor: p.bg,
          title: Text(_what.isEmpty ? 'รอบอ่าน 3 ขั้น' : _what, style: display(context, 16), maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (step <= _last)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: Text('${el.inMinutes} นาที', style: TextStyle(color: p.muted, fontSize: 13))),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _progress(context),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: step <= _last ? _stepView(context) : step == _rateStep ? _rate(context) : _done(context),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _progress(BuildContext context) {
    final p = Pal.of(context);
    return Row(children: [
      for (var i = 0; i < _steps.length; i++) ...[
        Expanded(
          child: GestureDetector(
            // Jump back to any step already passed.
            onTap: i < step && step <= _last ? () => _go(i) : null,
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: i < step ? _steps[i].color : i == step ? _steps[i].color.withValues(alpha: .55) : p.line.withValues(alpha: .6),
                ),
              ),
              const SizedBox(height: 4),
              Icon(_steps[i].icon, size: 16, color: i <= step ? _steps[i].color : p.muted.withValues(alpha: .5)),
            ]),
          ),
        ),
        if (i < _steps.length - 1) const SizedBox(width: 4),
      ],
    ]);
  }

  Widget _stepView(BuildContext context) {
    final p = Pal.of(context);
    final s = _steps[step];
    return ListView(key: ValueKey(step), children: [
      Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: s.color.withValues(alpha: .18), shape: BoxShape.circle),
          child: Icon(s.icon, color: s.color, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ขั้นที่ ${step + 1} จาก ${_steps.length}', style: TextStyle(color: p.muted, fontSize: 12.5)),
            Text(s.title, style: display(context, 26).copyWith(color: s.color)),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Text(s.how, style: TextStyle(color: p.ink, fontSize: 16, height: 1.7)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: s.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: s.color, width: 4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('จบขั้นนี้เมื่อ', style: TextStyle(color: s.color, fontSize: 12.5, fontWeight: FontWeight.w600)),
          Text(s.doneWhen, style: TextStyle(color: p.ink, height: 1.6)),
        ]),
      ),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.tips_and_updates_outlined, size: 18, color: p.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(s.tip, style: TextStyle(color: p.muted, height: 1.6, fontSize: 13.5))),
      ]),
      const SizedBox(height: 18),
      ...switch (step) {
        0 => [
            _prompt(context, 'ถามจุดที่งง',
                'ฉันกำลังอ่านเรื่อง $_topic ฉันงงตรงนี้: [วางจุดที่งง] อธิบายให้สั้น พร้อมตัวอย่างจริง 1 อย่าง ไม่ต้องอธิบายเรื่องอื่น'),
            _prompt(context, 'เริ่มจากศูนย์ (ถ้าอ่านไม่รู้เรื่องเลย)',
                'ฉันเริ่มเรื่อง $_topic จากศูนย์ เล่าภาพรวมสั้น ๆ: คืออะไร แก้ปัญหาอะไร เปรียบเทียบกับของในชีวิตจริง 1 อย่าง และคำสำคัญ 5 คำที่ต้องรู้'),
          ],
        1 => [
            _note(context, 'ก่อนเริ่ม', 'ปิดสไลด์ แล้วค่อยพิมพ์หรือพูดอธิบาย'),
            const SizedBox(height: 10),
            _prompt(context, 'ฉันเข้าใจแบบนี้ ถูกไหม',
                'ฉันเพิ่งอ่านเรื่อง $_topic จบ จะอธิบายด้วยคำของฉัน ช่วยบอกว่าตรงไหนถูก ตรงไหนผิด ตรงไหนขาด แล้วถามคำถาม 2 ข้อเพื่อเช็กว่าฉันเข้าใจจริง รอให้ฉันตอบก่อน: [พิมพ์ที่เข้าใจ]'),
            _prompt(context, 'ขอโจทย์มาลองทำ',
                'ออกโจทย์เรื่อง $_topic แบบข้อสอบมหาวิทยาลัย 3 ข้อ จากง่ายไปยาก ห้ามเฉลยจนกว่าฉันจะส่งคำตอบ แล้วตรวจว่าผิดตรงไหน เพราะอะไร'),
          ],
        _ => [
            _note(context, 'กติกา', 'อ่านเฉพาะตรงที่ผิด ไม่ต้องอ่านใหม่ทั้งหัวข้อ\nแล้วปิดสไลด์ ลองใหม่จนทำได้เอง'),
            const SizedBox(height: 10),
            _prompt(context, 'ขอข้อใหม่ตรงที่พลาด', 'ฉันพลาดเรื่อง [ตรงที่ผิด] ใน $_topic ขอโจทย์หรือคำถามใหม่ 2 ข้อเฉพาะตรงนี้ ห้ามเฉลยจนกว่าฉันจะตอบ'),
          ],
      },
      const SizedBox(height: 22),
      FilledButton(
        onPressed: () => _go(step + 1),
        style: FilledButton.styleFrom(backgroundColor: s.color, foregroundColor: const Color(0xFF0B1418), padding: const EdgeInsets.symmetric(vertical: 15)),
        child: Text(step == _last ? 'จบรอบ' : 'ไปขั้นต่อไป · ${_steps[step + 1].title}'),
      ),
      if (step > 0)
        TextButton(onPressed: () => _go(step - 1), child: Text('ย้อนไปขั้น ${_steps[step - 1].title}', style: TextStyle(color: p.muted))),
    ]);
  }

  Widget _note(BuildContext context, String label, String text) {
    final p = Pal.of(context);
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: p.muted, fontSize: 12)),
        Text(text, style: TextStyle(color: p.ink, height: 1.6)),
      ]),
    );
  }

  Widget _prompt(BuildContext context, String title, String text) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _copy(text),
        child: Panel(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          border: p.lotus.withValues(alpha: .5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$title · แตะเพื่อคัดลอก', style: TextStyle(color: p.lotus, fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(color: p.muted, height: 1.5, fontSize: 13)),
              ]),
            ),
            Icon(Icons.copy_rounded, size: 18, color: p.muted),
          ]),
        ),
      ),
    );
  }

  Widget _rate(BuildContext context) {
    final p = Pal.of(context);
    return Column(key: const ValueKey('rate'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      Icon(Icons.flag_rounded, size: 48, color: p.lotus),
      const SizedBox(height: 10),
      Text('จบรอบแล้ว', textAlign: TextAlign.center, style: display(context, 28)),
      const SizedBox(height: 6),
      Text(widget.topic == null ? 'ตอนนี้เรื่องนี้อยู่ระดับไหน' : 'ตอนนี้ "${widget.topic}" อยู่ระดับไหน\nตอบตามจริง แอปจะได้เลือกให้ทวนถูกจุด',
          textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.6)),
      const Spacer(),
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            onPressed: () {
              widget.onLevel?.call(i);
              setState(() => step = _rateStep + 1);
            },
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            child: Text(_levels[i], style: const TextStyle(fontSize: 16)),
          ),
        ),
    ]);
  }

  Widget _done(BuildContext context) {
    final p = Pal.of(context);
    final min = DateTime.now().difference(started).inMinutes;
    return Column(key: const ValueKey('done'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      Icon(Icons.spa_rounded, size: 56, color: p.lotus),
      const SizedBox(height: 12),
      Text('อ่านไป $min นาที', textAlign: TextAlign.center, style: display(context, 26)),
      const SizedBox(height: 6),
      Text('รอบนี้ได้ดึงความรู้ออกมาเอง ไม่ใช่แค่อ่านผ่าน\nเรื่องนี้จะติดอยู่นานกว่าเดิมมาก', textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.6)),
      const Spacer(),
      FilledButton(onPressed: () => Navigator.of(context).pop(), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text('เสร็จ')),
    ]);
  }
}
