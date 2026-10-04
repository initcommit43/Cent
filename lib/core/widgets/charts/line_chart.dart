import 'package:flutter/material.dart';

import '../../theme/cent_theme.dart';

/// Minimal line chart: three hairline gridlines, one copper line and a dot
/// on the latest value.
class CentLineChart extends StatelessWidget {
  const CentLineChart({
    super.key,
    required this.values,
    required this.semanticLabel,
    this.height = 120,
  });

  final List<double> values;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(
            values: values,
            line: c.primary,
            grid: c.hairline,
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.values, required this.line, required this.grid});

  final List<double> values;
  final Color line;
  final Color grid;

  static const _dotRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final y in [0.5, size.height / 2, size.height - 0.5]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.length < 2) return;

    var low = values.reduce((a, b) => a < b ? a : b);
    var high = values.reduce((a, b) => a > b ? a : b);
    // A flat series still needs vertical room, otherwise it divides by zero.
    if (high - low < 1) {
      high += 1;
      low -= 1;
    }
    // Keep the line and its end dot inside the plot.
    const top = _dotRadius + 2;
    final usable = size.height - top * 2;
    final right = size.width - _dotRadius;

    Offset point(int i) => Offset(
      right * i / (values.length - 1),
      top + usable * (1 - (values[i] - low) / (high - low)),
    );

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = point(i);
      path.lineTo(p.dx, p.dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(point(values.length - 1), _dotRadius, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.line != line || old.grid != grid;
}
