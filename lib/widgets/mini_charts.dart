import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/teslamate_models.dart';

class MiniLineChart extends StatelessWidget {
  const MiniLineChart({
    required this.title,
    required this.points,
    required this.color,
    required this.unit,
    super.key,
  });

  final String title;
  final List<ChartPoint> points;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLine = points.length >= 2;
    final lastValue = hasLine ? points.last.value : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                Text(
                  lastValue == null
                      ? 'No data'
                      : '${lastValue.toStringAsFixed(0)} $unit',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 132,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _MiniLineChartPainter(
                      points: points,
                      color: color,
                    ),
                  ),
                  if (!hasLine)
                    Center(
                      child: Text(
                        'Waiting for curve samples',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (hasLine)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(points.first.label, style: theme.textTheme.bodySmall),
                  Text(points.last.label, style: theme.textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class RouteTraceView extends StatelessWidget {
  const RouteTraceView({required this.title, required this.points, super.key});

  final String title;
  final List<RoutePoint> points;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: const Color(0xFFEAF1EC),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: CustomPaint(
                      painter: _RouteTracePainter(points: points),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              points.length < 2
                  ? 'Waiting for tracking points from Reader API.'
                  : '${points.length} sampled tracking points',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniLineChartPainter extends CustomPainter {
  const _MiniLineChartPainter({required this.points, required this.color});

  final List<ChartPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) {
      return;
    }

    final values = points.map((point) => point.value).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1, maxValue - minValue);
    final step = size.width / (points.length - 1);
    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final x = step * i;
      final y =
          size.height - ((points[i].value - minValue) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _RouteTracePainter extends CustomPainter {
  const _RouteTracePainter({required this.points});

  final List<RoutePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.68)
      ..strokeWidth = 2;
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }

    if (points.isEmpty) {
      return;
    }

    final latitudes = points.map((point) => point.latitude);
    final longitudes = points.map((point) => point.longitude);
    final minLat = latitudes.reduce(math.min);
    final maxLat = latitudes.reduce(math.max);
    final minLng = longitudes.reduce(math.min);
    final maxLng = longitudes.reduce(math.max);
    final latRange = math.max(0.0001, maxLat - minLat);
    final lngRange = math.max(0.0001, maxLng - minLng);

    Offset project(RoutePoint point) {
      final x = (point.longitude - minLng) / lngRange * (size.width - 48) + 24;
      final y =
          size.height -
          ((point.latitude - minLat) / latRange * (size.height - 48) + 24);
      return Offset(x, y);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final offset = project(points[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF1B7F79)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final start = project(points.first);
    final end = project(points.last);
    canvas.drawCircle(start, 7, Paint()..color = const Color(0xFF0E1713));
    canvas.drawCircle(end, 7, Paint()..color = const Color(0xFFB35C00));
  }

  @override
  bool shouldRepaint(covariant _RouteTracePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
