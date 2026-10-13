import 'package:flutter/material.dart';

import 'theme.dart';

/// Small shared pieces of UI.

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? border;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.border});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border ?? p.line),
      ),
      child: child,
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: eyebrow(context));
}

class SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String action;
  final VoidCallback onSave;
  const SheetFrame({super.key, required this.title, required this.children, required this.action, required this.onSave});
  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: display(context, 21)),
            const SizedBox(height: 14),
            ...children,
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ไว้ภายหลัง')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onSave, child: Text(action)),
            ]),
          ],
        ),
      ),
    );
  }
}

class Label extends StatelessWidget {
  final String text;
  const Label(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      );
}

class Choice<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;
  const Choice({super.key, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (v, label) in options)
            ChoiceChip(label: Text(label), selected: v == value, onSelected: (_) => onChanged(v), showCheckmark: false),
        ],
      );
}

class Field extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final int lines;
  const Field(this.controller, {super.key, this.hint, this.lines = 3});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines + 4,
      maxLength: 2000,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: p.bg,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      ),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg, textAlign: TextAlign.center), duration: const Duration(milliseconds: 2400)));
}

/// Simple line icons drawn to match the lotus theme.
class GlyphPainter extends CustomPainter {
  final String id;
  final Color color;
  GlyphPainter(this.id, this.color);

  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 48;
    c.scale(k);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;
    switch (id) {
      case 'lion':
        c.drawCircle(const Offset(24, 24), 5, fill);
        for (final (x, sign, a) in [(12.0, -1.0, 1.0), (6.0, -1.0, .55), (36.0, 1.0, 1.0), (42.0, 1.0, .55)]) {
          final p = Path()
            ..moveTo(x, x == 12 || x == 36 ? 15 : 10)
            ..quadraticBezierTo(x + sign * (x == 12 || x == 36 ? 5 : 7), 24, x, x == 12 || x == 36 ? 33 : 38);
          c.drawPath(p, stroke..color = color.withValues(alpha: a));
        }
      case 'wind':
        final net = Paint()
          ..color = color.withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        for (final v in [18.0, 30.0]) {
          c.drawLine(Offset(v, 6), Offset(v, 42), net);
          c.drawLine(Offset(6, v), Offset(42, v), net);
        }
        c.drawPath(
            Path()
              ..moveTo(3, 25)
              ..cubicTo(12, 17, 20, 31, 28, 23)
              ..cubicTo(34, 17, 40, 17, 46, 21),
            stroke);
      case 'lotus':
        Path petal(double a) {
          final p = Path()
            ..moveTo(0, 0)
            ..cubicTo(-8, -9, -6, -20, 0, -27)
            ..cubicTo(6, -20, 8, -9, 0, 0);
          return p.transform((Matrix4.identity()
                ..translateByDouble(24, 36, 0, 1)
                ..rotateZ(a))
              .storage);
        }
        c.drawPath(petal(-.9), fill..color = color.withValues(alpha: .55));
        c.drawPath(petal(.9), fill..color = color.withValues(alpha: .55));
        c.drawPath(petal(0), fill..color = color.withValues(alpha: .95));
        c.drawLine(const Offset(5, 41), const Offset(43, 41), stroke..color = color.withValues(alpha: .5));
    }
  }

  @override
  bool shouldRepaint(covariant GlyphPainter old) => old.id != id || old.color != color;
}

class Glyph extends StatelessWidget {
  final String id;
  final Color color;
  final double size;
  const Glyph(this.id, this.color, {super.key, this.size = 46});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: GlyphPainter(id, color));
}
