import 'package:flutter/material.dart';
import '../main.dart';
import '../services/payoff_planner.dart';

/// Minimalist chart comparing two combined-debt curves
/// (e.g. no-extra-budget vs planned budget).
class DebtCurveChart extends StatelessWidget {
  final List<DebtPoint> baseline;
  final List<DebtPoint> planned;
  final double height;

  const DebtCurveChart({
    super.key,
    required this.baseline,
    required this.planned,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _DebtCurvePainter(baseline, planned),
      ),
    );
  }
}

class _DebtCurvePainter extends CustomPainter {
  final List<DebtPoint> baseline;
  final List<DebtPoint> planned;

  _DebtCurvePainter(this.baseline, this.planned);

  @override
  void paint(Canvas canvas, Size size) {
    if (baseline.isEmpty && planned.isEmpty) return;

    final maxMonths = [
      if (baseline.isNotEmpty) baseline.last.monthIndex,
      if (planned.isNotEmpty) planned.last.monthIndex,
    ].reduce((a, b) => a > b ? a : b);

    double maxBalance = 0;
    for (final p in baseline) {
      if (p.totalBalance > maxBalance) maxBalance = p.totalBalance;
    }
    for (final p in planned) {
      if (p.totalBalance > maxBalance) maxBalance = p.totalBalance;
    }
    if (maxBalance <= 0 || maxMonths <= 0) return;

    // subtle horizontal grid lines
    final gridPaint = Paint()
      ..color = kHairline
      ..strokeWidth = 0.8;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Path buildPath(List<DebtPoint> points, double startBalance) {
      final path = Path();
      path.moveTo(0, size.height * (1 - startBalance / maxBalance));
      for (final p in points) {
        final x = size.width * (p.monthIndex / maxMonths);
        final y = size.height * (1 - p.totalBalance / maxBalance);
        path.lineTo(x, y);
      }
      return path;
    }

    final startBalance =
        baseline.isNotEmpty ? maxBalance : maxBalance;

    if (baseline.isNotEmpty) {
      final basePaint = Paint()
        ..color = kSubtle.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawPath(buildPath(baseline, startBalance), basePaint);
    }

    if (planned.isNotEmpty) {
      final planPaint = Paint()
        ..color = kAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(buildPath(planned, startBalance), planPaint);

      final last = planned.last;
      final x = size.width * (last.monthIndex / maxMonths);
      final y = size.height * (1 - last.totalBalance / maxBalance);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = kAccent);
    }
  }

  @override
  bool shouldRepaint(covariant _DebtCurvePainter oldDelegate) =>
      oldDelegate.baseline != baseline || oldDelegate.planned != planned;
}
