import 'package:flutter/material.dart';

import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';

class LocationsScreen extends StatelessWidget {
  const LocationsScreen({required this.data, super.key});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _MapPreview(vehicle: data.vehicle),
        const SizedBox(height: 16),
        Text('Frequent places', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...data.locations.map(
          (location) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LocationCard(location: location),
          ),
        ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.vehicle});

  final VehicleSnapshot vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFEA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car, size: 34),
                  const SizedBox(height: 8),
                  Text(
                    vehicle.locationName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vehicle.latitude.toStringAsFixed(4)}, ${vehicle.longitude.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location});

  final LocationVisit location;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(_iconForKind(location.kind)),
        ),
        title: Text(
          location.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${location.address} | ${location.visitCount} visits | ${formatDate(location.lastVisitedAt)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text('${location.distanceFromHomeKm.toStringAsFixed(1)} km'),
      ),
    );
  }

  IconData _iconForKind(String kind) {
    return switch (kind) {
      'Geofence' => Icons.home_outlined,
      'Work' => Icons.work_outline,
      'Charging' => Icons.ev_station_outlined,
      _ => Icons.place_outlined,
    };
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1;

    for (double x = 18; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x - 28, size.height), paint);
    }
    for (double y = 22; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 30), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
