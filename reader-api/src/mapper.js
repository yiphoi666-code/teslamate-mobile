function numberFrom(row, keys, fallback = 0) {
  for (const key of keys) {
    const value = row?.[key];
    if (value !== null && value !== undefined && value !== '') {
      const parsed = Number(value);
      if (!Number.isNaN(parsed)) {
        return parsed;
      }
    }
  }
  return fallback;
}

function stringFrom(row, keys, fallback = '') {
  for (const key of keys) {
    const value = row?.[key];
    if (value !== null && value !== undefined && value !== '') {
      return String(value);
    }
  }
  return fallback;
}

function dateFrom(row, keys) {
  for (const key of keys) {
    const value = row?.[key];
    if (value) {
      return new Date(value).toISOString();
    }
  }
  return new Date(0).toISOString();
}

function durationMinutes(start, end, fallback = 0) {
  if (!start || !end) {
    return Math.round(fallback);
  }
  return Math.max(0, Math.round((new Date(end) - new Date(start)) / 60000));
}

function routePoint(latitude, longitude, label) {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }
  return { latitude, longitude, label };
}

function positiveNumberFrom(row, keys, fallback = 0) {
  for (const key of keys) {
    const value = numberFrom(row, [key]);
    if (value > 0) {
      return value;
    }
  }
  return fallback;
}

function carEfficiencyKwhPerKm(row) {
  const efficiency = numberFrom(row, ['car_efficiency', 'efficiency']);
  if (efficiency <= 0) {
    return 0;
  }

  return efficiency > 5 ? efficiency / 1000 : efficiency;
}

function mapDrive(row, tracking = []) {
  const startedAt = dateFrom(row, ['start_date', 'started_at']);
  const endedAt = dateFrom(row, ['end_date', 'ended_at']);
  const distanceKm = numberFrom(row, ['distance', 'distance_km']);
  const rawEnergyKwh = numberFrom(row, [
    'consumption_kWh',
    'consumption_kwh',
    'energy_kwh',
  ]);
  const rangeDiffKm = positiveNumberFrom(row, [
    'preferred_range_diff_km',
    'rated_range_diff_km',
    'ideal_range_diff_km',
    'range_diff_km',
  ]);
  const computedEnergyKwh = rangeDiffKm * carEfficiencyKwhPerKm(row);
  const energyKwh = rawEnergyKwh > 0 ? rawEnergyKwh : computedEnergyKwh;
  const duration = durationMinutes(
    startedAt,
    endedAt,
    numberFrom(row, ['duration_min', 'duration_minutes'])
  );
  const efficiency = distanceKm > 0 ? Math.round((energyKwh * 1000) / distanceKm) : 0;
  const startLatitude = numberFrom(row, ['start_latitude']);
  const startLongitude = numberFrom(row, ['start_longitude']);
  const endLatitude = numberFrom(row, ['end_latitude']);
  const endLongitude = numberFrom(row, ['end_longitude']);
  const route = tracking.length
    ? tracking
    : [
        routePoint(startLatitude, startLongitude, 'Start'),
        routePoint(endLatitude, endLongitude, 'End'),
      ].filter(Boolean);

  return {
    id: Number(row.id),
    startedAt,
    durationMinutes: duration,
    startLocation: stringFrom(row, ['start_address', 'start_geofence_name'], 'Start'),
    endLocation: stringFrom(row, ['end_address', 'end_geofence_name'], 'End'),
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
    distanceKm,
    energyKwh,
    efficiencyWhPerKm: efficiency,
    maxSpeedKmh: Math.round(numberFrom(row, ['speed_max', 'max_speed'])),
    averageSpeedKmh: duration > 0 ? distanceKm / (duration / 60) : 0,
    startBatteryLevel: Math.round(numberFrom(row, ['start_battery_level'])),
    endBatteryLevel: Math.round(numberFrom(row, ['end_battery_level'])),
    route,
    speedCurve: tracking.map((point, index) => ({
      label: chartLabel(point.label, index),
      value: point.speedKmh || 0,
    })),
    elevationCurve: tracking.map((point, index) => ({
      label: chartLabel(point.label, index),
      value: point.elevationM || 0,
    })),
    batteryCurve: tracking.map((point, index) => ({
      label: chartLabel(point.label, index),
      value: point.batteryLevel || 0,
    })),
  };
}

function chartLabel(label, index) {
  if (!label) {
    return `${index + 1}`;
  }

  const date = new Date(label);
  if (Number.isNaN(date.getTime())) {
    return `${index + 1}`;
  }

  return date.toISOString().slice(11, 16);
}

function mapCharge(row, samples = []) {
  const startedAt = dateFrom(row, ['start_date', 'started_at']);
  const endedAt = dateFrom(row, ['end_date', 'ended_at']);
  const startBattery = Math.round(
    numberFrom(row, ['start_battery_level', 'battery_level_start'])
  );
  const endBattery = Math.round(
    numberFrom(row, ['end_battery_level', 'battery_level_end'], startBattery)
  );

  return {
    id: Number(row.id),
    startedAt,
    durationMinutes: durationMinutes(
      startedAt,
      endedAt,
      numberFrom(row, ['duration_min', 'duration_minutes'])
    ),
    location: stringFrom(row, ['geofence_name', 'location'], 'Charging'),
    startBatteryLevel: startBattery,
    endBatteryLevel: endBattery,
    addedKwh: numberFrom(row, ['charge_energy_added', 'added_kwh']),
    rangeAddedKm: numberFrom(row, [
      'range_added',
      'rated_range_added',
      'ideal_range_added',
    ]),
    cost: numberFrom(row, ['cost', 'charge_cost']),
    maxPowerKw: numberFrom(row, ['max_power_kw', 'charger_power_max']),
    voltage: Math.round(numberFrom(row, ['voltage', 'charger_voltage'])),
    currentA: Math.round(numberFrom(row, ['current_a', 'charger_actual_current'])),
    chargeCurve: samples.map((sample) => ({
      label: `${Math.round(numberFrom(sample, ['battery_level']))}%`,
      value: numberFrom(sample, ['charger_power']),
    })),
    batteryCurve: samples.map((sample, index) => ({
      label: `${index + 1}`,
      value: numberFrom(sample, ['battery_level']),
    })),
  };
}

module.exports = {
  mapDrive,
  mapCharge,
  numberFrom,
  stringFrom,
  dateFrom,
};
