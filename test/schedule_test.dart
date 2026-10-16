import 'package:flutter_test/flutter_test.dart';
import 'package:fukton/prep.dart';
import 'package:fukton/schedule.dart';
import 'package:fukton/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Subject _s(String code, DateTime at, int rank) => Subject(code, code, at, rank, [Topic('a'), Topic('b')]);

final subs = [
  _s('CN330', DateTime(2026, 11, 25, 9), 3),
  _s('CN320', DateTime(2026, 11, 26, 9), 7),
  _s('CN321', DateTime(2026, 11, 30, 9), 6),
  _s('CN310', DateTime(2026, 12, 2, 9), 2),
  _s('CN331', DateTime(2026, 12, 2, 13), 4),
  _s('CN360', DateTime(2026, 12, 3, 13), 5),
  _s('CN361', DateTime(2026, 12, 4, 9), 1),
];

void _covered(List<Block> bs, String why) {
  expect(bs.first.start, 0, reason: why);
  expect(bs.last.end, 24 * 60, reason: why);
  for (var i = 1; i < bs.length; i++) {
    expect(bs[i].start, bs[i - 1].end, reason: '$why ${bs[i - 1].label} -> ${bs[i].label}');
    expect(bs[i].end > bs[i].start, true, reason: '$why ${bs[i].label}');
  }
}

void main() {
  late Store store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = Store();
    await store.load();
  });

  test('every day is covered end to end, in every mode', () {
    for (var d = DateTime(2026, 10, 16); d.isBefore(DateTime(2026, 12, 6)); d = d.add(const Duration(days: 1))) {
      _covered(blocksFor(d, subs), 'plan $d');
      for (final c in [const DayChoice(DayMode.shift, 19 * 60), const DayChoice(DayMode.shift, 23 * 60 + 30), const DayChoice(DayMode.flex), const DayChoice(DayMode.rest)]) {
        setDayChoice(store, d, c);
        _covered(blocksOn(store, d, subs), '${c.mode} ${c.start} $d');
      }
      setDayChoice(store, d, const DayChoice(DayMode.plan));
    }
  });

  test('targets per mode on a Friday', () {
    final fri = DateTime(2026, 10, 16);
    final plan = dayTarget(store, fri, subs);
    setDayChoice(store, fri, const DayChoice(DayMode.shift, 19 * 60));
    final late = dayTarget(store, fri, subs);
    setDayChoice(store, fri, const DayChoice(DayMode.flex));
    final flex = dayTarget(store, fri, subs);
    setDayChoice(store, fri, const DayChoice(DayMode.rest));
    final rest = dayTarget(store, fri, subs);
    // ignore: avoid_print
    print('Fri plan ${plan / 60} h · start 19:00 ${late / 60} h · flex ${flex / 60} h · rest ${rest / 60} h');
    expect(late < plan, true);
    expect(flex, plan);
    expect(rest, 0);
  });

  test('hours left look sane', () {
    final h = studyMinutesBetween(store, DateTime(2026, 10, 16, 18), DateTime(2026, 12, 4, 9), subs) / 60;
    // ignore: avoid_print
    print('hours left to last exam: $h');
    expect(h > 100 && h < 300, true);
  });

  test('exam day has the exam blocks', () {
    expect(blocksFor(DateTime(2026, 12, 2), subs).where((b) => b.kind == Kind.exam).length, 2);
  });
}
