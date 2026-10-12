import 'package:flutter/material.dart';

import 'content.dart';
import 'calm.dart';
import 'detox.dart';
import 'extras.dart';
import 'mascot.dart';
import 'ritual.dart';
import 'scene.dart';
import 'sheets.dart';
import 'store.dart';
import 'theme.dart';
import 'urge.dart';

class TodayPage extends StatelessWidget {
  final Store store;
  final void Function(String mode) onPractice;
  final VoidCallback onSettings;
  const TodayPage({super.key, required this.store, required this.onPractice, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final k = todayKey();
    final d = store.day(k);
    final dayNum = dateOf(k).millisecondsSinceEpoch ~/ 864e5;
    final pillars = pillarsOf(d);
    final bloom = pillars.where((x) => x == 2).length;
    final streak = store.streak();
    final intent = d['intent'] as int?;
    final night = todNow() == Tod.night;
    final onScene = night ? const Color(0xFFF2EDE4) : const Color(0xFF15201C);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(children: [
          BuaNoi(mood: moodFor(bloom), size: 58),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${greeting(DateTime.now())}${(store.prefs.getString('name') ?? '').isEmpty ? '' : ' ${store.prefs.getString('name')}'}',
                  style: display(context, 20)),
              Text(buaSays(bloom, DateTime.now().hour).replaceAll('\n', ' '), style: TextStyle(color: p.lotus, fontSize: 12.5)),
            ]),
          ),
          IconButton(onPressed: onSettings, icon: Icon(Icons.notifications_none_rounded, color: p.muted), tooltip: 'ระฆังเตือนใจ'),
        ]),

        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(thaiLongDate(DateTime.now()), style: TextStyle(color: p.muted, fontSize: 12.5, letterSpacing: .3)),
        ),
        // The pond, with one line of the creed.
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 340,
            child: Stack(children: [
              Positioned.fill(child: PondScene(bloom: bloom, decor: store.prefs.getStringList('decor') ?? const [])),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [
                      (night ? const Color(0xFF0B1418) : const Color(0xFFFFFCF6)).withValues(alpha: .55),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                top: 22,
                right: 22,
                child: Text(
                  creedOnPond[dayNum % creedOnPond.length],
                  style: TextStyle(fontFamily: serif, fontSize: 25, height: 1.45, fontWeight: FontWeight.w600, color: onScene),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 14,
                child: Text(
                  '${bloomLines[bloom]}${streak > 0 ? '  ·  วันที่ ${thaiNum(streak)}' : ''}',
                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .85), letterSpacing: .3),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // The two smallest doors back to the present.
        Row(children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.air_rounded,
              title: 'สามลมหายใจ',
              sub: 'สามสิบวินาที',
              color: p.pond,
              onTap: () => openThreeBreaths(context, store),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.filter_drama_rounded,
              title: 'ใจขุ่น · กังวล',
              sub: 'ให้ตะกอนนอนก้น',
              color: p.gold,
              onTap: () => openCloudyMind(context, store),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.bedtime_rounded,
              title: 'ก่อนนอน',
              sub: 'วางความคิด · หลับง่าย',
              color: const Color(0xFF8B93D9),
              glow: DateTime.now().hour >= 20 || DateTime.now().hour < 4,
              onTap: () => openSleep(context, store),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.sports_esports_outlined,
              title: 'ใจอยากหนี',
              sub: 'อยากเล่นเกม · ใจลอย',
              color: p.lotus,
              onTap: () async {
                final r = await openUrge(context, store);
                if (r == 'study') onPractice('study');
              },
            ),
          ),
        ]),
        const SizedBox(height: 22),

        // Today's intention
        if (intent == null)
          _IntentCard(
            title: 'วันนี้ตั้งใจอะไรดี',
            body: 'เลือก 1 อย่างที่จะทำให้ได้วันนี้',
            action: 'ตั้งใจ',
            onTap: () => openRitual(context, store),
          )
        else
          _IntentCard(
            title: 'วันนี้ ${vows[intent].vow}',
            body: pillars[intent] == 2 ? 'ทำได้แล้ววันนี้' : (store.prefs.getString('goal-$intent') ?? vows[intent].goal),
            action: pillars[intent] == 2 ? null : 'เริ่ม',
            done: pillars[intent] == 2,
            onTap: () => _act(context, intent),
          ),
        const SizedBox(height: 14),
        DetoxCard(store: store),
        const SizedBox(height: 14),
        DhammaCardView(store: store),
        const SizedBox(height: 26),

        Text('ห้าสิ่งที่ตั้งใจ', style: display(context, 18)),
        const SizedBox(height: 2),
        Text('แตะเพื่อเริ่ม · แตะดินสอเพื่อแก้เป้าหมาย', style: TextStyle(color: p.muted, fontSize: 12.5)),
        const SizedBox(height: 8),
        for (var i = 0; i < vows.length; i++) _vowRow(context, i, pillars[i], i == intent),
      ],
    );
  }

  void _act(BuildContext context, int i) {
    switch (i) {
      case 0:
        onPractice('sit');
      case 1:
        onPractice('study');
      case 2:
        openExerciseSheet(context, store);
      case 3:
        openSilaSheet(context, store);
      default:
        openHeartSheet(context, store);
    }
  }

  Widget _vowRow(BuildContext context, int i, int state, bool chosen) {
    final p = Pal.of(context);
    final v = vows[i];
    final goal = store.prefs.getString('goal-$i') ?? v.goal;
    return InkWell(
      onTap: () => _act(context, i),
      onLongPress: () => openGoalSheet(context, store, i),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          SizedBox(
            width: 34,
            child: Text(thaiNum(i + 1), style: TextStyle(fontFamily: serif, fontSize: 20, color: state == 2 ? p.lotus : p.line, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(v.vow, style: display(context, 19).copyWith(color: state == 2 ? p.ink : p.ink.withValues(alpha: .85))),
                if (chosen) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: p.lotus.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
                    child: Text('วันนี้', style: TextStyle(fontSize: 11.5, color: p.lotus, fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              Text(goal, style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
          IconButton(
            tooltip: 'แก้เป้าหมาย',
            visualDensity: VisualDensity.compact,
            onPressed: () => openGoalSheet(context, store, i),
            icon: Icon(Icons.edit_outlined, size: 18, color: p.muted),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state == 2 ? p.lotus : Colors.transparent,
              border: Border.all(color: state == 0 ? p.line : p.lotus, width: 1.5),
            ),
            child: state == 2 ? Icon(Icons.check_rounded, size: 14, color: p.onAccent) : null,
          ),
        ]),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  final String title, body;
  final String? action;
  final bool done;
  final VoidCallback onTap;
  const _IntentCard({required this.title, required this.body, this.action, this.done = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: done ? p.lotus.withValues(alpha: .1) : p.surface,
          border: Border.all(color: done ? p.lotus : p.line),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: display(context, 21)),
              const SizedBox(height: 2),
              Text(body, style: TextStyle(color: done ? p.lotus : p.muted, fontSize: 13.5)),
            ]),
          ),
          if (action != null)
            FilledButton(onPressed: onTap, child: Text(action!))
          else
            Icon(Icons.spa_rounded, color: p.lotus, size: 28),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final Color color;
  final bool glow;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.title, required this.sub, required this.color, required this.onTap, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: .16), color.withValues(alpha: .05)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: glow ? .8 : .3), width: glow ? 1.6 : 1),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: .18), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(title, maxLines: 1, style: display(context, 16))),
              Text(sub, style: TextStyle(color: p.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}
