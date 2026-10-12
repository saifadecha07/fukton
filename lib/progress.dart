import 'store.dart';
import 'content.dart';

/// Lotus seeds, weekly quests and ranks.
/// Seeds earned are derived from what the reader actually did, so they can
/// never drift out of step with the log; only what was spent is stored.

// ---------- pond decorations ----------
class Decor {
  final String id, name, desc;
  final int price;
  const Decor(this.id, this.name, this.price, this.desc);
}

const decorItems = <Decor>[
  Decor('fish', 'ปลาคราฟคู่', 30, 'ว่ายวนใต้ใบบัว'),
  Decor('firefly', 'หิ่งห้อย', 40, 'แสงเล็ก ๆ ยามค่ำ'),
  Decor('dragonfly', 'แมลงปอ', 50, 'บินโฉบเหนือน้ำ'),
  Decor('frog', 'กบน้อย', 60, 'นั่งสมาธิบนใบบัว'),
  Decor('lantern', 'กระทงลอยน้ำ', 80, 'แสงอุ่นลอยผ่านช้า ๆ'),
  Decor('sala', 'ศาลาริมน้ำ', 150, 'ที่พักใจริมฝั่ง'),
];

List<String> ownedDecor(Store s) => s.prefs.getStringList('decor') ?? const [];

// ---------- daily seeds ----------
List<Map<String, dynamic>> gamesOf(Day d) => items(d, 'games');

int seedsForDay(Day d) {
  final p = pillarsOf(d);
  final done = p.where((x) => x == 2).length;
  var s = done * 5 + (done == 5 ? 10 : 0);
  if ((d['card'] as Map?)?['done'] == true) s += 3;
  if (d['detox'] == 'kept') s += 3;
  s += 5 * items(d, 'urges').where((u) => u['outcome'] == 'returned').length.clamp(0, 3);
  s += 2 * gamesOf(d).map((g) => g['game']).toSet().length;
  return s;
}

// ---------- weekly quests ----------
class Quest {
  final String id, title;
  final int target;
  final bool Function(Day d) counts;
  const Quest(this.id, this.title, this.target, this.counts);
}

const questReward = 20;

final quests = <Quest>[
  Quest('mind', 'ฝึกสติ 5 วัน', 5, (d) => pillarsOf(d)[0] == 2),
  Quest('clean', 'ใจสะอาด 5 วัน', 5, (d) => d['detox'] == 'kept'),
  Quest('study', 'เรียนอย่างมีสติ 3 วัน', 3, (d) => pillarsOf(d)[1] == 2),
  Quest('body', 'ออกกำลังกาย 3 วัน', 3, (d) => pillarsOf(d)[2] == 2),
  Quest('lan', 'เข้าลานฝึกใจ 5 วัน', 5, (d) => gamesOf(d).isNotEmpty),
];

DateTime weekStart(DateTime t) {
  final d = DateTime(t.year, t.month, t.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

int questProgress(Store s, Quest q, DateTime start) {
  var n = 0;
  for (var i = 0; i < 7; i++) {
    final d = s.days[keyOf(start.add(Duration(days: i)))];
    if (d != null && q.counts(d)) n++;
  }
  return n;
}

int _questSeeds(Store s) {
  if (s.days.isEmpty) return 0;
  final first = (s.days.keys.toList()..sort()).first;
  var w = weekStart(dateOf(first));
  final last = weekStart(DateTime.now());
  var total = 0;
  while (!w.isAfter(last)) {
    for (final q in quests) {
      if (questProgress(s, q, w) >= q.target) total += questReward;
    }
    w = w.add(const Duration(days: 7));
  }
  return total;
}

int seedsEarned(Store s) => s.days.values.fold(0, (a, d) => a + seedsForDay(d)) + _questSeeds(s);

int seedsSpent(Store s) {
  final owned = ownedDecor(s);
  return decorItems.where((x) => owned.contains(x.id)).fold(0, (a, x) => a + x.price);
}

int seedBalance(Store s) => seedsEarned(s) - seedsSpent(s);

// ---------- ranks ----------
const ranks = <(int, String, String)>[
  (0, 'ผู้เริ่มเดิน', 'ก้าวแรกสำคัญที่สุด'),
  (3, 'ผู้รู้ตัว', 'เริ่มเห็นใจตัวเอง'),
  (10, 'ราชสีห์หนุ่ม', 'ไม่ตื่นเสียงง่าย ๆ แล้ว'),
  (30, 'สายลมพลิ้ว', 'ปล่อยวางได้คล่องขึ้น'),
  (60, 'บัวพ้นน้ำ', 'อยู่กลางสายชลได้ไม่เปื้อน'),
  (100, 'นอแรด', 'ยืนได้ด้วยใจของตน'),
];

int activeDays(Store s) => s.days.values.where(isActive).length;

(String, String, int?) rankOf(Store s) {
  final n = activeDays(s);
  var i = 0;
  for (var k = 0; k < ranks.length; k++) {
    if (n >= ranks[k].$1) i = k;
  }
  final next = i + 1 < ranks.length ? ranks[i + 1].$1 - n : null;
  return (ranks[i].$2, ranks[i].$3, next);
}

// ---------- card album ----------
/// index of card -> mission done?
Map<int, bool> collectedCards(Store s) {
  final out = <int, bool>{};
  s.days.forEach((k, d) {
    final c = d['card'] as Map?;
    if (c?['open'] != true) return;
    final i = cards.indexOf(cardOfDay(dateOf(k).millisecondsSinceEpoch ~/ 864e5));
    out[i] = (out[i] ?? false) || c?['done'] == true;
  });
  return out;
}
