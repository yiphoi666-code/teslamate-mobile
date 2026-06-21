import 'package:flutter/material.dart';

import '../data/reader_api_client.dart';
import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';
import '../widgets/metric_tile.dart';
import '../widgets/status_chip.dart';
import 'charge_detail_screen.dart';
import 'drive_detail_screen.dart';
import 'overview_metric_detail_screen.dart';
import 'vehicle_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
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
    final vehicle = data.vehicle;
    final stats = data.monthlyStats;
    final hasStateHours = stats.asleepHours > 0 || stats.onlineHours > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _VehicleHero(
          vehicle: vehicle,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VehicleDetailScreen(data: data),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('This month', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.18,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          children: [
            MetricTile(
              icon: Icons.route,
              label: 'Distance',
              value: '${stats.distanceKm.toStringAsFixed(0)} km',
              caption: '${stats.driveCount} drives',
              onTap: () => _openMetric(context, OverviewMetricKind.distance),
            ),
            MetricTile(
              icon: Icons.speed,
              label: 'Efficiency',
              value: '${stats.efficiencyWhPerKm} Wh/km',
              caption: '${stats.energyKwh.toStringAsFixed(1)} kWh used',
              color: const Color(0xFF6B6E23),
              onTap: () => _openMetric(context, OverviewMetricKind.efficiency),
            ),
            MetricTile(
              icon: Icons.bolt,
              label: 'Charging',
              value: '${stats.chargeCount} sessions',
              caption: formatMoney(stats.chargingCost),
              color: const Color(0xFFB35C00),
              onTap: () => _openMetric(context, OverviewMetricKind.charging),
            ),
            MetricTile(
              icon: Icons.bedtime,
              label: 'Sleep time',
              value: hasStateHours
                  ? '${stats.asleepHours.toStringAsFixed(0)} h'
                  : 'No data',
              caption: hasStateHours
                  ? '${stats.onlineHours.toStringAsFixed(0)} h online'
                  : 'State history pending',
              color: const Color(0xFF56616A),
              onTap: () => _openMetric(context, OverviewMetricKind.sleep),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Recent activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        _RecentActivity(
          data: data,
          readerApiConfig: readerApiConfig,
          usingRemoteData: usingRemoteData,
        ),
      ],
    );
  }

  void _openMetric(BuildContext context, OverviewMetricKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OverviewMetricDetailScreen(
          data: data,
          kind: kind,
          readerApiConfig: readerApiConfig,
          usingRemoteData: usingRemoteData,
        ),
      ),
    );
  }
}

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({required this.vehicle, required this.onTap});

  final VehicleSnapshot vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final batteryFraction = vehicle.batteryLevel / 100;

    return Material(
      color: const Color(0xFF17211F),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.displayName,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vehicle.model,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  VehicleStateChip(state: vehicle.state),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${vehicle.batteryLevel}%',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${vehicle.ratedRangeKm.toStringAsFixed(0)} km rated',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: batteryFraction,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  color: scheme.primaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroFact(
                    icon: Icons.location_on_outlined,
                    label: vehicle.locationName,
                  ),
                  _HeroFact(
                    icon: Icons.thermostat,
                    label:
                        '${vehicle.outsideTempC.toStringAsFixed(1)} C outside',
                  ),
                  _HeroFact(
                    icon: Icons.update,
                    label: 'Seen ${formatDate(vehicle.lastSeen)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.data,
    required this.readerApiConfig,
    required this.usingRemoteData,
  });

  final TeslamateDashboardData data;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;

  @override
  Widget build(BuildContext context) {
    final drive = data.drives.isEmpty ? null : data.drives.first;
    final charge = data.charges.isEmpty ? null : data.charges.first;

    return Column(
      children: [
        if (drive != null)
          _ActivityRow(
            icon: Icons.route,
            title: '${drive.startLocation} to ${drive.endLocation}',
            detail:
                '${drive.distanceKm.toStringAsFixed(1)} km | '
                '${formatDuration(drive.duration)} | '
                '${drive.efficiencyWhPerKm} Wh/km',
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
        if (drive != null && charge != null) const SizedBox(height: 10),
        if (charge != null)
          _ActivityRow(
            icon: Icons.bolt,
            title: charge.location,
            detail:
                '${charge.startBatteryLevel}% to ${charge.endBatteryLevel}% | '
                '${charge.addedKwh.toStringAsFixed(1)} kWh',
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
        if (drive == null && charge == null)
          const Card(
            child: ListTile(
              leading: Icon(Icons.history),
              title: Text('No recent activity'),
              subtitle: Text('Reader API has not returned drives or charges.'),
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
