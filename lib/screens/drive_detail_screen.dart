import 'package:flutter/material.dart';

import '../data/reader_api_client.dart';
import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';
import '../widgets/mini_charts.dart';

class DriveDetailScreen extends StatefulWidget {
  const DriveDetailScreen({
    required this.carId,
    required this.drive,
    required this.readerApiConfig,
    required this.usingRemoteData,
    super.key,
  });

  final int carId;
  final DriveRecord drive;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;

  @override
  State<DriveDetailScreen> createState() => _DriveDetailScreenState();
}

class _DriveDetailScreenState extends State<DriveDetailScreen> {
  late final Future<DriveRecord>? _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture =
        widget.usingRemoteData && widget.readerApiConfig.isConfigured
        ? ReaderApiClient(
            config: widget.readerApiConfig,
          ).loadDriveDetail(carId: widget.carId, driveId: widget.drive.id)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drive detail')),
      body: FutureBuilder<DriveRecord>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final drive = snapshot.data ?? widget.drive;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const _DetailNotice(
                  icon: Icons.sync,
                  text: 'Loading tracking curves from Reader API...',
                ),
              if (snapshot.hasError)
                _DetailNotice(
                  icon: Icons.error_outline,
                  text: 'Could not load tracking curves: ${snapshot.error}',
                ),
              _DriveHero(drive: drive),
              const SizedBox(height: 12),
              RouteTraceView(title: 'Route tracking', points: drive.route),
              const SizedBox(height: 12),
              MiniLineChart(
                title: 'Speed',
                points: drive.speedCurve,
                color: const Color(0xFF1B7F79),
                unit: 'km/h',
              ),
              const SizedBox(height: 12),
              MiniLineChart(
                title: 'Battery',
                points: drive.batteryCurve,
                color: const Color(0xFFB35C00),
                unit: '%',
              ),
              const SizedBox(height: 12),
              MiniLineChart(
                title: 'Elevation',
                points: drive.elevationCurve,
                color: const Color(0xFF56616A),
                unit: 'm',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailNotice extends StatelessWidget {
  const _DetailNotice({required this.icon, required this.text});

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

class _DriveHero extends StatelessWidget {
  const _DriveHero({required this.drive});

  final DriveRecord drive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatDate(drive.startedAt),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text('#${drive.id}', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 16),
            Text(drive.startLocation, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 5),
                Container(width: 1, height: 28, color: Colors.black26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${drive.distanceKm.toStringAsFixed(1)} km | '
                    '${formatDuration(drive.duration)} | '
                    '${drive.energyKwh.toStringAsFixed(1)} kWh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              drive.endLocation,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FactChip(label: '${drive.efficiencyWhPerKm} Wh/km'),
                _FactChip(
                  label: '${drive.averageSpeedKmh.toStringAsFixed(0)} km/h avg',
                ),
                _FactChip(label: '${drive.maxSpeedKmh} km/h max'),
                _FactChip(
                  label:
                      '${drive.startBatteryLevel}% -> ${drive.endBatteryLevel}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}
