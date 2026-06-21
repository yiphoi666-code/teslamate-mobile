import 'package:flutter/material.dart';

import '../data/reader_api_client.dart';
import '../models/teslamate_models.dart';
import '../widgets/formatters.dart';
import 'charge_detail_screen.dart';

class ChargesScreen extends StatelessWidget {
  const ChargesScreen({
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
        _ChargingHeader(data: data),
        const SizedBox(height: 16),
        Text(
          'Charging sessions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        ...data.charges.map(
          (charge) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChargeCard(
              data: data,
              charge: charge,
              readerApiConfig: readerApiConfig,
              usingRemoteData: usingRemoteData,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChargingHeader extends StatelessWidget {
  const _ChargingHeader({required this.data});

  final TeslamateDashboardData data;

  @override
  Widget build(BuildContext context) {
    final stats = data.monthlyStats;
    final now = DateTime.now();
    final visibleMonthlyCharges = data.charges.where((charge) {
      return charge.startedAt.year == now.year &&
          charge.startedAt.month == now.month;
    }).toList();
    final visibleChargeCount = stats.chargeCount > 0
        ? stats.chargeCount
        : visibleMonthlyCharges.length;
    final visibleChargeEnergy = stats.chargeEnergyKwh > 0
        ? stats.chargeEnergyKwh
        : visibleMonthlyCharges.fold<double>(
            0,
            (sum, charge) => sum + charge.addedKwh,
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEAC797)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 36, color: Color(0xFFB35C00)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$visibleChargeCount charges this month',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatMoney(stats.chargingCost)} total | ${visibleChargeEnergy.toStringAsFixed(1)} kWh charged',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeCard extends StatelessWidget {
  const _ChargeCard({
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
    final percentDelta = charge.endBatteryLevel - charge.startBatteryLevel;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.ev_station, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      charge.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(formatMoney(charge.cost)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${formatDate(charge.startedAt)} | ${formatDuration(charge.duration)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
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
                          minHeight: 8,
                          color: const Color(0xFFB35C00),
                          backgroundColor: const Color(0xFFE8DED0),
                        ),
                      ),
                    ),
                  ),
                  Text('${charge.endBatteryLevel}%'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChargeFact(label: '+$percentDelta%'),
                  _ChargeFact(
                    label: '${charge.addedKwh.toStringAsFixed(1)} kWh',
                  ),
                  _ChargeFact(
                    label: charge.rangeAddedKm > 0
                        ? '+${charge.rangeAddedKm.toStringAsFixed(0)} km'
                        : 'Range no data',
                  ),
                  _ChargeFact(
                    label: charge.maxPowerKw > 0
                        ? '${charge.maxPowerKw.toStringAsFixed(0)} kW peak'
                        : 'Power no data',
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

class _ChargeFact extends StatelessWidget {
  const _ChargeFact({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}
