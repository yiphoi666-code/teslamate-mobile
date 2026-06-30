import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';
import '../widgets/metric_tile.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({required this.data, this.dataListenable, super.key});

  final TeslamateDashboardData data;
  final ValueListenable<TeslamateDashboardData>? dataListenable;

  @override
  Widget build(BuildContext context) {
    final modules = _InsightModule.all;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _CoverageHeader(data: data, dataListenable: dataListenable),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Dashboard groups'),
        const SizedBox(height: 10),
        ...modules.map(
          (module) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InsightModuleCard(
              data: data,
              dataListenable: dataListenable,
              module: module,
            ),
          ),
        ),
      ],
    );
  }
}

enum _InsightModuleKind {
  vehicle,
  charging,
  battery,
  efficiency,
  drives,
  system,
}

enum _InsightDetailFocus {
  overview,
  currentState,
  chargingCost,
  chargingCurves,
  rangeLoss,
  speedTemperature,
  trackingDrives,
  dataQuality,
}

class _InsightQuickLink {
  const _InsightQuickLink({
    required this.label,
    required this.icon,
    required this.module,
    required this.focus,
    required this.caption,
  });

  final String label;
  final IconData icon;
  final _InsightModule module;
  final _InsightDetailFocus focus;
  final String caption;
}

class _InsightModule {
  const _InsightModule({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.coverage,
  });

  final _InsightModuleKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> coverage;

  static const all = [
    _InsightModule(
      kind: _InsightModuleKind.vehicle,
      icon: Icons.directions_car_outlined,
      title: 'Vehicle live view',
      subtitle: 'Current state, location, states, timeline, updates',
      coverage: ['Overview', 'Current State', 'States', 'Timeline', 'Updates'],
    ),
    _InsightModule(
      kind: _InsightModuleKind.charging,
      icon: Icons.ev_station_outlined,
      title: 'Charging analytics',
      subtitle: 'Charge level, costs, sessions, details, curves',
      coverage: ['Charge Level', 'Charges', 'Charge Details', 'Charging Stats'],
    ),
    _InsightModule(
      kind: _InsightModuleKind.battery,
      icon: Icons.battery_5_bar_outlined,
      title: 'Battery and range',
      subtitle: 'Battery health, projected range, degradation, vampire drain',
      coverage: ['Battery Health', 'Projected Range', 'Vampire Drain'],
    ),
    _InsightModule(
      kind: _InsightModuleKind.efficiency,
      icon: Icons.speed_outlined,
      title: 'Efficiency lab',
      subtitle: 'Speed, temperature, net/gross consumption',
      coverage: ['Efficiency', 'Speed Rates', 'Speed Temperature'],
    ),
    _InsightModule(
      kind: _InsightModuleKind.drives,
      icon: Icons.route_outlined,
      title: 'Drives and trips',
      subtitle: 'Drive stats, details, mileage, trips, tracking',
      coverage: ['Drive Stats', 'Drives', 'Drive Details', 'Mileage', 'Trip'],
    ),
    _InsightModule(
      kind: _InsightModuleKind.system,
      icon: Icons.storage_outlined,
      title: 'System and ownership',
      subtitle: 'Database info, data quality, amortization',
      coverage: ['Database Information', 'Statistics', 'Incomplete Data'],
    ),
  ];

  static _InsightModule byKind(_InsightModuleKind kind) {
    return all.firstWhere((module) => module.kind == kind);
  }
}

class _InsightModuleCard extends StatelessWidget {
  const _InsightModuleCard({
    required this.data,
    required this.module,
    this.dataListenable,
  });

  final TeslamateDashboardData data;
  final ValueListenable<TeslamateDashboardData>? dataListenable;
  final _InsightModule module;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(module.icon),
        ),
        title: Text(
          module.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            module.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _InsightDetailPage(
                data: data,
                dataListenable: dataListenable,
                module: module,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InsightDetailPage extends StatelessWidget {
  const _InsightDetailPage({
    required this.data,
    required this.module,
    this.focus = _InsightDetailFocus.overview,
    this.dataListenable,
  });

  final TeslamateDashboardData data;
  final ValueListenable<TeslamateDashboardData>? dataListenable;
  final _InsightModule module;
  final _InsightDetailFocus focus;

  @override
  Widget build(BuildContext context) {
    final listenable = dataListenable;
    if (listenable == null) {
      return _buildScaffold(data);
    }

    return ValueListenableBuilder<TeslamateDashboardData>(
      valueListenable: listenable,
      builder: (context, latestData, _) => _buildScaffold(latestData),
    );
  }

  Widget _buildScaffold(TeslamateDashboardData data) {
    final pageTitle = focus == _InsightDetailFocus.overview
        ? module.title
        : _focusTitle(focus);

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [..._buildSections(data)],
        ),
      ),
    );
  }

  List<Widget> _buildSections(TeslamateDashboardData data) {
    final analytics = data.analytics;

    final focusedSections = _buildFocusedSections(data, analytics);
    if (focusedSections != null) {
      return focusedSections;
    }

    return switch (module.kind) {
      _InsightModuleKind.vehicle => [
        const _SectionTitle(title: 'Current State'),
        const SizedBox(height: 10),
        _LiveTelemetryGrid(data: data),
        const SizedBox(height: 10),
        _StateTimelineCard(segments: analytics.stateTimeline),
        const SizedBox(height: 10),
        _LocationAndUpdatesCard(data: data),
      ],
      _InsightModuleKind.charging => [
        const _SectionTitle(title: 'Charge Level'),
        const SizedBox(height: 10),
        _ChargeLevelCard(data: data),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Charging Stats'),
        const SizedBox(height: 10),
        _ChargingEconomics(data: analytics),
        const SizedBox(height: 10),
        _TopStationsCard(stations: analytics.topStations),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Charging Curves'),
        const SizedBox(height: 10),
        _ChargingCurveCard(curves: analytics.chargingCurves),
      ],
      _InsightModuleKind.battery => [
        const _SectionTitle(title: 'Battery Health'),
        const SizedBox(height: 10),
        _BatteryRangeSection(data: analytics),
        const SizedBox(height: 10),
        _ProjectedRangeCard(data: data),
        const SizedBox(height: 10),
        _VampireDrainCard(data: data),
      ],
      _InsightModuleKind.efficiency => [
        const _SectionTitle(title: 'Efficiency'),
        const SizedBox(height: 10),
        _SpeedRatesCard(buckets: analytics.speedRates),
        const SizedBox(height: 10),
        _TemperatureHeatmap(points: analytics.speedTemperature),
      ],
      _InsightModuleKind.drives => [
        const _SectionTitle(title: 'Drive Stats'),
        const SizedBox(height: 10),
        _DriveStatsCard(data: data),
        const SizedBox(height: 10),
        _BarChartCard(
          title: 'Mileage by month',
          points: analytics.monthlyMileage,
          color: const Color(0xFF1B7F79),
          valueSuffix: ' km',
        ),
        const SizedBox(height: 10),
        _TripAndTrackingCard(data: data),
      ],
      _InsightModuleKind.system => [
        const _SectionTitle(title: 'Database Information'),
        const SizedBox(height: 10),
        _DatabaseInfoCard(data: data),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Incomplete Data'),
        const SizedBox(height: 10),
        _DataQualityCard(summary: analytics.dataQuality),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Amortization'),
        const SizedBox(height: 10),
        _AmortizationCard(summary: analytics.amortization),
      ],
    };
  }

  List<Widget>? _buildFocusedSections(
    TeslamateDashboardData data,
    AnalyticsData analytics,
  ) {
    return switch (focus) {
      _InsightDetailFocus.overview => null,
      _InsightDetailFocus.currentState => [
        const _SectionTitle(title: 'Current State'),
        const SizedBox(height: 10),
        _LiveTelemetryGrid(data: data),
        const SizedBox(height: 10),
        _CurrentStateDetailCard(data: data),
        const SizedBox(height: 10),
        _StateTimelineCard(segments: analytics.stateTimeline),
      ],
      _InsightDetailFocus.chargingCost => [
        const _SectionTitle(title: 'Charging Cost'),
        const SizedBox(height: 10),
        _ChargingEconomics(data: analytics),
        const SizedBox(height: 10),
        _TopStationsCard(stations: analytics.topStations),
      ],
      _InsightDetailFocus.chargingCurves => [
        const _SectionTitle(title: 'Charging Curves'),
        const SizedBox(height: 10),
        _ChargingCurveCard(curves: analytics.chargingCurves),
        const SizedBox(height: 10),
        _ChargeLevelCard(data: data),
      ],
      _InsightDetailFocus.rangeLoss => [
        const _SectionTitle(title: 'Range Loss'),
        const SizedBox(height: 10),
        _BatteryRangeSection(data: analytics),
        const SizedBox(height: 10),
        _ProjectedRangeCard(data: data),
        const SizedBox(height: 10),
        _VampireDrainCard(data: data),
      ],
      _InsightDetailFocus.speedTemperature => [
        const _SectionTitle(title: 'Speed Temperature'),
        const SizedBox(height: 10),
        _TemperatureHeatmap(points: analytics.speedTemperature),
        const SizedBox(height: 10),
        _SpeedRatesCard(buckets: analytics.speedRates),
      ],
      _InsightDetailFocus.trackingDrives => [
        const _SectionTitle(title: 'Tracking Drives'),
        const SizedBox(height: 10),
        _TrackingDrivesDetailCard(data: data),
        const SizedBox(height: 10),
        _DriveStatsCard(data: data),
      ],
      _InsightDetailFocus.dataQuality => [
        const _SectionTitle(title: 'Data Quality'),
        const SizedBox(height: 10),
        _DataQualityCard(summary: analytics.dataQuality),
        const SizedBox(height: 10),
        _DatabaseInfoCard(data: data),
      ],
    };
  }
}

String _focusTitle(_InsightDetailFocus focus) {
  return switch (focus) {
    _InsightDetailFocus.overview => 'Overview',
    _InsightDetailFocus.currentState => 'Current State',
    _InsightDetailFocus.chargingCost => 'Charging Cost',
    _InsightDetailFocus.chargingCurves => 'Charging Curves',
    _InsightDetailFocus.rangeLoss => 'Range Loss',
    _InsightDetailFocus.speedTemperature => 'Speed Temperature',
    _InsightDetailFocus.trackingDrives => 'Tracking Drives',
    _InsightDetailFocus.dataQuality => 'Data Quality',
  };
}

class _CurrentStateDetailCard extends StatelessWidget {
  const _CurrentStateDetailCard({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final vehicle = data.vehicle;
    final drive = data.analytics.currentDrive;
    final charge = data.analytics.currentCharge;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.directions_car_outlined),
            title: const Text('Vehicle state'),
            subtitle: Text('${vehicle.displayName} | ${vehicle.model}'),
            trailing: Text(
              _vehicleStateLabel(vehicle.state),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('Current location'),
            subtitle: Text(vehicle.locationName),
            trailing: Text(
              '${vehicle.latitude.toStringAsFixed(4)}, ${vehicle.longitude.toStringAsFixed(4)}',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: const Text('Power state'),
            subtitle: Text(
              vehicle.pluggedIn
                  ? 'Plugged in | ${vehicle.powerKw.toStringAsFixed(1)} kW'
                  : 'Unplugged | ${vehicle.powerKw.toStringAsFixed(1)} kW',
            ),
            trailing: Text(
              charge.isCharging
                  ? '${charge.minutesRemaining} min'
                  : drive.isDriving
                  ? '${drive.averageSpeedKmh.toStringAsFixed(0)} km/h'
                  : 'Idle',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('Last sample'),
            subtitle: const Text(
              'From TeslaMate PostgreSQL through Reader API',
            ),
            trailing: Text(formatDate(vehicle.lastSeen)),
          ),
        ],
      ),
    );
  }
}

String _vehicleStateLabel(VehicleState state) {
  return switch (state) {
    VehicleState.online => 'Online',
    VehicleState.asleep => 'Asleep',
    VehicleState.charging => 'Charging',
    VehicleState.offline => 'Offline',
  };
}

class _LocationAndUpdatesCard extends StatelessWidget {
  const _LocationAndUpdatesCard({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final vehicle = data.vehicle;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('Location'),
            subtitle: Text(
              '${vehicle.locationName} / ${vehicle.latitude.toStringAsFixed(4)}, ${vehicle.longitude.toStringAsFixed(4)}',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Updates'),
            subtitle: Text(
              'Last sample ${formatDate(vehicle.lastSeen)} | Reader ${data.database.readerApiVersion}',
            ),
            trailing: const Icon(Icons.check_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _ChargeLevelCard extends StatelessWidget {
  const _ChargeLevelCard({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final vehicle = data.vehicle;
    final charge = data.analytics.currentCharge;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.battery_charging_full,
              title: 'Charge level',
              trailing: 'Current',
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${vehicle.batteryLevel}%',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${vehicle.ratedRangeKm.toStringAsFixed(0)} km rated',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: vehicle.batteryLevel / 100,
                minHeight: 12,
                color: const Color(0xFF1B7F79),
                backgroundColor: const Color(0xFFE4E8E4),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${vehicle.usableBatteryLevel}% usable')),
                Chip(
                  label: Text(
                    '${vehicle.idealRangeKm.toStringAsFixed(0)} km ideal',
                  ),
                ),
                if (charge.isCharging) ...[
                  Chip(
                    label: Text('${charge.powerKw.toStringAsFixed(0)} kW now'),
                  ),
                  Chip(label: Text('${charge.minutesRemaining} min left')),
                ] else
                  const Chip(label: Text('Not charging')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectedRangeCard extends StatelessWidget {
  const _ProjectedRangeCard({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final battery = data.analytics.batteryStats;
    final vehicle = data.vehicle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.route_outlined,
              title: 'Projected Range',
              trailing: 'Rated vs ideal',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InlineStat(
                    label: 'Rated',
                    value: '${vehicle.ratedRangeKm.toStringAsFixed(0)} km',
                  ),
                ),
                Expanded(
                  child: _InlineStat(
                    label: 'Ideal',
                    value: '${vehicle.idealRangeKm.toStringAsFixed(0)} km',
                  ),
                ),
                Expanded(
                  child: _InlineStat(
                    label: 'Best',
                    value: '${battery.bestRangeKm.toStringAsFixed(0)} km',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VampireDrainCard extends StatelessWidget {
  const _VampireDrainCard({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final stats = data.monthlyStats;
    final estimatedDrainKwh = stats.onlineHours * 0.08;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.dark_mode_outlined,
              title: 'Vampire Drain',
              trailing: 'Estimate',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InlineStat(
                    label: 'Asleep',
                    value: '${stats.asleepHours.toStringAsFixed(0)} h',
                  ),
                ),
                Expanded(
                  child: _InlineStat(
                    label: 'Online',
                    value: '${stats.onlineHours.toStringAsFixed(0)} h',
                  ),
                ),
                Expanded(
                  child: _InlineStat(
                    label: 'Drain',
                    value: '${estimatedDrainKwh.toStringAsFixed(1)} kWh',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveStatsCard extends StatelessWidget {
  const _DriveStatsCard({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final stats = data.monthlyStats;
    final recentDrives = data.drives;
    final averageSpeed = recentDrives.isEmpty
        ? 0.0
        : recentDrives.fold<double>(
                0,
                (sum, drive) => sum + drive.averageSpeedKmh,
              ) /
              recentDrives.length;
    final maxElevationCurve = recentDrives
        .expand((drive) => drive.elevationCurve)
        .fold<double>(0, (max, point) => math.max(max, point.value));

    return GridView(
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
        ),
        MetricTile(
          icon: Icons.speed,
          label: 'Average speed',
          value: averageSpeed > 0
              ? '${averageSpeed.toStringAsFixed(0)} km/h'
              : 'No data',
          caption: 'Recent completed drives',
          color: const Color(0xFF355C9A),
        ),
        MetricTile(
          icon: Icons.bolt,
          label: 'Energy',
          value: '${stats.energyKwh.toStringAsFixed(1)} kWh',
          caption: '${stats.efficiencyWhPerKm} Wh/km this month',
          color: const Color(0xFFB35C00),
        ),
        MetricTile(
          icon: Icons.terrain,
          label: 'Route samples',
          value: '${recentDrives.length}',
          caption: maxElevationCurve > 0
              ? 'Elevation max ${maxElevationCurve.toStringAsFixed(0)} m'
              : 'Open a drive for curves',
          color: const Color(0xFF56616A),
        ),
      ],
    );
  }
}

class _TripAndTrackingCard extends StatelessWidget {
  const _TripAndTrackingCard({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    if (data.drives.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: _NoDataBody(
            message: 'No drive records have been returned by Reader API yet.',
          ),
        ),
      );
    }

    final longest = data.drives.reduce(
      (a, b) => a.distanceKm >= b.distanceKm ? a : b,
    );

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.alt_route),
            title: const Text('Trip'),
            subtitle: Text(
              '${longest.startLocation} to ${longest.endLocation}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('${longest.distanceKm.toStringAsFixed(0)} km'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.landscape_outlined),
            title: const Text('Tracking Drives'),
            subtitle: const Text('Energy consumed and elevation profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _InsightDetailPage(
                    data: data,
                    module: _InsightModule.byKind(_InsightModuleKind.drives),
                    focus: _InsightDetailFocus.trackingDrives,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrackingDrivesDetailCard extends StatelessWidget {
  const _TrackingDrivesDetailCard({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final drives = data.drives
        .where(
          (drive) =>
              drive.energyKwh > 0 ||
              drive.elevationCurve.isNotEmpty ||
              drive.route.isNotEmpty,
        )
        .take(8)
        .toList();

    if (drives.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: _NoDataBody(
            message: 'No tracking drive samples have been returned yet.',
          ),
        ),
      );
    }

    final totalEnergy = drives.fold<double>(
      0,
      (sum, drive) => sum + drive.energyKwh,
    );
    final maxElevation = drives
        .expand((drive) => drive.elevationCurve)
        .fold<double>(0, (max, point) => math.max(max, point.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(
              icon: Icons.landscape_outlined,
              title: 'Energy consumed and elevation profile',
              trailing: '${drives.length} drives',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CompactDriveMetric(
                    label: 'Energy',
                    value: '${totalEnergy.toStringAsFixed(1)} kWh',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactDriveMetric(
                    label: 'Elevation max',
                    value: maxElevation > 0
                        ? '${maxElevation.toStringAsFixed(0)} m'
                        : 'No data',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...drives.map((drive) => _TrackingDriveRow(drive: drive)),
          ],
        ),
      ),
    );
  }
}

class _CompactDriveMetric extends StatelessWidget {
  const _CompactDriveMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingDriveRow extends StatelessWidget {
  const _TrackingDriveRow({required this.drive});

  final DriveRecord drive;

  @override
  Widget build(BuildContext context) {
    final elevationMax = drive.elevationCurve.fold<double>(
      0,
      (max, point) => math.max(max, point.value),
    );

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.route_outlined),
          title: Text(
            '${drive.startLocation} to ${drive.endLocation}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${drive.distanceKm.toStringAsFixed(1)} km / ${drive.energyKwh.toStringAsFixed(1)} kWh / ${drive.efficiencyWhPerKm} Wh/km',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            elevationMax > 0 ? '${elevationMax.toStringAsFixed(0)} m' : '--',
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _DatabaseInfoCard extends StatelessWidget {
  const _DatabaseInfoCard({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final database = data.database;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: const Text('Cars'),
            trailing: Text('${database.carRows}'),
            subtitle: Text(
              '${data.vehicle.displayName} | ${database.databaseName}',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.route),
            title: const Text('Drive rows'),
            trailing: Text('${database.driveRows}'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.timeline),
            title: const Text('Position rows'),
            trailing: Text('${database.positionRows}'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.ev_station),
            title: const Text('Charge rows'),
            trailing: Text('${database.chargeRows}'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Database size'),
            trailing: Text('${database.databaseSizeMb.toStringAsFixed(1)} MB'),
            subtitle: Text('Schema ${database.schemaVersion}'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('Latest data'),
            trailing: Text(formatDate(database.latestDataAt)),
            subtitle: Text('First seen ${formatDate(database.firstDataAt)}'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Reader API mode'),
            subtitle: Text(
              database.connected
                  ? 'Connected | API ${database.readerApiVersion}'
                  : 'PostgreSQL credentials stay on the backend',
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageHeader extends StatelessWidget {
  const _CoverageHeader({required this.data, this.dataListenable});

  final TeslamateDashboardData data;
  final ValueListenable<TeslamateDashboardData>? dataListenable;

  @override
  Widget build(BuildContext context) {
    final analytics = data.analytics;
    final scheme = Theme.of(context).colorScheme;
    final rangeNow = analytics.batteryStats.ratedRangeNowKm > 0
        ? analytics.batteryStats.ratedRangeNowKm
        : data.vehicle.ratedRangeKm;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17211F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: scheme.primaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TeslaMate insights',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DarkStat(
                  label: 'Range now',
                  value: rangeNow > 0
                      ? '${rangeNow.toStringAsFixed(0)} km'
                      : 'No data',
                ),
              ),
              Expanded(
                child: _DarkStat(
                  label: 'Cost this period',
                  value: formatMoney(analytics.chargingCosts.totalCost),
                ),
              ),
              Expanded(
                child: _DarkStat(
                  label: 'Efficiency',
                  value:
                      '${analytics.chargingCosts.netConsumptionWhPerKm} Wh/km',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _QuickLinksStrip(
            links: _buildQuickLinks(),
            data: data,
            dataListenable: dataListenable,
          ),
        ],
      ),
    );
  }

  List<_InsightQuickLink> _buildQuickLinks() {
    final vehicle = _InsightModule.byKind(_InsightModuleKind.vehicle);
    final charging = _InsightModule.byKind(_InsightModuleKind.charging);
    final battery = _InsightModule.byKind(_InsightModuleKind.battery);
    final efficiency = _InsightModule.byKind(_InsightModuleKind.efficiency);
    final system = _InsightModule.byKind(_InsightModuleKind.system);

    return [
      _InsightQuickLink(
        label: 'Current state',
        icon: Icons.directions_car_outlined,
        module: vehicle,
        focus: _InsightDetailFocus.currentState,
        caption: 'Live status',
      ),
      _InsightQuickLink(
        label: 'Charging cost',
        icon: Icons.payments_outlined,
        module: charging,
        focus: _InsightDetailFocus.chargingCost,
        caption: 'Energy spend',
      ),
      _InsightQuickLink(
        label: 'Curves',
        icon: Icons.show_chart,
        module: charging,
        focus: _InsightDetailFocus.chargingCurves,
        caption: 'Charging power',
      ),
      _InsightQuickLink(
        label: 'Range loss',
        icon: Icons.trending_down,
        module: battery,
        focus: _InsightDetailFocus.rangeLoss,
        caption: 'Battery health',
      ),
      _InsightQuickLink(
        label: 'Speed temp',
        icon: Icons.thermostat,
        module: efficiency,
        focus: _InsightDetailFocus.speedTemperature,
        caption: 'Wh/km heatmap',
      ),
      _InsightQuickLink(
        label: 'Data quality',
        icon: Icons.health_and_safety_outlined,
        module: system,
        focus: _InsightDetailFocus.dataQuality,
        caption: 'Missing rows',
      ),
    ];
  }
}

class _QuickLinksStrip extends StatelessWidget {
  const _QuickLinksStrip({
    required this.links,
    required this.data,
    this.dataListenable,
  });

  final List<_InsightQuickLink> links;
  final TeslamateDashboardData data;
  final ValueListenable<TeslamateDashboardData>? dataListenable;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: links.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _QuickLinkButton(
            link: links[index],
            data: data,
            dataListenable: dataListenable,
          );
        },
      ),
    );
  }
}

class _QuickLinkButton extends StatelessWidget {
  const _QuickLinkButton({
    required this.link,
    required this.data,
    this.dataListenable,
  });

  final _InsightQuickLink link;
  final TeslamateDashboardData data;
  final ValueListenable<TeslamateDashboardData>? dataListenable;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${link.label}',
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _InsightDetailPage(
                  data: data,
                  dataListenable: dataListenable,
                  module: link.module,
                  focus: link.focus,
                ),
              ),
            );
          },
          child: Container(
            width: 152,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(link.icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        link.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  link.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkStat extends StatelessWidget {
  const _DarkStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _LiveTelemetryGrid extends StatelessWidget {
  const _LiveTelemetryGrid({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final vehicle = data.vehicle;
    final drive = data.analytics.currentDrive;
    final charge = data.analytics.currentCharge;

    return GridView(
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
          icon: Icons.battery_charging_full,
          label: 'Battery',
          value: '${vehicle.batteryLevel}%',
          caption: '${vehicle.ratedRangeKm.toStringAsFixed(0)} km rated',
        ),
        MetricTile(
          icon: Icons.speed,
          label: 'Odometer',
          value: '${vehicle.odometerKm.toStringAsFixed(0)} km',
          caption: vehicle.locationName,
          color: const Color(0xFF56616A),
        ),
        MetricTile(
          icon: Icons.thermostat,
          label: 'Cabin climate',
          value: '${vehicle.insideTempC.toStringAsFixed(1)} C',
          caption: '${vehicle.outsideTempC.toStringAsFixed(1)} C outside',
          color: const Color(0xFF8A5A00),
        ),
        MetricTile(
          icon: Icons.update,
          label: 'Last sample',
          value: formatDate(vehicle.lastSeen),
          caption: 'Reader database',
          color: const Color(0xFF355C9A),
        ),
        MetricTile(
          icon: Icons.route,
          label: 'Current drive',
          value: drive.isDriving
              ? '${drive.distanceKm.toStringAsFixed(1)} km'
              : 'Idle',
          caption: drive.isDriving
              ? '${formatDuration(drive.elapsed)} at ${drive.averageSpeedKmh.toStringAsFixed(0)} km/h'
              : 'No active drive',
          color: const Color(0xFF1B7F79),
        ),
        MetricTile(
          icon: Icons.ev_station,
          label: 'Current charge',
          value: charge.isCharging ? '${charge.powerKw} kW' : 'Not charging',
          caption: charge.isCharging
              ? '${charge.voltage} V / ${charge.currentA} A'
              : 'No active session',
          color: const Color(0xFFB35C00),
        ),
      ],
    );
  }
}

class _StateTimelineCard extends StatelessWidget {
  const _StateTimelineCard({required this.segments});

  final List<StateTimelineSegment> segments;

  @override
  Widget build(BuildContext context) {
    final visibleSegments = segments.where((item) => item.hours > 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(
              icon: Icons.timeline,
              title: 'State timeline',
              trailing: 'Last 30 days',
            ),
            const SizedBox(height: 14),
            if (visibleSegments.isEmpty)
              const _NoDataBody(
                message: 'State history has not been returned by Reader API.',
              )
            else ...[
              SizedBox(
                height: 26,
                child: CustomPaint(
                  painter: _TimelinePainter(segments: visibleSegments),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: visibleSegments
                    .map(
                      (item) => _LegendItem(
                        color: _stateColor(item.label),
                        label:
                            '${item.label} ${item.hours.toStringAsFixed(0)} h',
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChargingEconomics extends StatelessWidget {
  const _ChargingEconomics({required this.data});

  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final costs = data.chargingCosts;
    final points = [
      ChartPoint(label: 'AC', value: costs.acCost),
      ChartPoint(label: 'DC', value: costs.dcCost),
      ChartPoint(label: 'SuC', value: costs.superchargerCost),
      ChartPoint(label: 'Free', value: 0),
    ];

    return Column(
      children: [
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
              icon: Icons.bolt,
              label: 'Energy used',
              value: '${costs.totalEnergyUsedKwh.toStringAsFixed(1)} kWh',
              caption: '${costs.freeEnergyKwh.toStringAsFixed(1)} kWh free',
              color: const Color(0xFFB35C00),
            ),
            MetricTile(
              icon: Icons.payments_outlined,
              label: 'Total cost',
              value: formatMoney(costs.totalCost),
              caption: '${formatMoney(costs.costPer100Km)} / 100 km',
              color: const Color(0xFF7A4B11),
            ),
            MetricTile(
              icon: Icons.price_check,
              label: 'Cost per kWh',
              value: formatMoney(costs.costPerKwh),
              caption: 'AC ${formatMoney(costs.acCost)}',
              color: const Color(0xFF355C9A),
            ),
            MetricTile(
              icon: Icons.speed,
              label: 'Gross use',
              value: '${costs.grossConsumptionWhPerKm} Wh/km',
              caption: '${costs.netConsumptionWhPerKm} Wh/km net',
              color: const Color(0xFF56616A),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _BarChartCard(
          title: 'Charging cost split',
          points: points,
          color: const Color(0xFFB35C00),
          valuePrefix: r'$',
        ),
      ],
    );
  }
}

class _TopStationsCard extends StatelessWidget {
  const _TopStationsCard({required this.stations});

  final List<StationStat> stations;

  @override
  Widget build(BuildContext context) {
    final visibleStations = stations
        .where((station) => station.energyKwh > 0 || station.sessions > 0)
        .toList();
    final maxEnergy = visibleStations.fold<double>(
      1,
      (max, item) => math.max(max, item.energyKwh),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.ev_station_outlined,
              title: 'Top charging stations',
              trailing: 'Energy',
            ),
            const SizedBox(height: 12),
            if (visibleStations.isEmpty)
              const _NoDataBody(
                message:
                    'No charging station summary has been returned by Reader API.',
              )
            else
              ...visibleStations.map(
                (station) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StationRow(station: station, maxEnergy: maxEnergy),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({required this.station, required this.maxEnergy});

  final StationStat station;
  final double maxEnergy;

  @override
  Widget build(BuildContext context) {
    final fraction = station.energyKwh / maxEnergy;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                station.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${station.energyKwh.toStringAsFixed(1)} kWh',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.05, 1),
            minHeight: 8,
            color: _stationColor(station.kind),
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${station.kind} / ${station.sessions} sessions / ${formatMoney(station.cost)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ChargingCurveCard extends StatelessWidget {
  const _ChargingCurveCard({required this.curves});

  final List<ChargingCurve> curves;

  @override
  Widget build(BuildContext context) {
    final drawableCurves = curves
        .where(
          (curve) => curve.points.where((point) => point.value > 0).length >= 2,
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.show_chart,
              title: 'Charging power by battery level',
              trailing: 'kW',
            ),
            const SizedBox(height: 12),
            if (drawableCurves.isEmpty)
              const _NoDataBody(
                message:
                    'No charging curve samples have been returned by Reader API.',
              )
            else ...[
              SizedBox(
                height: 190,
                child: CustomPaint(
                  painter: _MultiLinePainter(
                    series: drawableCurves
                        .map(
                          (curve) => _ChartSeries(
                            name: curve.label,
                            color: Color(curve.colorHex),
                            points: curve.points,
                          ),
                        )
                        .toList(),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: drawableCurves
                    .map(
                      (curve) => _LegendItem(
                        color: Color(curve.colorHex),
                        label: curve.label,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BatteryRangeSection extends StatelessWidget {
  const _BatteryRangeSection({required this.data});

  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final battery = data.batteryStats;
    final hasCapacity = battery.estimatedCapacityKwh > 0;
    final hasDegradation =
        battery.ratedRangeStartKm > 0 && battery.ratedRangeNowKm > 0;

    return Column(
      children: [
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
              icon: Icons.battery_5_bar,
              label: 'Capacity',
              value: hasCapacity
                  ? '${battery.estimatedCapacityKwh.toStringAsFixed(1)} kWh'
                  : 'No data',
              caption: battery.nominalFullPackKwh > 0
                  ? '${battery.nominalFullPackKwh.toStringAsFixed(1)} kWh nominal'
                  : 'Needs battery range samples',
              color: const Color(0xFF1B7F79),
            ),
            MetricTile(
              icon: Icons.trending_down,
              label: 'Degradation',
              value: hasDegradation
                  ? '${battery.degradationPercent.toStringAsFixed(1)}%'
                  : 'No data',
              caption: hasDegradation
                  ? '${battery.ratedRangeStartKm.toStringAsFixed(0)} to ${battery.ratedRangeNowKm.toStringAsFixed(0)} km'
                  : 'Needs charge session history',
              color: const Color(0xFF8A3A3A),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _LineChartCard(
          title: 'Range degradation',
          points: data.rangeDegradation,
          color: const Color(0xFF8A3A3A),
          valueSuffix: ' km',
          emptyMessage: hasCapacity || hasDegradation
              ? 'Analytics chart data is still loading. Pull latest data or retry Reader API refresh.'
              : 'No range degradation samples have been returned by Reader API.',
        ),
      ],
    );
  }
}

class _SpeedRatesCard extends StatelessWidget {
  const _SpeedRatesCard({required this.buckets});

  final List<SpeedRateBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final visibleBuckets = buckets
        .where((bucket) => bucket.netWhPerKm > 0 || bucket.grossWhPerKm > 0)
        .toList();

    if (visibleBuckets.length < 2) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(
                icon: Icons.speed,
                title: 'Consumption by speed',
                trailing: 'Wh/km',
              ),
              SizedBox(height: 12),
              _NoDataBody(
                message:
                    'No speed efficiency buckets have been returned by Reader API.',
              ),
            ],
          ),
        ),
      );
    }

    final net = visibleBuckets
        .map(
          (bucket) => ChartPoint(
            label: '${bucket.speedKmh}',
            value: bucket.netWhPerKm.toDouble(),
          ),
        )
        .toList();
    final gross = visibleBuckets
        .map(
          (bucket) => ChartPoint(
            label: '${bucket.speedKmh}',
            value: bucket.grossWhPerKm.toDouble(),
          ),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.speed,
              title: 'Consumption by speed',
              trailing: 'Wh/km',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: CustomPaint(
                painter: _MultiLinePainter(
                  series: [
                    _ChartSeries(
                      name: 'Net',
                      color: const Color(0xFF1B7F79),
                      points: net,
                    ),
                    _ChartSeries(
                      name: 'Gross',
                      color: const Color(0xFFB35C00),
                      points: gross,
                    ),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _LegendItem(color: Color(0xFF1B7F79), label: 'Net'),
                _LegendItem(color: Color(0xFFB35C00), label: 'Gross'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TemperatureHeatmap extends StatelessWidget {
  const _TemperatureHeatmap({required this.points});

  final List<TemperatureEfficiencyPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(
                icon: Icons.grid_view,
                title: 'Speed and temperature',
                trailing: 'Wh/km',
              ),
              SizedBox(height: 12),
              _NoDataBody(
                message:
                    'No temperature efficiency samples have been returned by Reader API.',
              ),
            ],
          ),
        ),
      );
    }

    final speeds = points.map((p) => p.speedKmh).toSet().toList()..sort();
    final temps = points.map((p) => p.temperatureC).toSet().toList()..sort();
    final values = points.map((p) => p.whPerKm);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = math.max(1, maxValue - minValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.grid_view,
              title: 'Speed and temperature',
              trailing: 'Wh/km',
            ),
            const SizedBox(height: 12),
            ...temps.map(
              (temp) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        '$temp C',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    ...speeds.map((speed) {
                      final point = points.firstWhere(
                        (p) => p.speedKmh == speed && p.temperatureC == temp,
                        orElse: () => TemperatureEfficiencyPoint(
                          speedKmh: speed,
                          temperatureC: temp,
                          whPerKm: minValue,
                        ),
                      );
                      final normalized = (point.whPerKm - minValue) / span;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _HeatCell(
                            value: point.whPerKm,
                            strength: normalized,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 42),
                ...speeds.map(
                  (speed) => Expanded(
                    child: Center(
                      child: Text(
                        '$speed',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.value, required this.strength});

  final int value;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      const Color(0xFFE4F2EC),
      const Color(0xFFB35C00),
      strength,
    )!;

    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: strength > 0.58 ? Colors.white : const Color(0xFF17211F),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DataQualityCard extends StatelessWidget {
  const _DataQualityCard({required this.summary});

  final DataQualitySummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _QualityTile(
            icon: Icons.route_outlined,
            label: 'Incomplete drives',
            value: '${summary.incompleteDrives}',
          ),
          const Divider(height: 1),
          _QualityTile(
            icon: Icons.battery_alert_outlined,
            label: 'Incomplete charges',
            value: '${summary.incompleteCharges}',
          ),
          const Divider(height: 1),
          _QualityTile(
            icon: Icons.location_off_outlined,
            label: 'Missing positions',
            value: '${summary.missingPositions}',
          ),
          const Divider(height: 1),
          _QualityTile(
            icon: Icons.health_and_safety_outlined,
            label: 'Last healthy sample',
            value: formatDate(summary.lastHealthyAt),
          ),
        ],
      ),
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _AmortizationCard extends StatelessWidget {
  const _AmortizationCard({required this.summary});

  final AmortizationSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.savings_outlined,
              title: 'Break-even tracker',
              trailing: 'Estimate',
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: summary.breakEvenPercent / 100,
                minHeight: 12,
                color: const Color(0xFF1B7F79),
                backgroundColor: const Color(0xFFE4E8E4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InlineStat(
                    label: 'Progress',
                    value: '${summary.breakEvenPercent.toStringAsFixed(0)}%',
                  ),
                ),
                Expanded(
                  child: _InlineStat(
                    label: 'Savings',
                    value: formatMoney(summary.savingsToDate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InlineStat(
                    label: 'Purchase',
                    value: formatMoney(summary.purchasePrice),
                  ),
                ),
                Expanded(
                  child: _InlineStat(
                    label: 'Value',
                    value: formatMoney(summary.currentValue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.title,
    required this.points,
    required this.color,
    this.valuePrefix = '',
    this.valueSuffix = '',
  });

  final String title;
  final List<ChartPoint> points;
  final Color color;
  final String valuePrefix;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final hasBars = points.any((point) => point.value > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(icon: Icons.bar_chart, title: title, trailing: ''),
            const SizedBox(height: 12),
            if (!hasBars)
              const _NoDataBody(
                message: 'No chart values have been returned by Reader API.',
              )
            else ...[
              SizedBox(
                height: 170,
                child: CustomPaint(
                  painter: _BarChartPainter(points: points, color: color),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: points
                    .map(
                      (point) => Chip(
                        label: Text(
                          '${point.label} $valuePrefix${point.value.toStringAsFixed(point.value >= 100 ? 0 : 1)}$valueSuffix',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.title,
    required this.points,
    required this.color,
    this.valueSuffix = '',
    this.emptyMessage =
        'No line chart samples have been returned by Reader API.',
  });

  final String title;
  final List<ChartPoint> points;
  final Color color;
  final String valueSuffix;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final hasLine =
        points.length >= 2 && points.any((point) => point.value > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(icon: Icons.show_chart, title: title, trailing: ''),
            const SizedBox(height: 12),
            if (!hasLine)
              _NoDataBody(message: emptyMessage)
            else ...[
              SizedBox(
                height: 180,
                child: CustomPaint(
                  painter: _LineChartPainter(points: points, color: color),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      points.first.label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Text(
                    '${points.last.value.toStringAsFixed(0)}$valueSuffix',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoDataBody extends StatelessWidget {
  const _NoDataBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 24),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing.isNotEmpty)
          Text(trailing, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _ChartSeries {
  const _ChartSeries({
    required this.name,
    required this.color,
    required this.points,
  });

  final String name;
  final Color color;
  final List<ChartPoint> points;
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({required this.segments});

  final List<StateTimelineSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (sum, item) => sum + item.hours);
    if (total <= 0) {
      return;
    }

    var x = 0.0;
    for (final segment in segments) {
      final width = size.width * (segment.hours / total);
      final paint = Paint()..color = _stateColor(segment.label);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, width, size.height),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, paint);
      x += width;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.points, required this.color});

  final List<ChartPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    final maxValue = points.map((p) => p.value).reduce(math.max);
    if (maxValue <= 0) {
      return;
    }

    final barWidth = size.width / (points.length * 1.8);
    final spacing =
        (size.width - (barWidth * points.length)) /
        math.max(1, points.length - 1);
    final labelPaint = _textPainterStyle(const Color(0xFF56616A), 10);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final left = i * (barWidth + spacing);
      final height = size.height * 0.78 * (point.value / maxValue);
      final top = size.height * 0.78 - height;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, height),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      _drawText(
        canvas,
        point.label,
        Offset(left, size.height - 18),
        labelPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.points, required this.color});

  final List<ChartPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSingleLine(canvas, size, points, color);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _MultiLinePainter extends CustomPainter {
  const _MultiLinePainter({required this.series});

  final List<_ChartSeries> series;

  @override
  void paint(Canvas canvas, Size size) {
    final drawableSeries = series
        .where((item) => item.points.length >= 2)
        .toList();
    if (drawableSeries.isEmpty) {
      return;
    }

    final allPoints = drawableSeries.expand((item) => item.points).toList();
    if (allPoints.isEmpty) {
      return;
    }

    final minValue = allPoints.map((p) => p.value).reduce(math.min);
    final maxValue = allPoints.map((p) => p.value).reduce(math.max);
    final chartRect = Rect.fromLTWH(0, 8, size.width, size.height - 30);
    _drawGrid(canvas, chartRect);

    for (final item in drawableSeries) {
      _drawLineInRect(
        canvas,
        chartRect,
        item.points,
        item.color,
        minValue,
        maxValue,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLinePainter oldDelegate) {
    return oldDelegate.series != series;
  }
}

void _drawSingleLine(
  Canvas canvas,
  Size size,
  List<ChartPoint> points,
  Color color,
) {
  if (points.length < 2) {
    return;
  }

  final minValue = points.map((p) => p.value).reduce(math.min);
  final maxValue = points.map((p) => p.value).reduce(math.max);
  final chartRect = Rect.fromLTWH(0, 8, size.width, size.height - 30);
  _drawGrid(canvas, chartRect);
  _drawLineInRect(canvas, chartRect, points, color, minValue, maxValue);

  final labelPaint = _textPainterStyle(const Color(0xFF56616A), 10);
  _drawText(
    canvas,
    points.first.label,
    Offset(chartRect.left, chartRect.bottom + 8),
    labelPaint,
  );
  _drawText(
    canvas,
    points.last.label,
    Offset(chartRect.right - 28, chartRect.bottom + 8),
    labelPaint,
  );
}

void _drawLineInRect(
  Canvas canvas,
  Rect rect,
  List<ChartPoint> points,
  Color color,
  double minValue,
  double maxValue,
) {
  if (points.length < 2) {
    return;
  }

  final span = math.max(1, maxValue - minValue);
  final path = Path();
  final fillPath = Path();

  for (var i = 0; i < points.length; i++) {
    final x = rect.left + rect.width * (i / (points.length - 1));
    final y = rect.bottom - rect.height * ((points[i].value - minValue) / span);
    if (i == 0) {
      path.moveTo(x, y);
      fillPath.moveTo(x, rect.bottom);
      fillPath.lineTo(x, y);
    } else {
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }
  }

  fillPath.lineTo(rect.right, rect.bottom);
  fillPath.close();
  canvas.drawPath(fillPath, Paint()..color = color.withValues(alpha: 0.10));
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  for (var i = 0; i < points.length; i++) {
    final x = rect.left + rect.width * (i / (points.length - 1));
    final y = rect.bottom - rect.height * ((points[i].value - minValue) / span);
    canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
  }
}

void _drawGrid(Canvas canvas, Rect rect) {
  final gridPaint = Paint()
    ..color = const Color(0xFFE3E8E3)
    ..strokeWidth = 1;

  for (var i = 0; i < 4; i++) {
    final y = rect.top + rect.height * (i / 3);
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
  }
}

TextStyle _textPainterStyle(Color color, double size) {
  return TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700);
}

void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: 64);
  painter.paint(canvas, offset);
}

Color _stateColor(String label) {
  return switch (label) {
    'Asleep' => const Color(0xFF56616A),
    'Online' => const Color(0xFF1B7F79),
    'Driving' => const Color(0xFF355C9A),
    'Charging' => const Color(0xFFB35C00),
    _ => const Color(0xFF6B6E23),
  };
}

Color _stationColor(String kind) {
  return switch (kind) {
    'AC' => const Color(0xFF1B7F79),
    'Supercharger' => const Color(0xFFB35C00),
    'Free' => const Color(0xFF355C9A),
    _ => const Color(0xFF56616A),
  };
}
