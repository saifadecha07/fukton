import 'dart:math';

import 'package:flutter/material.dart';

enum BuaMood { sleepy, calm, happy, bloom }

/// บัวน้อย — a small lotus bud who keeps the reader company.
/// It breathes slowly; its face follows how the day is going.
class BuaNoi extends StatefulWidget {
  final BuaMood mood;
  final double size;
  const BuaNoi({super.key, this.mood = BuaMood.calm, this.size = 56});
  @override
  State<BuaNoi> createState() => _BuaNoiState();
}

class _BuaNoiState extends State<BuaNoi> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedBuilder(
      animation: c,
      builder: (_, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _BuaPainter(widget.mood, reduce ? 0 : sin(c.value * 2 * pi)),
      ),
    );
  }
}

class _BuaPainter extends CustomPainter {
  final BuaMood mood;
  final double breath; // -1..1
  _BuaPainter(this.mood, this.breath);

  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 100;
    c.scale(k);
    c.translate(50, 56 + breath * 1.2);
    final sq = 1 + breath * .025;
    c.scale(sq, 2 - sq);

    // leaf pad
    c.drawOval(const Rect.fromLTWH(-34, 26, 68, 14), Paint()..color = const Color(0xFF7FB89B));
    c.drawOval(const Rect.fromLTWH(-30, 27, 60, 9), Paint()..color = const Color(0xFF94C9AD));

    final open = switch (mood) { BuaMood.sleepy => 0.0, BuaMood.calm => .35, BuaMood.happy => .7, BuaMood.bloom => 1.0 };
    const outer = Color(0xFFF08FB0), inner = Color(0xFFFFD6E3);

    // side petals open with the mood
    for (final side in const [-1.0, 1.0]) {
      c.save();
      c.translate(0, 26);
      c.rotate(side * (.35 + .55 * open));
      final p = Path()
        ..moveTo(0, 0)
        ..cubicTo(side * -16, -12, side * -12, -38, 0, -44)
        ..cubicTo(side * 10, -36, side * 8, -10, 0, 0);
      c.drawPath(p, Paint()..color = outer.withValues(alpha: .85));
      c.restore();
    }

    // round body
    final body = Path()
      ..moveTo(0, 28)
      ..cubicTo(-30, 26, -30, -10, 0, -38)
      ..cubicTo(30, -10, 30, 26, 0, 28);
    c.drawPath(
        body,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [inner, outer])
              .createShader(const Rect.fromLTWH(-30, -38, 60, 66)));
    // highlight
    c.drawOval(const Rect.fromLTWH(-16, -22, 9, 14), Paint()..color = Colors.white.withValues(alpha: .45));

    // cheeks
    final blush = Paint()..color = const Color(0xFFFF7FA3).withValues(alpha: .45);
    c.drawOval(const Rect.fromLTWH(-21, 4, 10, 6), blush);
    c.drawOval(const Rect.fromLTWH(11, 4, 10, 6), blush);

    // face
    final ink = Paint()
      ..color = const Color(0xFF3B2A33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    if (mood == BuaMood.sleepy) {
      c.drawLine(const Offset(-13, -2), const Offset(-6, -2), ink);
      c.drawLine(const Offset(6, -2), const Offset(13, -2), ink);
    } else {
      // closed happy eyes
      c.drawArc(const Rect.fromLTWH(-14, -6, 9, 8), pi, pi, false, ink);
      c.drawArc(const Rect.fromLTWH(5, -6, 9, 8), pi, pi, false, ink);
    }
    final smile = mood == BuaMood.sleepy ? 3.0 : mood == BuaMood.calm ? 5.0 : 8.0;
    c.drawArc(Rect.fromCenter(center: const Offset(0, 6), width: 9, height: smile), 0, pi, false, ink);

    if (mood == BuaMood.bloom) {
      final spark = Paint()..color = const Color(0xFFF2C45C);
      for (final (x, y, r) in const [(-30.0, -36.0, 2.6), (28.0, -42.0, 2.0), (34.0, -20.0, 1.6)]) {
        c.drawCircle(Offset(x, y), r, spark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BuaPainter old) => old.breath != breath || old.mood != mood;
}

BuaMood moodFor(int bloom) => bloom == 0 ? BuaMood.sleepy : bloom < 3 ? BuaMood.calm : bloom < 5 ? BuaMood.happy : BuaMood.bloom;

String buaSays(int bloom, int hour) {
  if (hour >= 21 || hour < 4) return 'ใกล้เวลานอนแล้ว\nมาผ่อนลมด้วยกันไหม';
  return switch (bloom) {
    0 => 'สวัสดี\nเริ่มจากสามลมหายใจก็พอ',
    1 || 2 => 'ดีมากเลย\nค่อย ๆ ไปทีละกลีบ',
    3 || 4 => 'เกือบบานแล้ว\nอีกนิดเดียว',
    _ => 'บานเต็มดอกแล้ว\nเก่งมาก',
  };
}
