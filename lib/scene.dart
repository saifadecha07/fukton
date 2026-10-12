import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum Tod { dawn, day, dusk, night }

Tod todNow() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 8) return Tod.dawn;
  if (h >= 8 && h < 16) return Tod.day;
  if (h >= 16 && h < 19) return Tod.dusk;
  return Tod.night;
}

class _P {
  final List<Color> sky, hills, water, petal;
  final Color sun, leaf;
  const _P(this.sky, this.sun, this.hills, this.water, this.leaf, this.petal);
}

const _scenes = {
  Tod.dawn: _P([Color(0xFFF4C2B0), Color(0xFFF9E6CE)], Color(0xFFFFE1AE), [Color(0xFFC99B9C), Color(0xFFAE8189)],
      [Color(0xFFE3BDB3), Color(0xFFA9818D)], Color(0xFF5E8B6A), [Color(0xFFE77FA3), Color(0xFFFBD7E2)]),
  Tod.day: _P([Color(0xFFA6D1CE), Color(0xFFE7F2EA)], Color(0xFFFFF6D8), [Color(0xFF8BB4A6), Color(0xFF6A998B)],
      [Color(0xFF99C6C0), Color(0xFF5B958C)], Color(0xFF3F7A5C), [Color(0xFFDE6E96), Color(0xFFFAD3E0)]),
  Tod.dusk: _P([Color(0xFFE38B67), Color(0xFFF5D09E)], Color(0xFFFFD293), [Color(0xFF9B686D), Color(0xFF7B535F)],
      [Color(0xFFC5877A), Color(0xFF76505B)], Color(0xFF4C6D51), [Color(0xFFE77FA3), Color(0xFFFBD7E2)]),
  Tod.night: _P([Color(0xFF0D192A), Color(0xFF22394A)], Color(0xFFF2EBD3), [Color(0xFF1A2B39), Color(0xFF13212E)],
      [Color(0xFF1B3041), Color(0xFF0C1722)], Color(0xFF2B4E46), [Color(0xFFC9799A), Color(0xFFEBC3D3)]),
};

/// Animated lotus pond. [bloom] is 0..5; the flower opens toward it.
class PondScene extends StatefulWidget {
  final int bloom;
  final Tod? tod;
  final List<String> decor;
  const PondScene({super.key, required this.bloom, this.tod, this.decor = const []});
  @override
  State<PondScene> createState() => _PondSceneState();
}

class _PondSceneState extends State<PondScene> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0, _bloom = 0;
  final _ripples = <double>[];
  double _lastRipple = -10;

  @override
  void initState() {
    super.initState();
    _bloom = widget.bloom.toDouble();
    _ticker = createTicker((e) {
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      final t = e.inMicroseconds / 1e6;
      final dt = t - _t;
      _t = t;
      _bloom += (widget.bloom - _bloom) * (reduce ? 1 : min(1, dt * 2.4));
      if (!reduce && t - _lastRipple > 3.8) {
        _ripples.add(0);
        _lastRipple = t;
      }
      for (var i = 0; i < _ripples.length; i++) {
        _ripples[i] += reduce ? 0 : dt * 21;
      }
      _ripples.removeWhere((r) => r > 110);
      setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: _ScenePainter(_t, _bloom, List.of(_ripples), widget.tod ?? todNow(), widget.decor), size: Size.infinite),
      );
}

class _ScenePainter extends CustomPainter {
  final double t, bloom;
  final List<double> ripples;
  final Tod tod;
  final List<String> decor;
  _ScenePainter(this.t, this.bloom, this.ripples, this.tod, this.decor);

  static final _stars = List.generate(40, (i) {
    double f(double x) => x - x.floorToDouble();
    return (f(sin(i * 12.9898) * 43758.5453), f(sin(i * 78.233) * 12543.21), (i % 3) + 1.0);
  });

  void _hill(Canvas c, Size s, double base, double amp, double freq, double phase, Color col) {
    final p = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width + 6; x += 6) {
      p.lineTo(x, base - amp * (0.6 * sin(x * freq + phase) + 0.4 * sin(x * freq * 2.3 + phase * 1.7)));
    }
    p
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(p, Paint()..color = col);
  }

  void _petal(Canvas c, Offset o, double ang, double len, double wid, Color c0, Color c1) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(ang);
    final p = Path()
      ..moveTo(0, 0)
      ..cubicTo(-wid, -len * .35, -wid * .6, -len * .85, 0, -len)
      ..cubicTo(wid * .6, -len * .85, wid, -len * .35, 0, 0);
    c.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c1, c0])
              .createShader(Rect.fromLTWH(-wid, -len, wid * 2, len)));
    c.restore();
  }

  void _leaf(Canvas c, Offset o, double rx, double ry, Color col) {
    final r = Rect.fromCenter(center: o, width: rx * 2, height: ry * 2);
    final p = Path()
      ..moveTo(o.dx, o.dy)
      ..arcTo(r, 0.15, pi * 2 - 0.3, false)
      ..close();
    c.drawPath(p, Paint()..color = col);
    c.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .12));
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, P = _scenes[tod]!;
    final hz = h * .58;
    c.drawRect(
        Rect.fromLTWH(0, 0, w, hz + 1),
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: P.sky)
              .createShader(Rect.fromLTWH(0, 0, w, hz)));
    if (tod == Tod.night) {
      for (var i = 0; i < _stars.length; i++) {
        final (fx, fy, sz) = _stars[i];
        c.drawRect(Rect.fromLTWH(fx * w, fy * hz * .8, sz * .8, sz * .8),
            Paint()..color = const Color(0xFFF2EBD3).withValues(alpha: .35 + .35 * sin(t * 1.3 + i)));
      }
    }
    final sx = w * .8, sy = tod == Tod.day ? hz * .32 : tod == Tod.night ? hz * .3 : hz * .72;
    const sr = 16.0;
    c.drawCircle(
        Offset(sx, sy),
        sr * 5,
        Paint()
          ..shader = RadialGradient(colors: [P.sun.withValues(alpha: .65), P.sun.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: Offset(sx, sy), radius: sr * 5)));
    c.drawCircle(Offset(sx, sy), sr, Paint()..color = P.sun);
    if (tod == Tod.night) c.drawCircle(Offset(sx + 6, sy - 4), sr * .85, Paint()..color = P.sky[0]);
    _hill(c, s, hz - 4, 18, .012, 1.2, P.hills[0]);
    _hill(c, s, hz + 2, 10, .02, 4.1, P.hills[1]);
    if (decor.contains('sala')) _sala(c, Offset(w * .14, hz + 2), P.hills[1]);
    c.drawRect(
        Rect.fromLTWH(0, hz, w, h - hz),
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: P.water)
              .createShader(Rect.fromLTWH(0, hz, w, h - hz)));
    for (var i = 0; i < 9; i++) {
      final yy = hz + 6 + i * 7, ww = (22 - i * 1.8) * (.7 + .3 * sin(t * 2 + i));
      c.drawRect(Rect.fromLTWH(sx - ww / 2, yy, ww, 1.5), Paint()..color = P.sun.withValues(alpha: .45 - i * .04));
    }
    if (tod != Tod.night) {
      for (var i = 0; i < 3; i++) {
        final mx = ((t * 6 + i * w / 2.5) % (w + 240)) - 120;
        c.drawOval(
            Rect.fromCenter(center: Offset(mx, hz - 2), width: 240, height: 60),
            Paint()
              ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: .28), Colors.white.withValues(alpha: 0)])
                  .createShader(Rect.fromCenter(center: Offset(mx, hz - 2), width: 240, height: 60)));
      }
    }
    final f = Offset(w * .32, h * .84);
    if (decor.contains('fish')) _fish(c, s, hz);
    if (decor.contains('lantern')) _lantern(c, s, hz);
    for (final r in ripples) {
      c.drawOval(
          Rect.fromCenter(center: f.translate(0, 4), width: (r + 14) * 2, height: (r + 14) * .44),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: .35 * (1 - r / 110)));
    }
    _leaf(c, f.translate(70, 12), 44, 9, P.leaf);
    _leaf(c, Offset(w * .62, h * .75), 28, 6, P.leaf);
    _leaf(c, f.translate(-58, 18), 34, 7.5, P.leaf);
    if (decor.contains('frog')) _frog(c, f.translate(70, 6));

    final o = bloom / 5, sway = sin(t * .8) * .03;
    final spread = .12 + 1.0 * o, len = 30 + 10 * o, wid = 9 + 7 * o;
    const order = [-1.0, 1.0, -.62, .62, -.28, .28, 0.0];
    for (var i = 0; i < order.length; i++) {
      _petal(c, f, order[i] * spread + sway, i < 2 ? len * .92 : len, wid, P.petal[0], P.petal[1]);
    }
    if (o > .35) {
      c.drawOval(Rect.fromCenter(center: f.translate(0, -len * .42), width: 10 * o, height: 6 * o),
          Paint()..color = const Color(0xFFF2C45C).withValues(alpha: o.clamp(0, 1)));
    }
    for (final m in const [-.75, .75]) {
      _petal(c, f.translate(0, 2), m * spread * .9 + sway, len * .7, wid * .9, P.petal[0], P.petal[1]);
    }
    if (decor.contains('dragonfly')) _dragonfly(c, Offset(w * .58 + 26 * sin(t * .6), hz - 18 + 7 * sin(t * 1.4)));
    if (decor.contains('firefly')) _fireflies(c, s, hz);
  }

  void _sala(Canvas c, Offset base, Color col) {
    final p = Paint()..color = Color.lerp(col, Colors.black, .35)!;
    c.drawRect(Rect.fromLTWH(base.dx - 15, base.dy - 16, 3, 16), p);
    c.drawRect(Rect.fromLTWH(base.dx + 12, base.dy - 16, 3, 16), p);
    c.drawPath(
        Path()
          ..moveTo(base.dx - 24, base.dy - 15)
          ..quadraticBezierTo(base.dx, base.dy - 22, base.dx + 24, base.dy - 15)
          ..lineTo(base.dx + 4, base.dy - 34)
          ..lineTo(base.dx - 4, base.dy - 34)
          ..close(),
        p);
    c.drawRect(Rect.fromLTWH(base.dx - 20, base.dy - 2, 40, 3), p);
  }

  void _fish(Canvas c, Size s, double hz) {
    for (var i = 0; i < 2; i++) {
      final ph = t * .28 + i * 2.6;
      final x = s.width * (.52 + .34 * sin(ph));
      final y = hz + (s.height - hz) * (.42 + .1 * i) + 6 * sin(ph * 1.7);
      final dir = cos(ph) >= 0 ? 1.0 : -1.0;
      final main = i == 0 ? const Color(0xFFF08A3C) : const Color(0xFFF4F0E8);
      final spot = i == 0 ? const Color(0xFFF4F0E8) : const Color(0xFFF08A3C);
      c.save();
      c.translate(x, y);
      c.scale(dir, 1);
      final body = Paint()..color = main.withValues(alpha: .8);
      c.drawOval(const Rect.fromLTWH(-11, -4, 22, 8), body);
      c.drawPath(
          Path()
            ..moveTo(-10, 0)
            ..lineTo(-18, -5 + 2 * sin(t * 6 + i))
            ..lineTo(-18, 5 + 2 * sin(t * 6 + i))
            ..close(),
          body);
      c.drawOval(const Rect.fromLTWH(-2, -3, 7, 4), Paint()..color = spot.withValues(alpha: .8));
      c.restore();
    }
  }

  void _lantern(Canvas c, Size s, double hz) {
    final x = ((t * 7) % (s.width + 80)) - 40;
    final y = hz + (s.height - hz) * .3 + 2 * sin(t * 1.2);
    final glow = Offset(x, y - 6);
    c.drawCircle(
        glow,
        22,
        Paint()
          ..shader = RadialGradient(colors: [const Color(0xFFFFC46B).withValues(alpha: .5), Colors.transparent])
              .createShader(Rect.fromCircle(center: glow, radius: 22)));
    c.drawPath(
        Path()
          ..moveTo(x - 10, y)
          ..lineTo(x + 10, y)
          ..lineTo(x + 7, y + 4)
          ..lineTo(x - 7, y + 4)
          ..close(),
        Paint()..color = const Color(0xFF6F9C6B));
    for (final a in const [-.6, .6, 0.0]) {
      c.save();
      c.translate(x, y);
      c.rotate(a);
      c.drawPath(
          Path()
            ..moveTo(0, 0)
            ..cubicTo(-4, -4, -3, -9, 0, -12)
            ..cubicTo(3, -9, 4, -4, 0, 0),
          Paint()..color = const Color(0xFFF2C45C));
      c.restore();
    }
    c.drawLine(Offset(x, y - 10), Offset(x, y - 15), Paint()
      ..color = const Color(0xFFFFE6A8)
      ..strokeWidth = 1.5);
  }

  void _frog(Canvas c, Offset o) {
    final g = Paint()..color = const Color(0xFF7DBA6A);
    c.drawOval(Rect.fromCenter(center: o, width: 18, height: 12), g);
    c.drawCircle(o.translate(-5, -6), 3.6, g);
    c.drawCircle(o.translate(5, -6), 3.6, g);
    final eye = Paint()
      ..color = const Color(0xFF1E2A22)
      ..strokeWidth = 1.2;
    // the frog closes its eyes now and then, as if meditating
    if (sin(t * .9) > .6) {
      c.drawLine(o.translate(-7, -6), o.translate(-3, -6), eye);
      c.drawLine(o.translate(3, -6), o.translate(7, -6), eye);
    } else {
      c.drawCircle(o.translate(-5, -6), 1.4, eye);
      c.drawCircle(o.translate(5, -6), 1.4, eye);
    }
    c.drawArc(
        Rect.fromCenter(center: o.translate(0, -1), width: 7, height: 4),
        0,
        pi,
        false,
        Paint()
          ..color = const Color(0xFF1E2A22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  void _dragonfly(Canvas c, Offset o) {
    final wing = Paint()..color = Colors.white.withValues(alpha: .45 + .2 * sin(t * 30));
    for (final dy in const [-2.0, 2.0]) {
      c.drawOval(Rect.fromCenter(center: o.translate(-6, dy * 2), width: 12, height: 4), wing);
      c.drawOval(Rect.fromCenter(center: o.translate(6, dy * 2), width: 12, height: 4), wing);
    }
    c.drawLine(
        o.translate(0, -4),
        o.translate(0, 14),
        Paint()
          ..color = const Color(0xFF3F8FA8)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
  }

  void _fireflies(Canvas c, Size s, double hz) {
    final strong = tod == Tod.night || tod == Tod.dusk;
    for (var i = 0; i < 9; i++) {
      final x = s.width * (.08 + .84 * ((sin(i * 7.3) + 1) / 2)) + 10 * sin(t * .5 + i);
      final y = hz - 30 + 40 * ((sin(i * 3.1) + 1) / 2) + 6 * sin(t * .8 + i * 2);
      final a = (.5 + .5 * sin(t * 2 + i * 1.7)) * (strong ? 1 : .45);
      final o = Offset(x, y);
      c.drawCircle(
          o,
          7,
          Paint()
            ..shader = RadialGradient(colors: [const Color(0xFFE6F59A).withValues(alpha: a * .7), Colors.transparent])
                .createShader(Rect.fromCircle(center: o, radius: 7)));
      c.drawCircle(o, 1.4, Paint()..color = const Color(0xFFF6FFC8).withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => true;
}

