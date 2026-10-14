import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'store.dart';
import 'theme.dart';

// เริ่มแค่ 2 นาที — for anything the reader wants to do but cannot begin.
// Starting is the hard part, so the promise is tiny: two minutes, then free
// to stop. When the time is up, offer to carry on (10, 25 minutes, or open
// ended) and keep offering after each stretch, never pushing.

const _bg = Color(0xFF0B1418);
const _ink = Color(0xFFF2EDE4);
const _dim = Color(0xFF93A59D);
const _gold = Color(0xFFE2B866);
const _pond = Color(0xFF82BAB0);

const _ideas = ['ทำการบ้าน', 'อ่านหนังสือ', 'ออกกำลังกาย', 'จัดห้อง', 'ทวนบทเรียน'];

Future<void> openStart(BuildContext context, Store store) => Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => StartPage(store: store),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));

class StartPage extends StatefulWidget {
  final Store store;
  const StartPage({super.key, required this.store});
  @override
  State<StartPage> createState() => _StartPageState();
}

enum _Phase { pick, run, ask, done }

class _StartPageState extends State<StartPage> {
  _Phase phase = _Phase.pick;
  final task = TextEditingController();
  late List<String> recent;

  DateTime? startedAt;
  DateTime? _endAt; // null while running open-ended
  Timer? _tick;
  int rounds = 0; // stretches finished, including the first two minutes
  final _bell = AudioPlayer();

  @override
  void initState() {
    super.initState();
    recent = widget.store.prefs.getStringList('start-recent') ?? const [];
  }

  @override
  void dispose() {
    _tick?.cancel();
    WakelockPlus.disable();
    _bell.dispose();
    task.dispose();
    super.dispose();
  }

  String get _task => task.text.trim();

  int get _workedMin => startedAt == null ? 0 : DateTime.now().difference(startedAt!).inMinutes;

  void _begin() {
    if (_task.isEmpty) return;
    FocusScope.of(context).unfocus();
    final r = [_task, ...recent.where((t) => t != _task)].take(5).toList();
    widget.store.prefs.setStringList('start-recent', r);
    startedAt = DateTime.now();
    WakelockPlus.enable();
    HapticFeedback.mediumImpact();
    _run(2);
  }

  /// Run for [minutes], or open-ended when null.
  void _run(int? minutes) {
    _tick?.cancel();
    setState(() {
      phase = _Phase.run;
      _endAt = minutes == null ? null : DateTime.now().add(Duration(minutes: minutes));
    });
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (_endAt != null && !DateTime.now().isBefore(_endAt!)) {
        _tick?.cancel();
        rounds++;
        HapticFeedback.heavyImpact();
        _bell.play(AssetSource('sounds/bell.wav')).catchError((_) {});
        setState(() => phase = _Phase.ask);
        return;
      }
      setState(() {});
    });
  }

  void _finish() {
    _tick?.cancel();
    WakelockPlus.disable();
    final min = _workedMin;
    if (min >= 1) {
      widget.store.mutate(todayKey(), (d) {
        d['starts'] = [
          ...((d['starts'] as List?) ?? const []),
          {'id': newId(), 't': startedAt!.toIso8601String(), 'task': _task, 'min': min},
        ];
      });
    }
    setState(() => phase = _Phase.done);
  }

  String _fmt(Duration d) {
    final s = d.inSeconds.clamp(0, 359999);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final running = phase == _Phase.run || phase == _Phase.ask;
    return PopScope(
      // Leaving mid-way still keeps the minutes already done.
      canPop: !running,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _finish();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.bolt_rounded, color: _gold, size: 22),
                const SizedBox(width: 6),
                const Text('เริ่มแค่ 2 นาที', style: TextStyle(fontFamily: cute, fontSize: 18, color: _ink, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (!running) IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: _dim)),
              ]),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: switch (phase) {
                    _Phase.pick => _pick(),
                    _Phase.run => _running(),
                    _Phase.ask => _ask(),
                    _Phase.done => _done(),
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pick() => SingleChildScrollView(
        key: const ValueKey('pick'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 10),
          const Text('อยากทำอะไร\nแต่ยังไม่ได้เริ่ม', style: TextStyle(fontFamily: cute, fontSize: 30, height: 1.35, color: _ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('ไม่ต้องทำให้เสร็จ แค่ 2 นาทีพอ\nครบแล้วจะหยุดก็ได้ จะทำต่อก็ได้',
              style: TextStyle(color: _dim, height: 1.6)),
          const SizedBox(height: 20),
          TextField(
            controller: task,
            autofocus: true,
            maxLength: 80,
            style: const TextStyle(color: _ink, fontSize: 17),
            textInputAction: TextInputAction.go,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _begin(),
            decoration: InputDecoration(
              hintText: 'เช่น ทำการบ้านเลขข้อ 1',
              hintStyle: const TextStyle(color: Color(0xFF5E716B)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: .05),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 6),
          const Text('ยิ่งเล็กยิ่งดี "ทำข้อ 1" เริ่มง่ายกว่า "ทำการบ้านให้เสร็จ"', style: TextStyle(color: _dim, fontSize: 12.5)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in {...recent, ..._ideas})
              ActionChip(
                label: Text(t, style: const TextStyle(color: _ink)),
                backgroundColor: Colors.white.withValues(alpha: .05),
                side: BorderSide(color: _dim.withValues(alpha: .35)),
                onPressed: () => setState(() => task.text = t),
              ),
          ]),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _task.isEmpty ? null : _begin,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _bg,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: const Text('เริ่ม 2 นาที'),
          ),
        ]),
      );

  Widget _running() {
    final open = _endAt == null;
    final shown = open ? DateTime.now().difference(startedAt!) : _endAt!.difference(DateTime.now()) + const Duration(milliseconds: 999);
    return Column(key: const ValueKey('run'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      Text(_task, textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 26, height: 1.4, color: _ink, fontWeight: FontWeight.w600)),
      const SizedBox(height: 18),
      Text(_fmt(shown),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: sans, fontSize: 64, color: _ink, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()])),
      Text(open ? 'ทำต่อไปเรื่อย ๆ · ไม่จับเวลา' : rounds == 0 ? 'แค่ 2 นาที ทำไปก่อน ไม่ต้องคิดเยอะ' : 'ทำต่ออีกนิด',
          textAlign: TextAlign.center, style: const TextStyle(color: _dim)),
      const Spacer(),
      const Text('วางมือถือไว้ได้เลย ครบเวลาจะมีเสียงระฆัง', textAlign: TextAlign.center, style: TextStyle(color: _dim, fontSize: 13)),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _finish,
        style: OutlinedButton.styleFrom(foregroundColor: _ink, side: BorderSide(color: _dim.withValues(alpha: .5)), padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text(open ? 'เสร็จแล้ว' : 'พอแค่นี้'),
      ),
    ]);
  }

  Widget _ask() {
    final first = rounds == 1;
    ButtonStyle s(Color bg) => FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: _bg,
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle: const TextStyle(fontFamily: sans, fontSize: 15.5, fontWeight: FontWeight.w600),
        );
    return Column(key: ValueKey('ask$rounds'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      const Icon(Icons.notifications_active_rounded, color: _gold, size: 44),
      const SizedBox(height: 12),
      Text(first ? 'ครบ 2 นาทีแล้ว' : 'ทำไปแล้ว $_workedMin นาที',
          textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 30, color: _ink, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(first ? 'เริ่มได้แล้ว ส่วนที่ยากที่สุดผ่านไปแล้ว\nยังไหวไหม อยากทำต่อหรือเปล่า' : 'เก่งมาก ยังอยากทำต่อไหม',
          textAlign: TextAlign.center, style: const TextStyle(color: _dim, height: 1.6)),
      const Spacer(),
      FilledButton(onPressed: () => _run(10), style: s(_gold), child: const Text('ทำต่ออีก 10 นาที')),
      const SizedBox(height: 10),
      FilledButton(onPressed: () => _run(25), style: s(_pond), child: const Text('ทำต่ออีก 25 นาที')),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => _run(null),
        style: OutlinedButton.styleFrom(foregroundColor: _ink, side: BorderSide(color: _dim.withValues(alpha: .5)), padding: const EdgeInsets.symmetric(vertical: 14)),
        child: const Text('ทำต่อไปเลย ไม่ต้องจับเวลา'),
      ),
      const SizedBox(height: 6),
      TextButton(onPressed: _finish, child: const Text('พอแค่นี้ก่อน', style: TextStyle(color: _dim))),
    ]);
  }

  Widget _done() {
    final min = _workedMin;
    return Column(key: const ValueKey('done'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      const Icon(Icons.spa_rounded, color: _gold, size: 56),
      const SizedBox(height: 14),
      Text(min >= 1 ? 'ทำ "$_task" ไป $min นาที' : 'เริ่มแล้ว',
          textAlign: TextAlign.center, style: const TextStyle(fontFamily: cute, fontSize: 26, height: 1.4, color: _ink, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('การเริ่มคือส่วนที่ยากที่สุด\nวันนี้ทำได้แล้ว', textAlign: TextAlign.center, style: TextStyle(color: _dim, height: 1.6)),
      const Spacer(),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _bg, padding: const EdgeInsets.symmetric(vertical: 16)),
        child: const Text('เสร็จ'),
      ),
    ]);
  }
}
