import 'package:flutter/material.dart';

import 'content.dart';
import 'mascot.dart';
import 'theme.dart';
import 'widgets.dart';

class VersesPage extends StatelessWidget {
  const VersesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('คาถา', style: display(context, 28)),
              Text('ถ้อยคำเก่าแก่ ที่ยังใช้ได้ในวันนี้', style: TextStyle(color: p.muted)),
            ]),
          ),
          const BuaNoi(mood: BuaMood.calm, size: 54),
        ]),
        const SizedBox(height: 18),
        for (final v in verses) ...[
          _VerseCard(v),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _VerseCard extends StatelessWidget {
  final Verse v;
  const _VerseCard(this.v);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v.title, style: display(context, 18).copyWith(color: p.lotus)),
        const SizedBox(height: 10),
        Text(v.th, style: TextStyle(fontFamily: serif, fontSize: 19, height: 1.75, fontWeight: FontWeight.w600, color: p.ink)),
        const SizedBox(height: 16),
        Text('หมายความว่า', style: display(context, 14.5).copyWith(color: p.pond)),
        const SizedBox(height: 2),
        Text(v.meaning, style: TextStyle(fontSize: 15, height: 1.7, color: p.ink.withValues(alpha: .9))),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: p.lotus.withValues(alpha: .09), borderRadius: BorderRadius.circular(18)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.spa_rounded, size: 20, color: p.lotus),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ลองทำวันนี้', style: display(context, 14.5).copyWith(color: p.lotus)),
                Text(v.practice, style: TextStyle(height: 1.6, color: p.ink)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Text('ที่มา: ${v.ref}', style: TextStyle(fontSize: 11.5, color: p.muted.withValues(alpha: .8))),
      ]),
    );
  }
}
