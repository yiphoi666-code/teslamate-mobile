import 'package:flutter/material.dart';

import '../data/reader_api_client.dart';
import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';
import '../widgets/mini_charts.dart';

class ChargeDetailScreen extends StatefulWidget {
  const ChargeDetailScreen({
    required this.carId,
    required this.charge,
    required this.readerApiConfig,
    required this.usingRemoteData,
    super.key,
  });

  final int carId;
  final ChargeSession charge;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;

  @override
  State<ChargeDetailScreen> createState() => _ChargeDetailScreenState();
}

class _ChargeDetailScreenState extends State<ChargeDetailScreen> {
  late final Future<ChargeSession>? _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture =
        widget.usingRemoteData && widget.readerApiConfig.isConfigured
        ? ReaderApiClient(
            config: widget.readerApiConfig,
          ).loadChargeDetail(carId: widget.carId, chargeId: widget.charge.id)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charge detail')),
      body: FutureBuilder<ChargeSession>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final charge = snapshot.data ?? widget.charge;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const _DetailNotice(
                  icon: Icons.sync,
                  text: 'Loading charging curves from Reader API...',
                ),
              if (snapshot.hasError)
                _DetailNotice(
                  icon: Icons.error_outline,
                  text: 'Could not load charging curves: ${snapshot.error}',
                ),
              _ChargeHero(charge: charge),
              const SizedBox(height: 12),
              MiniLineChart(
                title: 'Charging power',
                points: charge.chargeCurve,
                color: const Color(0xFFB35C00),
                unit: 'kW',
              ),
              const SizedBox(height: 12),
              MiniLineChart(
                title: 'Battery level',
                points: charge.batteryCurve,
                color: const Color(0xFF1B7F79),
                unit: '%',
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

class _ChargeHero extends StatelessWidget {
  const _ChargeHero({required this.charge});

  final ChargeSession charge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addedPercent = charge.endBatteryLevel - charge.startBatteryLevel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.ev_station, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    charge.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text('#${charge.id}', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${formatDate(charge.startedAt)} | '
              '${formatDuration(charge.duration)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('${charge.startBatteryLevel}%'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: charge.endBatteryLevel / 100,
                        minHeight: 10,
                        color: const Color(0xFFB35C00),
                        backgroundColor: const Color(0xFFE8DED0),
                      ),
                    ),
                  ),
                ),
                Text('${charge.endBatteryLevel}%'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FactChip(label: '+$addedPercent%'),
                _FactChip(label: '${charge.addedKwh.toStringAsFixed(1)} kWh'),
                _FactChip(
                  label: charge.rangeAddedKm > 0
                      ? '+${charge.rangeAddedKm.toStringAsFixed(0)} km'
                      : 'Range no data',
                ),
                _FactChip(
                  label: charge.maxPowerKw > 0
                      ? '${charge.maxPowerKw.toStringAsFixed(0)} kW peak'
                      : 'Power no data',
                ),
                if (charge.voltage > 0) _FactChip(label: '${charge.voltage} V'),
                if (charge.currentA > 0)
                  _FactChip(label: '${charge.currentA} A'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Cost ${formatMoney(charge.cost)}',
              style: theme.textTheme.titleMedium,
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
