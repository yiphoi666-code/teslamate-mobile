import 'package:flutter/material.dart';

import '../data/reader_api_client.dart';
import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';
import 'drive_detail_screen.dart';
import 'visited_map_screen.dart';

class DrivesScreen extends StatelessWidget {
  const DrivesScreen({
    required this.data,
    required this.readerApiConfig,
    required this.usingRemoteData,
    super.key,
  });

  final TeslamateDashboardData data;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _DriveSummary(data: data),
        const SizedBox(height: 10),
        _VisitedMapEntry(
          data: data,
          readerApiConfig: readerApiConfig,
          usingRemoteData: usingRemoteData,
        ),
        const SizedBox(height: 16),
        Text('Recent drives', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...data.drives.map(
          (drive) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DriveCard(
              data: data,
              drive: drive,
              readerApiConfig: readerApiConfig,
              usingRemoteData: usingRemoteData,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriveSummary extends StatelessWidget {
  const _DriveSummary({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final stats = data.monthlyStats;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryText(
              label: 'Distance',
              value: '${stats.distanceKm.toStringAsFixed(0)} km',
            ),
          ),
          Expanded(
            child: _SummaryText(
              label: 'Energy',
              value: '${stats.energyKwh.toStringAsFixed(1)} kWh',
            ),
          ),
          Expanded(
            child: _SummaryText(
              label: 'Average',
              value: '${stats.efficiencyWhPerKm} Wh/km',
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitedMapEntry extends StatelessWidget {
  const _VisitedMapEntry({
    required this.data,
    required this.readerApiConfig,
    required this.usingRemoteData,
  });

  final TeslamateDashboardData data;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.map_outlined),
        title: const Text('Visited Lifetime Map'),
        subtitle: Text('${data.drives.length} routes ready for preview'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VisitedMapScreen(
                data: data,
                readerApiConfig: readerApiConfig,
                usingRemoteData: usingRemoteData,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryText extends StatelessWidget {
  const _SummaryText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _DriveCard extends StatelessWidget {
  const _DriveCard({
    required this.data,
    required this.drive,
    required this.readerApiConfig,
    required this.usingRemoteData,
  });

  final TeslamateDashboardData data;
  final DriveRecord drive;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DriveDetailScreen(
                carId: data.carId,
                drive: drive,
                readerApiConfig: readerApiConfig,
                usingRemoteData: usingRemoteData,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.route, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formatDate(drive.startedAt),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Text('${drive.maxSpeedKmh} km/h max'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                drive.startLocation,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 4),
                  Container(width: 1, height: 22, color: Colors.black26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${drive.distanceKm.toStringAsFixed(1)} km | ${formatDuration(drive.duration)} | ${drive.energyKwh.toStringAsFixed(1)} kWh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                drive.endLocation,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (drive.efficiencyWhPerKm / 240).clamp(0.08, 1),
                  minHeight: 6,
                  color: const Color(0xFF1B7F79),
                  backgroundColor: const Color(0xFFE7ECE7),
                ),
              ),
              const SizedBox(height: 8),
              Text('${drive.efficiencyWhPerKm} Wh/km efficiency'),
            ],
          ),
        ),
      ),
    );
  }
}
