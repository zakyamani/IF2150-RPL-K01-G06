import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// The handle overlaps the paper body at every display density.
class SurpriseBag extends StatelessWidget {
  final double width, height;
  final bool bread;
  const SurpriseBag({
    super.key,
    this.width = 100,
    this.height = 132,
    this.bread = false,
  });
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _BagPainter(bread)),
    ),
  );
}

class _BagPainter extends CustomPainter {
  final bool bread;
  const _BagPainter(this.bread);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 132);
    final body = Path()
      ..moveTo(17, 37)
      ..lineTo(79, 37)
      ..lineTo(86, 117)
      ..quadraticBezierTo(54, 129, 22, 118)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFC79B61));
    canvas.drawPath(
      Path()
        ..moveTo(17, 37)
        ..lineTo(31, 48)
        ..lineTo(30, 120)
        ..lineTo(22, 118)
        ..close(),
      Paint()..color = const Color(0xFFAE854F),
    );
    if (bread) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(49, 16, 27, 43),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xFFE9C98D),
      );
      final cuts = Paint()
        ..color = const Color(0xFFAE854F)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (final y in [25.0, 34.0, 43.0]) {
        canvas.drawLine(Offset(57, y), Offset(68, y + 5), cuts);
      }
    }
    canvas.drawCircle(const Offset(53, 81), 17, Paint()..color = Brand.green);
    _leaf(canvas, const Offset(43, 69), 22, Brand.paper);
    final handle = Path()
      ..moveTo(34, 42)
      ..lineTo(34, 20)
      ..cubicTo(34, -1, 72, -1, 72, 20)
      ..lineTo(72, 42);
    canvas.drawPath(
      handle,
      Paint()
        ..color = Brand.green
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BagPainter oldDelegate) => oldDelegate.bread != bread;
}

void _leaf(Canvas canvas, Offset at, double size, Color color) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(size / 24);
  canvas.drawPath(
    Path()
      ..moveTo(2, 22)
      ..cubicTo(1, 7, 13, 1, 24, 0)
      ..cubicTo(23, 13, 15, 23, 2, 22)
      ..close(),
    Paint()..color = color,
  );
  canvas.drawPath(
    Path()
      ..moveTo(3, 22)
      ..lineTo(18, 7),
    Paint()
      ..color = color == Brand.paper ? Brand.green : Brand.paper
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke,
  );
  canvas.restore();
}

class BrandTitle extends StatelessWidget {
  final String title;
  const BrandTitle({super.key, this.title = 'sisarasa'});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: 23,
        height: 25,
        child: CustomPaint(painter: _LeafPainter()),
      ),
      const SizedBox(width: 8),
      Flexible(child: Text(title)),
    ],
  );
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter();
  @override
  void paint(Canvas canvas, Size size) =>
      _leaf(canvas, Offset.zero, size.width, Brand.green);
  @override
  bool shouldRepaint(_LeafPainter oldDelegate) => false;
}

class BagPanel extends StatelessWidget {
  final bool bread;
  const BagPanel({super.key, this.bread = false});
  @override
  Widget build(BuildContext context) => Container(
    height: 162,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Brand.pale,
      borderRadius: BorderRadius.circular(22),
    ),
    child: SurpriseBag(bread: bread),
  );
}
