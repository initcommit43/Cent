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
    this.domain,
    this.guide,
  });

  final List<double> values;
  final String semanticLabel;
  final double height;

  /// Points on the full x-axis when [values] covers only part of it, such
  /// as a budget period that is still running.
  final int? domain;

  /// Draws a dashed line from zero to this value across the axis, and
  /// starts the y-axis at zero.
  final double? guide;

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
            domain: domain ?? values.length,
            guide: guide,
            line: c.primary,
            grid: c.hairline,
            guideColor: c.mute,
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.domain,
    required this.guide,
    required this.line,
    required this.grid,
    required this.guideColor,
  });

  final List<double> values;
  final int domain;
  final double? guide;
  final Color line;
  final Color grid;
  final Color guideColor;

  static const _dotRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final y in [0.5, size.height / 2, size.height - 0.5]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.isEmpty || domain < 2) return;

    var low = values.reduce((a, b) => a < b ? a : b);
    var high = values.reduce((a, b) => a > b ? a : b);
    if (guide != null) {
      low = low < 0 ? low : 0;
      high = high > guide! ? high : guide!;
    }
    // A flat series still needs vertical room, otherwise it divides by zero.
    if (high - low < 1) {
      high += 1;
      low -= 1;
    }
    // Keep the line and its end dot inside the plot.
    const top = _dotRadius + 2;
    final usable = size.height - top * 2;
    final right = size.width - _dotRadius;

    double y(double v) => top + usable * (1 - (v - low) / (high - low));
    Offset point(int i) => Offset(right * i / (domain - 1), y(values[i]));

    if (guide != null) {
      _dashed(canvas, Offset(0, y(0)), Offset(right, y(guide!)));
    }
    if (values.length < 2) {
      canvas.drawCircle(point(0), _dotRadius, Paint()..color = line);
      return;
    }

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

  void _dashed(Canvas canvas, Offset from, Offset to) {
    final paint = Paint()
      ..color = guideColor
      ..strokeWidth = 1.5;
    final delta = to - from;
    final length = delta.distance;
    const dash = 4.0;
    for (var d = 0.0; d < length; d += dash * 2) {
      final end = d + dash > length ? length : d + dash;
      canvas.drawLine(
        from + delta * (d / length),
        from + delta * (end / length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.domain != domain ||
      old.guide != guide ||
      old.line != line ||
      old.grid != grid;
}
