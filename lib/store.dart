import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';

/// Days in a row the reader kept away from horror and negative media.
/// Today counts once checked in; an unchecked today does not break the run.
int detoxStreak(Map<String, Day> days) {
  var d = DateTime.now();
  if (days[keyOf(d)]?['detox'] == null) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (days[keyOf(d)]?['detox'] == 'kept') {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

int detoxBest(Map<String, Day> days) {
  final ks = days.keys.toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final k in ks) {
    if (days[k]?['detox'] != 'kept') {
      run = 0;
      prev = null;
      continue;
    }
    final t = dateOf(k);
    run = (prev != null && t.difference(prev).inHours.round() <= 25) ? run + 1 : 1;
    if (run > best) best = run;
    prev = t;
  }
  return best;
}

int urgesWon(Iterable<Day> days) =>
    days.fold(0, (a, d) => a + items(d, 'urges').where((u) => u['outcome'] == 'returned').length);

typedef Day = Map<String, dynamic>;

String keyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String todayKey() => keyOf(DateTime.now());
DateTime dateOf(String k) => DateTime.parse('${k}T00:00:00');

String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) + Random().nextInt(1 << 20).toRadixString(36);

List<Map<String, dynamic>> items(Day d, String key) =>
    ((d[key] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

int minutesOf(Day d, [List<String>? kinds]) => items(d, 'sessions')
    .where((s) => kinds == null || kinds.contains(s['kind'] ?? 'sit'))
    .fold(0, (a, s) => a + ((s['min'] as num?)?.toInt() ?? 0));

int exerciseMinutes(Day d) => items(d, 'exercise').fold(0, (a, x) => a + ((x['min'] as num?)?.toInt() ?? 0));

int silaCount(Day d) {
  final m = (d['sila'] as Map?) ?? const {};
  var n = 0;
  for (var i = 0; i < sila.length; i++) {
    if (m['s$i'] == true) n++;
  }
  return n;
}

bool isActive(Day? d) =>
    d != null &&
    (items(d, 'sessions').isNotEmpty ||
        items(d, 'notes').isNotEmpty ||
        d['review'] != null ||
        items(d, 'emotions').isNotEmpty ||
        items(d, 'exercise').isNotEmpty ||
        ((d['card'] as Map?)?['done'] == true) ||
        items(d, 'urges').isNotEmpty ||
        items(d, 'worries').isNotEmpty ||
        items(d, 'sleeps').isNotEmpty ||
        d['detox'] != null ||
        items(d, 'games').isNotEmpty ||
        ((d['overthink'] as num?) ?? 0) > 0 ||
        silaCount(d) > 0);

/// Which of the five daily pillars are done: mind, study, body, sila, heart.
/// Values: 2 = done, 1 = partly, 0 = not yet.
List<int> pillarsOf(Day d) {
  final ss = items(d, 'sessions');
  final sc = silaCount(d);
  return [
    ss.any((s) => (s['kind'] ?? 'sit') != 'study') ? 2 : 0,
    ss.any((s) => s['kind'] == 'study') ? 2 : 0,
    exerciseMinutes(d) > 0 ? 2 : 0,
    sc == sila.length ? 2 : (sc > 0 ? 1 : 0),
    (d['review'] != null || items(d, 'emotions').isNotEmpty || items(d, 'notes').isNotEmpty || ((d['card'] as Map?)?['done'] == true) || items(d, 'urges').any((u) => u['outcome'] == 'returned') || items(d, 'worries').isNotEmpty || items(d, 'sleeps').isNotEmpty || d['detox'] == 'kept') ? 2 : 0,
  ];
}

class Store extends ChangeNotifier {
  static const _daysKey = 'fukton-days-v1';
  final Map<String, Day> days = {};
  late SharedPreferences prefs;

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_daysKey);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        m.forEach((k, v) => days[k] = Map<String, dynamic>.from(v as Map));
      } catch (_) {}
    }
  }

  static Day blank(String k) => {
        'date': k,
        'sessions': <dynamic>[],
        'notes': <dynamic>[],
        'review': null,
        'emotions': <dynamic>[],
        'exercise': <dynamic>[],
        'urges': <dynamic>[],
        'worries': <dynamic>[],
        'sleeps': <dynamic>[],
        'games': <dynamic>[],
        'sila': <String, dynamic>{},
      };

  Day day(String k) => days[k] ?? blank(k);

  void mutate(String k, void Function(Day d) fn) {
    final d = days.putIfAbsent(k, () => blank(k));
    for (final key in ['sessions', 'notes', 'emotions', 'exercise', 'urges', 'worries', 'sleeps', 'games']) {
      d[key] = List<dynamic>.from((d[key] as List?) ?? const []);
    }
    d['sila'] = Map<String, dynamic>.from((d['sila'] as Map?) ?? const {});
    fn(d);
    prefs.setString(_daysKey, jsonEncode(days));
    notifyListeners();
    syncWidget();
  }

  /// Push today's state to the home-screen widget. Safe to call anywhere.
  Future<void> syncWidget() async {
    if (kIsWeb) return;
    try {
      final k = todayKey();
      final d = day(k);
      final n = dateOf(k).millisecondsSinceEpoch ~/ 864e5;
      final intent = d['intent'] as int?;
      final bloom = pillarsOf(d).where((x) => x == 2).length;
      final s = streak();
      await HomeWidget.saveWidgetData<String>('line', creed[n % creed.length].replaceAll('\n', ' '));
      await HomeWidget.saveWidgetData<String>('vow', intent == null ? 'แตะเพื่อตั้งใจวันนี้' : 'วันนี้ ${vows[intent].vow}');
      await HomeWidget.saveWidgetData<String>('bloom', '${bloomLines[bloom]}${s > 0 ? ' · วันที่ ${thaiNum(s)}' : ''}');
      await HomeWidget.updateWidget(androidName: 'LotusWidget');
    } catch (_) {}
  }

  void touch() => notifyListeners();

  int streak() {
    var d = DateTime.now();
    if (!isActive(days[keyOf(d)])) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (isActive(days[keyOf(d)])) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  int longestStreak() {
    final ks = days.keys.where((k) => isActive(days[k])).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final k in ks) {
      final t = dateOf(k);
      run = (prev != null && t.difference(prev).inHours.round() >= 23 && t.difference(prev).inHours <= 25) ? run + 1 : 1;
      best = max(best, run);
      prev = t;
    }
    return best;
  }
}
