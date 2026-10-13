import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'content.dart';
import 'games.dart';
import 'iq.dart';
import 'mascot.dart';
import 'progress.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// ลาน — the practice yard: seeds, rank, weekly quests, games, pond shop, card album.
class LanPage extends StatelessWidget {
  final Store store;
  const LanPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final (rank, rankNote, toNext) = rankOf(store);
    final seeds = seedBalance(store);
    final today = items(store.day(todayKey()), 'games');
    final playedToday = today.map((g) => g['game']).toSet();
    final week = weekStart(DateTime.now());
    final album = collectedCards(store);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ลาน', style: display(context, 28)),
              Text('ลานฝึกใจ เล่นสั้น ๆ ได้ผลจริง', style: TextStyle(color: p.muted)),
            ]),
          ),
          _SeedChip(seeds),
        ]),
        const SizedBox(height: 16),

        // rank
        Panel(
          child: Row(children: [
            BuaNoi(mood: activeDays(store) >= 10 ? BuaMood.happy : BuaMood.calm, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ขั้นของคุณ', style: TextStyle(color: p.muted, fontSize: 12.5)),
                Text(rank, style: display(context, 22).copyWith(color: p.lotus)),
                Text(rankNote, style: TextStyle(color: p.ink, fontSize: 13.5)),
                if (toNext != null) Text('อีก $toNext วันที่ฝึก จะขึ้นขั้นถัดไป', style: TextStyle(color: p.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // weekly quests
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('ภารกิจสัปดาห์นี้', style: display(context, 17)),
              const Spacer(),
              Text('สำเร็จละ $questReward เมล็ด', style: TextStyle(color: p.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            for (final q in quests) _questRow(context, q, questProgress(store, q, week)),
          ]),
        ),
        const SizedBox(height: 20),

        // games
        Row(children: [
          Text('ฝึกวันนี้', style: display(context, 18)),
          const Spacer(),
          Text('เกมละ 2 เมล็ด/วัน', style: TextStyle(color: p.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Text('ฝึกใจ', style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 6),
        for (final g in gameList.take(mindGames)) _gameTile(context, g, playedToday.contains(g.id), _bestToday(today, g.id)),
        const SizedBox(height: 8),
        Text('ฝึกคิด · ช่วยเรื่องเรียน', style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 6),
        for (final g in gameList.skip(mindGames)) _gameTile(context, g, playedToday.contains(g.id), _bestToday(today, g.id)),
        const SizedBox(height: 20),

        // shop + album
        Row(children: [
          Expanded(child: _bigButton(context, Icons.water_rounded, 'แต่งสระ', '${ownedDecor(store).length}/${decorItems.length} ชิ้น', p.pond, () => _openShop(context))),
          const SizedBox(width: 10),
          Expanded(child: _bigButton(context, Icons.style_rounded, 'อัลบั้มไพ่ธรรม', '${album.length}/${cards.length} ใบ', p.lotus, () => _openAlbum(context))),
        ]),
        const SizedBox(height: 18),
        Text('เมล็ดบัวได้จากการฝึกจริง: ทำตามเป้าแต่ละข้อ 5 · ครบทั้ง 5 ข้อ +10 · ใจสะอาด 3 · ภารกิจไพ่ธรรม 3 · ชนะใจตน 5 · เล่นลาน 2',
            style: TextStyle(color: p.muted, fontSize: 12, height: 1.6)),
      ],
    );
  }

  int? _bestToday(List<Map<String, dynamic>> today, String id) {
    final xs = today.where((g) => g['game'] == id).map((g) => (g['score'] as num).toInt());
    return xs.isEmpty ? null : xs.reduce((a, b) => a > b ? a : b);
  }

  Widget _questRow(BuildContext context, Quest q, int n) {
    final p = Pal.of(context);
    final done = n >= q.target;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: done ? p.lotus : p.line),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.title, style: TextStyle(color: p.ink, fontSize: 14.5, decoration: done ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LinearProgressIndicator(
                value: (n / q.target).clamp(0, 1),
                minHeight: 6,
                color: done ? p.lotus : p.pond,
                backgroundColor: p.line.withValues(alpha: .6),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Text('${n.clamp(0, q.target)}/${q.target}', style: number(context, 13).copyWith(color: p.muted)),
      ]),
    );
  }

  Widget _gameTile(BuildContext context, GameInfo g, bool played, int? best) {
    final p = Pal.of(context);
    final unit = switch (g.id) { 'breath' || 'gonogo' || 'eq' || 'puzzle' => '%', 'memory' => ' ดอก', 'math' => ' ข้อ', 'recall' => ' ใบ', _ => ' จุด' };
    final due = g.id == 'recall' ? dueCards(store).length : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => openGame(context, store, g.id),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(colors: [g.color.withValues(alpha: .14), g.color.withValues(alpha: .04)]),
            border: Border.all(color: g.color.withValues(alpha: .3)),
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: g.color.withValues(alpha: .2), borderRadius: BorderRadius.circular(16)),
              child: Icon(g.icon, color: g.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name, style: display(context, 17)),
                Text(due > 0 ? '${g.trains} · ถึงเวลาทวน $due ใบ' : g.trains, style: TextStyle(color: due > 0 ? g.color : p.muted, fontSize: 12.5)),
              ]),
            ),
            if (played)
              Column(children: [
                Icon(Icons.check_circle_rounded, color: g.color, size: 20),
                if (best != null) Text('$best$unit', style: TextStyle(color: p.muted, fontSize: 11.5)),
              ])
            else
              Icon(Icons.play_arrow_rounded, color: g.color),
          ]),
        ),
      ),
    );
  }

  Widget _bigButton(BuildContext context, IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    final p = Pal.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: color.withValues(alpha: .1),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: display(context, 16)),
          Text(sub, style: TextStyle(color: p.muted, fontSize: 12.5)),
        ]),
      ),
    );
  }

  void _openShop(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ListenableBuilder(listenable: store, builder: (context, _) => _Shop(store: store)),
      );

  void _openAlbum(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Album(store: store)));
}

class _SeedChip extends StatelessWidget {
  final int seeds;
  const _SeedChip(this.seeds);
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: p.gold.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(size: const Size(18, 18), painter: _SeedPainter()),
        const SizedBox(width: 6),
        Text('$seeds', style: number(context, 18).copyWith(color: p.gold)),
        const SizedBox(width: 4),
        Text('เมล็ดบัว', style: TextStyle(color: p.gold, fontSize: 12)),
      ]),
    );
  }
}

class _SeedPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final o = Offset(s.width / 2, s.height / 2);
    c.drawOval(Rect.fromCenter(center: o, width: s.width * .7, height: s.height * .9), Paint()..color = const Color(0xFF8F6D2C));
    c.drawOval(Rect.fromCenter(center: o.translate(-1.5, -2), width: s.width * .22, height: s.height * .3), Paint()..color = Colors.white.withValues(alpha: .4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _Shop extends StatelessWidget {
  final Store store;
  const _Shop({required this.store});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final owned = ownedDecor(store);
    final balance = seedBalance(store);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('แต่งสระ', style: display(context, 22)),
          const Spacer(),
          _SeedChip(balance),
        ]),
        Text('ของที่ได้ จะไปอยู่ในสระหน้าวันนี้', style: TextStyle(color: p.muted)),
        const SizedBox(height: 14),
        for (final d in decorItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.name, style: display(context, 16)),
                    Text(d.desc, style: TextStyle(color: p.muted, fontSize: 13)),
                  ]),
                ),
                if (owned.contains(d.id))
                  Row(children: [Icon(Icons.check_circle_rounded, color: p.pond, size: 20), const SizedBox(width: 4), Text('อยู่ในสระแล้ว', style: TextStyle(color: p.pond, fontSize: 13))])
                else
                  FilledButton(
                    onPressed: balance >= d.price
                        ? () async {
                            HapticFeedback.mediumImpact();
                            await store.prefs.setStringList('decor', [...owned, d.id]);
                            store.touch();
                            if (context.mounted) toast(context, '${d.name} มาอยู่ในสระแล้ว');
                          }
                        : null,
                    child: Text('${d.price} เมล็ด'),
                  ),
              ]),
            ),
          ),
        if (balance < decorItems.where((d) => !owned.contains(d.id)).fold<int>(1 << 30, (a, d) => d.price < a ? d.price : a))
          Text('ยังสะสมเมล็ดไม่พอ ฝึกต่ออีกนิดนะ', style: TextStyle(color: p.muted, fontSize: 13)),
      ]),
    );
  }
}

class _Album extends StatelessWidget {
  final Store store;
  const _Album({required this.store});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final got = collectedCards(store);
    return Scaffold(
      appBar: AppBar(title: Text('อัลบั้มไพ่ธรรม · ${got.length}/${cards.length}', style: display(context, 18)), backgroundColor: p.bg),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .7),
        itemCount: cards.length,
        itemBuilder: (context, i) {
          final has = got.containsKey(i);
          final done = got[i] == true;
          final c = cards[i];
          return GestureDetector(
            onTap: has
                ? () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(c.teaching, style: display(context, 20)),
                        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('หมวด ${cardTags[c.tag]}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                          const SizedBox(height: 8),
                          Text(c.mission, style: const TextStyle(height: 1.6)),
                          const SizedBox(height: 10),
                          Text(done ? 'ทำภารกิจนี้สำเร็จแล้ว' : 'เปิดได้แล้ว แต่ภารกิจยังไม่สำเร็จ', style: TextStyle(color: done ? p.lotus : p.muted, fontSize: 13)),
                        ]),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด'))],
                      ),
                    )
                : null,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: has ? null : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF14212A), Color(0xFF2B4A46)]),
                color: has ? p.surface : null,
                border: Border.all(color: done ? p.gold : has ? p.lotus.withValues(alpha: .5) : Colors.transparent, width: done ? 2 : 1),
              ),
              child: has
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cardTags[c.tag] ?? '', style: TextStyle(color: p.muted, fontSize: 10.5)),
                      const SizedBox(height: 4),
                      Expanded(child: Text(c.teaching, style: display(context, 13.5), overflow: TextOverflow.fade)),
                      if (done) Icon(Icons.spa_rounded, size: 16, color: p.gold),
                    ])
                  : Center(child: Text('?', style: TextStyle(fontFamily: cute, fontSize: 30, color: Colors.white.withValues(alpha: .3)))),
            ),
          );
        },
      ),
    );
  }
}
