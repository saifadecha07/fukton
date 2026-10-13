import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'content.dart';
import 'scene.dart';
import 'store.dart';
import 'theme.dart';

/// Morning ritual: the creed appears line by line, then the reader
/// chooses one vow for the day and holds to commit.
Future<void> openRitual(BuildContext context, Store store) => Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, _, _) => RitualPage(store: store),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));

class RitualPage extends StatefulWidget {
  final Store store;
  const RitualPage({super.key, required this.store});
  @override
  State<RitualPage> createState() => _RitualPageState();
}

class _RitualPageState extends State<RitualPage> with TickerProviderStateMixin {
  int shown = 0; // creed lines revealed
  int? pick;
  bool done = false;
  Timer? _t;
  late final AnimationController hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _commit();
    });

  @override
  void initState() {
    super.initState();
    pick = widget.store.day(todayKey())['intent'] as int?;
    _t = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (shown >= creed.length + 1) {
        t.cancel();
        return;
      }
      setState(() => shown++);
    });
    setState(() => shown = 1);
  }

  @override
  void dispose() {
    _t?.cancel();
    hold.dispose();
    super.dispose();
  }

  void _commit() {
    if (pick == null || done) return;
    HapticFeedback.heavyImpact();
    widget.store.mutate(todayKey(), (d) => d['intent'] = pick);
    setState(() => done = true);
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _goal(int i) => widget.store.prefs.getString('goal-$i') ?? vows[i].goal;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFF2EDE4);
    const dim = Color(0xFF93A59D);
    const lotus = Color(0xFFE58BAB);
    final ready = shown > creed.length;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1418),
      body: Stack(children: [
        const Positioned.fill(child: Opacity(opacity: .35, child: PondScene(bloom: 0, tod: Tod.night))),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                const Color(0xFF0B1418).withValues(alpha: .55),
                const Color(0xFF0B1418).withValues(alpha: .92),
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ข้าม', style: TextStyle(color: dim)),
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < creed.length; i++)
                AnimatedOpacity(
                  opacity: i < shown ? 1 : 0,
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOut,
                  child: AnimatedSlide(
                    offset: i < shown ? Offset.zero : const Offset(0, .25),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOut,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(creed[i], style: const TextStyle(fontFamily: serif, fontSize: 22, height: 1.45, color: ink, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              const Spacer(),
              AnimatedOpacity(
                opacity: ready ? 1 : 0,
                duration: const Duration(milliseconds: 900),
                child: IgnorePointer(
                  ignoring: !ready,
                  child: done ? _doneView(ink, lotus) : _chooseView(ink, dim, lotus),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _doneView(Color ink, Color lotus) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ตั้งใจแล้ว', style: TextStyle(fontFamily: serif, fontSize: 28, color: lotus, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('วันนี้ ${vows[pick!].vow}', style: TextStyle(fontSize: 17, color: ink)),
        const SizedBox(height: 40),
      ]);

  Widget _chooseView(Color ink, Color dim, Color lotus) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('วันนี้ ฉันจะ…', style: TextStyle(fontSize: 15, color: Color(0xFF93A59D), letterSpacing: .5)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < vows.length; i++)
            GestureDetector(
              onTap: () => setState(() => pick = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: pick == i ? lotus : Colors.transparent,
                  border: Border.all(color: pick == i ? lotus : dim.withValues(alpha: .5)),
                ),
                child: Text(vows[i].vow,
                    style: TextStyle(fontSize: 15, color: pick == i ? const Color(0xFF0B1418) : ink, fontWeight: pick == i ? FontWeight.w600 : FontWeight.w400)),
              ),
            ),
        ]),
        SizedBox(
          height: 52,
          child: pick == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_goal(pick!), style: TextStyle(color: dim, fontSize: 14)),
                ),
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTapDown: (_) {
              if (pick != null) {
                HapticFeedback.selectionClick();
                hold.forward();
              }
            },
            onTapUp: (_) {
              if (!hold.isCompleted) hold.reverse();
            },
            onTapCancel: () {
              if (!hold.isCompleted) hold.reverse();
            },
            child: AnimatedBuilder(
              animation: hold,
              builder: (_, _) => SizedBox(
                width: 112,
                height: 112,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: hold.value,
                      strokeWidth: 3,
                      color: lotus,
                      backgroundColor: dim.withValues(alpha: .25),
                    ),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: lotus.withValues(alpha: .12 + .5 * hold.value)),
                    alignment: Alignment.center,
                    child: Text('ตั้งใจ', style: TextStyle(fontFamily: serif, fontSize: 17, color: ink, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(pick == null ? 'เลือก 1 อย่าง' : 'กดค้างไว้ จนวงเต็ม',
              style: TextStyle(color: dim, fontSize: 13)),
        ),
      ]);
}
