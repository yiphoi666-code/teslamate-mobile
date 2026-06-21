import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/reader_api_client.dart';
import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';

class VisitedMapScreen extends StatefulWidget {
  const VisitedMapScreen({
    required this.data,
    required this.readerApiConfig,
    required this.usingRemoteData,
    super.key,
  });

  final TeslamateDashboardData data;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;

  @override
  State<VisitedMapScreen> createState() => _VisitedMapScreenState();
}

class _VisitedMapScreenState extends State<VisitedMapScreen> {
  late final Future<List<List<RoutePoint>>>? _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture =
        widget.usingRemoteData && widget.readerApiConfig.isConfigured
        ? ReaderApiClient(
            config: widget.readerApiConfig,
          ).loadVisitedRoutes(carId: widget.data.carId)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<RoutePoint>>>(
      future: _routesFuture,
      builder: (context, snapshot) {
        final fallbackRoutes = widget.data.drives
            .where((drive) => drive.route.length >= 2)
            .map((drive) => drive.route)
            .toList();
        final routes = snapshot.data ?? fallbackRoutes;
        final totalPoints = routes.fold<int>(
          0,
          (sum, route) => sum + route.length,
        );

        return _VisitedMapBody(
          data: widget.data,
          routes: routes,
          totalPoints: totalPoints,
          loading: snapshot.connectionState == ConnectionState.waiting,
          error: snapshot.error?.toString(),
        );
      },
    );
  }
}

class _VisitedMapBody extends StatelessWidget {
  const _VisitedMapBody({
    required this.data,
    required this.routes,
    required this.totalPoints,
    required this.loading,
    required this.error,
  });

  final TeslamateDashboardData data;
  final List<List<RoutePoint>> routes;
  final int totalPoints;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final routeDrives = data.drives
        .where((drive) => drive.route.length >= 2)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Visited map')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (loading)
            const _MapNotice(
              icon: Icons.sync,
              text: 'Loading lifetime routes from Reader API...',
            ),
          if (error != null)
            _MapNotice(
              icon: Icons.error_outline,
              text: 'Could not load lifetime routes: $error',
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visited Lifetime Map',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${routes.length} routes - $totalPoints tracking points',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lifetime routes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColoredBox(
                      color: const Color(0xFFEAF1EC),
                      child: SizedBox(
                        height: 360,
                        width: double.infinity,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 8,
                          child: CustomPaint(
                            painter: _LifetimeMapPainter(routes: routes),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Recent route samples',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          ...routeDrives.map(
            (drive) => Card(
              child: ListTile(
                leading: const Icon(Icons.route),
                title: Text('${drive.startLocation} -> ${drive.endLocation}'),
                subtitle: Text(
                  '${formatDate(drive.startedAt)} - '
                  '${drive.distanceKm.toStringAsFixed(1)} km - '
                  '${drive.route.length} points in list summary',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  const _MapNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(leading: Icon(icon), title: Text(text)),
      ),
    );
  }
}

class _LifetimeMapPainter extends CustomPainter {
  const _LifetimeMapPainter({required this.routes});

  final List<List<RoutePoint>> routes;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.64)
      ..strokeWidth = 2;
    for (var i = 1; i < 7; i++) {
      final x = size.width * i / 7;
      final y = size.height * i / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final allPoints = routes.expand((route) => route).toList();
    if (allPoints.isEmpty) {
      return;
    }

    final latitudes = allPoints.map((point) => point.latitude);
    final longitudes = allPoints.map((point) => point.longitude);
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

    for (var routeIndex = 0; routeIndex < routes.length; routeIndex++) {
      final route = routes[routeIndex];
      if (route.length < 2) {
        continue;
      }

      final path = Path();
      for (var i = 0; i < route.length; i++) {
        final offset = project(route[i]);
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }

      final color = routeIndex.isEven
          ? const Color(0xFF1B7F79)
          : const Color(0xFFB35C00);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.86)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (final route in routes) {
      if (route.isEmpty) {
        continue;
      }
      canvas.drawCircle(
        project(route.first),
        5,
        Paint()..color = const Color(0xFF0E1713),
      );
      canvas.drawCircle(
        project(route.last),
        5,
        Paint()..color = const Color(0xFFB35C00),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LifetimeMapPainter oldDelegate) {
    return oldDelegate.routes != routes;
  }
}
