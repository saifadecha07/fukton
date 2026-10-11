import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'content.dart';
import 'store.dart';
import 'theme.dart';

/// "The mind wants to run": for the moment a game (or any escape) calls.
/// In the way of Luang Pho Thian: the urge is only a thought. See it, move
/// the hand through one round of the fourteen movements, and come back.
/// Resolves to 'study' when the reader chooses to return to their work.
Future<String?> openUrge(BuildContext context, Store store) => Navigator.of(context).push<String>(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, _, _) => UrgePage(store: store),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));

class UrgePage extends StatefulWidget {
  final Store store;
  const UrgePage({super.key, required this.store});
  @override
  State<UrgePage> createState() => _UrgePageState();
}

class _UrgePageState extends State<UrgePage> {
  static const ink = Color(0xFFF2EDE4), dim = Color(0xFF93A59D), lotus = Color(0xFFE58BAB), pond = Color(0xFF82BAB0);
  static const stepMs = 5000;

  int phase = 0; // 0 see it, 1 move the hand, 2 choose
  int before = 4, after = 3, rounds = 0;
  int step = 0;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _startRound() {
    setState(() {
      phase = 1;
      step = 0;
    });
    HapticFeedback.selectionClick();
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      HapticFeedback.selectionClick();
      if (step >= moveSteps.length - 1) {
        t.cancel();
        rounds++;
        HapticFeedback.mediumImpact();
        setState(() {
          phase = 2;
          after = before > 1 ? before - 1 : 1;
        });
        return;
      }
      setState(() => step++);
    });
  }

  void _record(String outcome) => widget.store.mutate(todayKey(), (d) => (d['urges'] as List).add({
        'id': newId(),
        't': DateTime.now().toIso8601String(),
        'before': before,
        'after': after,
        'rounds': rounds,
        'outcome': outcome,
      }));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1418),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: dim)),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: switch (phase) {
                  0 => _see(),
                  1 => _move(),
                  _ => _choose(),
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _scale(int value, ValueChanged<int> onPick) => Row(children: [
        for (var n = 1; n <= 5; n++)
          Expanded(
            child: GestureDetector(
              onTap: () => onPick(n),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: n == value ? lotus : Colors.transparent,
                  border: Border.all(color: n == value ? lotus : dim.withValues(alpha: .4)),
                ),
                child: Text(thaiNum(n),
                    style: TextStyle(fontFamily: serif, fontSize: 18, fontWeight: FontWeight.w600, color: n == value ? const Color(0xFF0B1418) : ink)),
              ),
            ),
          ),
      ]);

  Widget _see() => Column(key: const ValueKey(0), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('หยุดก่อน', style: TextStyle(fontFamily: serif, fontSize: 40, fontWeight: FontWeight.w600, color: ink)),
        const SizedBox(height: 14),
        const Text('ความอยากเล่น คือความคิดหนึ่ง\nมันเกิดขึ้นได้ ก็ย่อมดับได้\nเราไม่ต้องสู้กับมัน เพียงเห็นมัน',
            style: TextStyle(fontFamily: serif, fontSize: 19, height: 1.65, color: ink)),
        const SizedBox(height: 10),
        const Text('"เห็นความคิด อย่าเข้าไปในความคิด" — แนวหลวงพ่อเทียน จิตฺตสุโภ',
            style: TextStyle(fontSize: 13, color: dim, height: 1.5)),
        const Spacer(),
        const Text('ตอนนี้ความอยากแรงแค่ไหน', style: TextStyle(color: dim, fontSize: 14)),
        const SizedBox(height: 10),
        _scale(before, (n) => setState(() => before = n)),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _startRound,
          style: FilledButton.styleFrom(
            backgroundColor: lotus,
            foregroundColor: const Color(0xFF0B1418),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: const Text('ขยับมือหนึ่งรอบ · 70 วินาที'),
        ),
      ]);

  Widget _move() {
    final progress = (step + 1) / moveSteps.length;
    return Column(key: const ValueKey(1), children: [
      const SizedBox(height: 20),
      const Text('รู้สึกที่มือ ไม่ต้องคิดตาม', style: TextStyle(color: dim, fontSize: 14, letterSpacing: .4)),
      const Spacer(),
      SizedBox(
        width: 220,
        height: 220,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, _) => CircularProgressIndicator(value: v, strokeWidth: 3, color: lotus, backgroundColor: dim.withValues(alpha: .2)),
            ),
          ),
          Text(thaiNum(step + 1), style: const TextStyle(fontFamily: serif, fontSize: 72, fontWeight: FontWeight.w600, color: ink)),
        ]),
      ),
      const SizedBox(height: 32),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: Text(moveSteps[step],
            key: ValueKey(step), textAlign: TextAlign.center, style: const TextStyle(fontFamily: serif, fontSize: 24, height: 1.4, color: ink, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 10),
      const Text('ทำแล้วหยุด · รู้ว่าไหว รู้ว่านิ่ง', style: TextStyle(color: pond, fontSize: 14)),
      const Spacer(),
      const Text('ความอยากโผล่มาอีก ก็แค่รู้ แล้วกลับมาที่มือ', textAlign: TextAlign.center, style: TextStyle(color: dim, fontSize: 13)),
    ]);
  }

  Widget _choose() => Column(key: const ValueKey(2), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(rounds > 1 ? 'ครบ ${thaiNum(rounds)} รอบ' : 'ครบหนึ่งรอบ',
            style: const TextStyle(fontFamily: serif, fontSize: 36, fontWeight: FontWeight.w600, color: ink)),
        const SizedBox(height: 10),
        const Text('ความอยากเปลี่ยนไปหรือไม่\nสังเกตเพียงเท่านั้น', style: TextStyle(fontSize: 17, height: 1.6, color: dim)),
        const SizedBox(height: 20),
        const Text('ตอนนี้แรงแค่ไหน', style: TextStyle(color: dim, fontSize: 14)),
        const SizedBox(height: 10),
        _scale(after, (n) => setState(() => after = n)),
        const Spacer(),
        FilledButton(
          onPressed: () {
            _record('returned');
            HapticFeedback.heavyImpact();
            Navigator.of(context).pop('study');
          },
          style: FilledButton.styleFrom(
            backgroundColor: lotus,
            foregroundColor: const Color(0xFF0B1418),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: const Text('กลับไปเรียน · ชนะใจตน'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _startRound,
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: BorderSide(color: dim.withValues(alpha: .5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('อีกหนึ่งรอบ'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            _record('played');
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('ไม่เป็นไร ตั้งเวลาก่อนเล่น และรู้ตัวขณะเล่น การรู้ คือก้าวแรกแล้ว', textAlign: TextAlign.center)));
          },
          child: const Text('ยังอยากเล่นอยู่', style: TextStyle(color: dim)),
        ),
      ]);
}
