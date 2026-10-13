import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'calm.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// ใจสะอาด — a streak for days without horror or negative media, plus a quick
/// tally of the times the reader caught themself overthinking today.
class DetoxCard extends StatelessWidget {
  final Store store;
  const DetoxCard({super.key, required this.store});

  static const _violet = Color(0xFF8B93D9);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final k = todayKey();
    final d = store.day(k);
    final status = d['detox'] as String?;
    final streak = detoxStreak(store.days);
    final best = detoxBest(store.days);
    final caught = (d['overthink'] as num?)?.toInt() ?? 0;

    void mark(String? v) {
      HapticFeedback.mediumImpact();
      store.mutate(k, (x) => x['detox'] = v);
      if (v == 'kept') toast(context, 'ใจสะอาดอีกหนึ่งวัน');
      if (v == 'slipped') toast(context, 'ไม่เป็นไร รู้ตัวแล้ว พรุ่งนี้เริ่มใหม่');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          _violet.withValues(alpha: .14),
          p.surface,
        ]),
        border: Border.all(color: _violet.withValues(alpha: .35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ใจสะอาด', style: display(context, 18)),
              Text('งดคลิปหลอน · ข่าวร้าย · สื่อที่ทำให้ใจหม่น', style: TextStyle(color: p.muted, fontSize: 12.5)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$streak', style: number(context, 34).copyWith(color: _violet, height: 1)),
            Text('วันติดกัน', style: TextStyle(color: p.muted, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 12),
        if (status == null) ...[
          Text('วันนี้ เลี่ยงสื่อด้านลบได้ไหม', style: TextStyle(color: p.ink, fontSize: 14)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () => mark('kept'),
                style: FilledButton.styleFrom(backgroundColor: _violet, foregroundColor: Colors.white),
                child: const Text('ได้ วันนี้ใจสะอาด'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => mark('slipped'), child: const Text('พลาดไป')),
          ]),
        ] else
          Row(children: [
            Icon(status == 'kept' ? Icons.check_circle_rounded : Icons.refresh_rounded, color: status == 'kept' ? _violet : p.muted, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status == 'kept' ? 'วันนี้ใจสะอาดแล้ว${best > streak ? ' · ดีที่สุด $best วัน' : ''}' : 'วันนี้พลาดไป ไม่เป็นไร เริ่มใหม่พรุ่งนี้',
                style: TextStyle(color: p.ink, fontSize: 14),
              ),
            ),
            TextButton(onPressed: () => mark(null), child: const Text('แก้')),
          ]),
        const SizedBox(height: 10),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text(caught == 0 ? 'กำลังคิดมากอยู่ไหม' : 'วันนี้รู้ทันความคิดมาก $caught ครั้ง',
                style: TextStyle(color: p.muted, fontSize: 13)),
          ),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              store.mutate(k, (x) => x['overthink'] = ((x['overthink'] as num?)?.toInt() ?? 0) + 1);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: const Text('รู้ทันแล้ว แค่รู้ก็เบาลงครึ่งหนึ่ง'),
                  action: SnackBarAction(label: 'ทำใจให้นิ่ง', onPressed: () => openCloudyMind(context, store)),
                ));
            },
            icon: const Icon(Icons.psychology_alt_outlined, size: 18),
            label: const Text('คิดมากอีกแล้ว'),
          ),
        ]),
      ]),
    );
  }
}
