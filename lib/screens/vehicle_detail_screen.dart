import 'package:flutter/material.dart';

import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';
import '../widgets/status_chip.dart';

class VehicleDetailScreen extends StatelessWidget {
  const VehicleDetailScreen({required this.data, super.key});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final vehicle = data.vehicle;

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle detail')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vehicle.displayName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      VehicleStateChip(state: vehicle.state),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(vehicle.model),
                  const SizedBox(height: 18),
                  Text(
                    '${vehicle.batteryLevel}%',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: vehicle.batteryLevel / 100,
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _VehicleFact(
                  icon: Icons.route,
                  label: 'Rated range',
                  value: '${vehicle.ratedRangeKm.toStringAsFixed(0)} km',
                ),
                const Divider(height: 1),
                _VehicleFact(
                  icon: Icons.battery_charging_full,
                  label: 'Ideal range',
                  value: '${vehicle.idealRangeKm.toStringAsFixed(0)} km',
                ),
                const Divider(height: 1),
                _VehicleFact(
                  icon: Icons.speed,
                  label: 'Odometer',
                  value: '${vehicle.odometerKm.toStringAsFixed(0)} km',
                ),
                const Divider(height: 1),
                _VehicleFact(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: vehicle.locationName,
                ),
                const Divider(height: 1),
                _VehicleFact(
                  icon: Icons.thermostat,
                  label: 'Temperature',
                  value:
                      '${vehicle.outsideTempC.toStringAsFixed(1)} C outside | '
                      '${vehicle.insideTempC.toStringAsFixed(1)} C inside',
                ),
                const Divider(height: 1),
                _VehicleFact(
                  icon: Icons.update,
                  label: 'Last seen',
                  value: formatDate(vehicle.lastSeen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Reader data freshness'),
                  subtitle: Text(
                    'Latest database sample ${formatDate(data.database.latestDataAt)}',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Data source'),
                  subtitle: Text(
                    data.database.connected
                        ? 'Reader API ${data.database.readerApiVersion}'
                        : 'Mock data preview',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleFact extends StatelessWidget {
  const _VehicleFact({
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
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
