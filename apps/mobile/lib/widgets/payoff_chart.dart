import 'package:flutter/material.dart';
import '../main.dart';
import '../services/amortization_engine.dart';

/// Minimalist line chart comparing baseline vs accelerated balance curves.
class PayoffChart extends StatelessWidget {
  final ComparisonResult comparison;
  final double height;

  const PayoffChart({super.key, required this.comparison, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _PayoffChartPainter(comparison),
      ),
    );
  }
}

class _PayoffChartPainter extends CustomPainter {
  final ComparisonResult comparison;

  _PayoffChartPainter(this.comparison);

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = comparison.baseline.schedule;
    final accelerated = comparison.accelerated.schedule;
    if (baseline.isEmpty) return;

    final maxMonths = baseline.length;
    final maxBalance = baseline.first.balance + baseline.first.principalPaid;

    // subtle horizontal grid lines
    final gridPaint = Paint()
      ..color = kHairline
      ..strokeWidth = 0.8;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Path buildPath(List<MonthRow> rows) {
      final path = Path();
      path.moveTo(0, size.height * (1 - maxBalance / maxBalance));
      path.moveTo(0, 0);
      for (int i = 0; i < rows.length; i++) {
        final x = size.width * (rows[i].monthIndex / maxMonths);
        final y = size.height * (1 - rows[i].balance / maxBalance);
        if (i == 0) {
          path.moveTo(0, size.height * (1 - (maxBalance) / maxBalance));
          path.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    // baseline curve - light gray
    final basePaint = Paint()
      ..color = kSubtle.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(buildPath(baseline), basePaint);

    // accelerated curve - forest green
    final accPaint = Paint()
      ..color = kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(buildPath(accelerated), accPaint);

    // payoff dot for accelerated
    if (accelerated.isNotEmpty) {
      final last = accelerated.last;
      final x = size.width * (last.monthIndex / maxMonths);
      final y = size.height * (1 - last.balance / maxBalance);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = kAccent);
    }
  }

  @override
  bool shouldRepaint(covariant _PayoffChartPainter oldDelegate) =>
      oldDelegate.comparison != comparison;
}
