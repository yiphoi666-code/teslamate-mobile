import 'package:flutter/material.dart';

import '../models/teslamate_models.dart';

class VehicleStateChip extends StatelessWidget {
  const VehicleStateChip({required this.state, super.key});

  final VehicleState state;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (state) {
      VehicleState.online => (
        'Online',
        Icons.wifi_tethering,
        const Color(0xFF1B7F79),
      ),
      VehicleState.asleep => (
        'Asleep',
        Icons.bedtime_outlined,
        const Color(0xFF687076),
      ),
      VehicleState.charging => (
        'Charging',
        Icons.bolt,
        const Color(0xFFB35C00),
      ),
      VehicleState.offline => (
        'Offline',
        Icons.cloud_off_outlined,
        const Color(0xFF9B2C2C),
      ),
    };

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.10),
    );
  }
}
