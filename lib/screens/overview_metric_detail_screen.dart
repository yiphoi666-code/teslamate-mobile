import 'package:flutter/material.dart';

import '../data/reader_api_client.dart';
import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';
import 'charge_detail_screen.dart';
import 'drive_detail_screen.dart';

enum OverviewMetricKind { distance, efficiency, charging, sleep }

class OverviewMetricDetailScreen extends StatelessWidget {
  const OverviewMetricDetailScreen({
    required this.data,
    required this.kind,
    required this.readerApiConfig,
    required this.usingRemoteData,
    super.key,
  });

  final TeslamateDashboardData data;
  final OverviewMetricKind kind;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;

  @override
  Widget build(BuildContext context) {
    final meta = _metricMeta();

    return Scaffold(
      appBar: AppBar(title: Text(meta.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _MetricHero(meta: meta),
          const SizedBox(height: 16),
          ..._buildBody(context),
        ],
      ),
    );
  }

  _MetricMeta _metricMeta() {
    final stats = data.monthlyStats;
    final hasStateHours = stats.asleepHours > 0 || stats.onlineHours > 0;

    return switch (kind) {
      OverviewMetricKind.distance => _MetricMeta(
        icon: Icons.route,
        title: 'Distance detail',
        value: '${stats.distanceKm.toStringAsFixed(0)} km',
        caption: '${stats.driveCount} drives this month',
        color: const Color(0xFF1B7F79),
      ),
      OverviewMetricKind.efficiency => _MetricMeta(
        icon: Icons.speed,
        title: 'Efficiency detail',
        value: '${stats.efficiencyWhPerKm} Wh/km',
        caption: '${stats.energyKwh.toStringAsFixed(1)} kWh used',
        color: const Color(0xFF6B6E23),
      ),
      OverviewMetricKind.charging => _MetricMeta(
        icon: Icons.bolt,
        title: 'Charging detail',
        value: '${stats.chargeCount} sessions',
        caption: formatMoney(stats.chargingCost),
        color: const Color(0xFFB35C00),
      ),
      OverviewMetricKind.sleep => _MetricMeta(
        icon: Icons.bedtime,
        title: 'State timeline',
        value: hasStateHours
            ? '${stats.asleepHours.toStringAsFixed(0)} h'
            : 'No data',
        caption: hasStateHours
            ? '${stats.onlineHours.toStringAsFixed(0)} h online'
            : 'State history pending',
        color: const Color(0xFF56616A),
      ),
    };
  }

  List<Widget> _buildBody(BuildContext context) {
    return switch (kind) {
      OverviewMetricKind.distance => [
        Text('Recent drives', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...data.drives.map(
          (drive) => _DriveEntry(
            data: data,
            drive: drive,
            readerApiConfig: readerApiConfig,
            usingRemoteData: usingRemoteData,
          ),
        ),
      ],
      OverviewMetricKind.efficiency => [
        Text('Drive efficiency', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...data.drives.map(
          (drive) => _DriveEntry(
            data: data,
            drive: drive,
            readerApiConfig: readerApiConfig,
            usingRemoteData: usingRemoteData,
          ),
        ),
      ],
      OverviewMetricKind.charging => [
        Text(
          'Charging sessions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        ...data.charges.map(
          (charge) => _ChargeEntry(
            data: data,
            charge: charge,
            readerApiConfig: readerApiConfig,
            usingRemoteData: usingRemoteData,
          ),
        ),
      ],
      OverviewMetricKind.sleep => [
        Text('Vehicle states', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (data.analytics.stateTimeline.isEmpty)
          const _EmptyMetricBody(
            message: 'State history has not been returned by Reader API.',
          )
        else
          ...data.analytics.stateTimeline.map(_StateEntry.new),
      ],
    };
  }
}

class _MetricMeta {
  const _MetricMeta({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final Color color;
}

class _MetricHero extends StatelessWidget {
  const _MetricHero({required this.meta});

  final _MetricMeta meta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: meta.color.withValues(alpha: 0.16),
              child: Icon(meta.icon, color: meta.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meta.value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(meta.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveEntry extends StatelessWidget {
  const _DriveEntry({
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
      child: ListTile(
        leading: const Icon(Icons.route),
        title: Text(
          '${drive.startLocation} -> ${drive.endLocation}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${drive.distanceKm.toStringAsFixed(1)} km | '
          '${drive.efficiencyWhPerKm} Wh/km | '
          '${formatDuration(drive.duration)}',
        ),
        trailing: const Icon(Icons.chevron_right),
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
      ),
    );
  }
}

class _ChargeEntry extends StatelessWidget {
  const _ChargeEntry({
    required this.data,
    required this.charge,
    required this.readerApiConfig,
    required this.usingRemoteData,
  });

  final TeslamateDashboardData data;
  final ChargeSession charge;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.ev_station),
        title: Text(
          charge.location,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatDate(charge.startedAt)} | '
          '${charge.addedKwh.toStringAsFixed(1)} kWh | '
          '${formatMoney(charge.cost)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChargeDetailScreen(
                carId: data.carId,
                charge: charge,
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

class _EmptyMetricBody extends StatelessWidget {
  const _EmptyMetricBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Column(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StateEntry extends StatelessWidget {
  const _StateEntry(this.segment);

  final StateTimelineSegment segment;

  @override
  Widget build(BuildContext context) {
    final widthFactor = (segment.hours / 220).clamp(0.06, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    segment.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${segment.hours.toStringAsFixed(1)} h'),
              ],
            ),
            const SizedBox(height: 10),
            FractionallySizedBox(
              widthFactor: widthFactor,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B7F79),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
