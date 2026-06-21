enum VehicleState { online, asleep, charging, offline }

class TeslamateDashboardData {
  const TeslamateDashboardData({
    required this.carId,
    required this.vehicle,
    required this.monthlyStats,
    required this.drives,
    required this.charges,
    required this.locations,
    required this.database,
    required this.analytics,
  });

  final int carId;
  final VehicleSnapshot vehicle;
  final MonthlyStats monthlyStats;
  final List<DriveRecord> drives;
  final List<ChargeSession> charges;
  final List<LocationVisit> locations;
  final DatabaseInfo database;
  final AnalyticsData analytics;

  TeslamateDashboardData copyWith({
    int? carId,
    VehicleSnapshot? vehicle,
    MonthlyStats? monthlyStats,
    List<DriveRecord>? drives,
    List<ChargeSession>? charges,
    List<LocationVisit>? locations,
    DatabaseInfo? database,
    AnalyticsData? analytics,
  }) {
    return TeslamateDashboardData(
      carId: carId ?? this.carId,
      vehicle: vehicle ?? this.vehicle,
      monthlyStats: monthlyStats ?? this.monthlyStats,
      drives: drives ?? this.drives,
      charges: charges ?? this.charges,
      locations: locations ?? this.locations,
      database: database ?? this.database,
      analytics: analytics ?? this.analytics,
    );
  }
}

class VehicleSnapshot {
  const VehicleSnapshot({
    required this.displayName,
    required this.model,
    required this.state,
    required this.batteryLevel,
    required this.usableBatteryLevel,
    required this.ratedRangeKm,
    required this.idealRangeKm,
    required this.odometerKm,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.lastSeen,
    required this.outsideTempC,
    required this.insideTempC,
    required this.powerKw,
    required this.pluggedIn,
  });

  final String displayName;
  final String model;
  final VehicleState state;
  final int batteryLevel;
  final int usableBatteryLevel;
  final double ratedRangeKm;
  final double idealRangeKm;
  final double odometerKm;
  final String locationName;
  final double latitude;
  final double longitude;
  final DateTime lastSeen;
  final double outsideTempC;
  final double insideTempC;
  final double powerKw;
  final bool pluggedIn;
}

class MonthlyStats {
  const MonthlyStats({
    required this.distanceKm,
    required this.driveCount,
    required this.energyKwh,
    required this.chargeEnergyKwh,
    required this.efficiencyWhPerKm,
    required this.chargeCount,
    required this.chargingCost,
    required this.onlineHours,
    required this.asleepHours,
  });

  final double distanceKm;
  final int driveCount;
  final double energyKwh;
  final double chargeEnergyKwh;
  final int efficiencyWhPerKm;
  final int chargeCount;
  final double chargingCost;
  final double onlineHours;
  final double asleepHours;
}

class DriveRecord {
  const DriveRecord({
    required this.id,
    required this.startedAt,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.distanceKm,
    required this.energyKwh,
    required this.efficiencyWhPerKm,
    required this.maxSpeedKmh,
    required this.averageSpeedKmh,
    required this.startBatteryLevel,
    required this.endBatteryLevel,
    required this.route,
    required this.speedCurve,
    required this.elevationCurve,
    required this.batteryCurve,
  });

  final int id;
  final DateTime startedAt;
  final Duration duration;
  final String startLocation;
  final String endLocation;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final double distanceKm;
  final double energyKwh;
  final int efficiencyWhPerKm;
  final int maxSpeedKmh;
  final double averageSpeedKmh;
  final int startBatteryLevel;
  final int endBatteryLevel;
  final List<RoutePoint> route;
  final List<ChartPoint> speedCurve;
  final List<ChartPoint> elevationCurve;
  final List<ChartPoint> batteryCurve;
}

class ChargeSession {
  const ChargeSession({
    required this.id,
    required this.startedAt,
    required this.duration,
    required this.location,
    required this.startBatteryLevel,
    required this.endBatteryLevel,
    required this.addedKwh,
    required this.rangeAddedKm,
    required this.cost,
    required this.maxPowerKw,
    required this.voltage,
    required this.currentA,
    required this.chargeCurve,
    required this.batteryCurve,
  });

  final int id;
  final DateTime startedAt;
  final Duration duration;
  final String location;
  final int startBatteryLevel;
  final int endBatteryLevel;
  final double addedKwh;
  final double rangeAddedKm;
  final double cost;
  final double maxPowerKw;
  final int voltage;
  final int currentA;
  final List<ChartPoint> chargeCurve;
  final List<ChartPoint> batteryCurve;
}

class LocationVisit {
  const LocationVisit({
    required this.name,
    required this.address,
    required this.kind,
    required this.visitCount,
    required this.lastVisitedAt,
    required this.distanceFromHomeKm,
  });

  final String name;
  final String address;
  final String kind;
  final int visitCount;
  final DateTime lastVisitedAt;
  final double distanceFromHomeKm;
}

class DatabaseInfo {
  const DatabaseInfo({
    required this.connected,
    required this.databaseName,
    required this.schemaVersion,
    required this.databaseSizeMb,
    required this.carRows,
    required this.driveRows,
    required this.positionRows,
    required this.chargeRows,
    required this.chargingProcessRows,
    required this.stateRows,
    required this.geofenceRows,
    required this.firstDataAt,
    required this.latestDataAt,
    required this.readerApiVersion,
  });

  final bool connected;
  final String databaseName;
  final String schemaVersion;
  final double databaseSizeMb;
  final int carRows;
  final int driveRows;
  final int positionRows;
  final int chargeRows;
  final int chargingProcessRows;
  final int stateRows;
  final int geofenceRows;
  final DateTime firstDataAt;
  final DateTime latestDataAt;
  final String readerApiVersion;
}

class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}

class AnalyticsData {
  const AnalyticsData({
    required this.currentDrive,
    required this.currentCharge,
    required this.chargingCosts,
    required this.batteryStats,
    required this.dataQuality,
    required this.amortization,
    required this.stateTimeline,
    required this.monthlyMileage,
    required this.rangeDegradation,
    required this.chargingCurves,
    required this.speedRates,
    required this.speedTemperature,
    required this.topStations,
  });

  final CurrentDriveSnapshot currentDrive;
  final CurrentChargeSnapshot currentCharge;
  final ChargingCostSummary chargingCosts;
  final BatteryStats batteryStats;
  final DataQualitySummary dataQuality;
  final AmortizationSummary amortization;
  final List<StateTimelineSegment> stateTimeline;
  final List<ChartPoint> monthlyMileage;
  final List<ChartPoint> rangeDegradation;
  final List<ChargingCurve> chargingCurves;
  final List<SpeedRateBucket> speedRates;
  final List<TemperatureEfficiencyPoint> speedTemperature;
  final List<StationStat> topStations;
}

class CurrentDriveSnapshot {
  const CurrentDriveSnapshot({
    required this.isDriving,
    required this.elapsed,
    required this.distanceKm,
    required this.averageSpeedKmh,
    required this.efficiencyWhPerKm,
    required this.energyKwh,
    required this.elevationGainM,
    required this.currentRangeKm,
    required this.odometerKm,
  });

  final bool isDriving;
  final Duration elapsed;
  final double distanceKm;
  final double averageSpeedKmh;
  final int efficiencyWhPerKm;
  final double energyKwh;
  final double elevationGainM;
  final double currentRangeKm;
  final double odometerKm;
}

class CurrentChargeSnapshot {
  const CurrentChargeSnapshot({
    required this.isCharging,
    required this.addedKwh,
    required this.addedRangeKm,
    required this.powerKw,
    required this.voltage,
    required this.currentA,
    required this.minutesRemaining,
    required this.odometerKm,
  });

  final bool isCharging;
  final double addedKwh;
  final double addedRangeKm;
  final double powerKw;
  final int voltage;
  final int currentA;
  final int minutesRemaining;
  final double odometerKm;
}

class ChargingCostSummary {
  const ChargingCostSummary({
    required this.totalEnergyUsedKwh,
    required this.freeEnergyKwh,
    required this.acEnergyKwh,
    required this.dcEnergyKwh,
    required this.superchargerEnergyKwh,
    required this.acCost,
    required this.dcCost,
    required this.superchargerCost,
    required this.totalCost,
    required this.costPer100Km,
    required this.costPerKwh,
    required this.netConsumptionWhPerKm,
    required this.grossConsumptionWhPerKm,
  });

  final double totalEnergyUsedKwh;
  final double freeEnergyKwh;
  final double acEnergyKwh;
  final double dcEnergyKwh;
  final double superchargerEnergyKwh;
  final double acCost;
  final double dcCost;
  final double superchargerCost;
  final double totalCost;
  final double costPer100Km;
  final double costPerKwh;
  final int netConsumptionWhPerKm;
  final int grossConsumptionWhPerKm;
}

class BatteryStats {
  const BatteryStats({
    required this.estimatedCapacityKwh,
    required this.nominalFullPackKwh,
    required this.degradationPercent,
    required this.ratedRangeNowKm,
    required this.ratedRangeStartKm,
    required this.bestRangeKm,
    required this.worstRangeKm,
  });

  final double estimatedCapacityKwh;
  final double nominalFullPackKwh;
  final double degradationPercent;
  final double ratedRangeNowKm;
  final double ratedRangeStartKm;
  final double bestRangeKm;
  final double worstRangeKm;
}

class DataQualitySummary {
  const DataQualitySummary({
    required this.incompleteDrives,
    required this.incompleteCharges,
    required this.missingPositions,
    required this.lastHealthyAt,
  });

  final int incompleteDrives;
  final int incompleteCharges;
  final int missingPositions;
  final DateTime lastHealthyAt;
}

class AmortizationSummary {
  const AmortizationSummary({
    required this.purchasePrice,
    required this.currentValue,
    required this.savingsToDate,
    required this.breakEvenPercent,
    required this.estimatedBreakEvenDate,
  });

  final double purchasePrice;
  final double currentValue;
  final double savingsToDate;
  final double breakEvenPercent;
  final DateTime estimatedBreakEvenDate;
}

class StateTimelineSegment {
  const StateTimelineSegment({required this.label, required this.hours});

  final String label;
  final double hours;
}

class ChartPoint {
  const ChartPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class ChargingCurve {
  const ChargingCurve({
    required this.label,
    required this.colorHex,
    required this.points,
  });

  final String label;
  final int colorHex;
  final List<ChartPoint> points;
}

class SpeedRateBucket {
  const SpeedRateBucket({
    required this.speedKmh,
    required this.netWhPerKm,
    required this.grossWhPerKm,
    required this.distanceKm,
  });

  final int speedKmh;
  final int netWhPerKm;
  final int grossWhPerKm;
  final double distanceKm;
}

class TemperatureEfficiencyPoint {
  const TemperatureEfficiencyPoint({
    required this.speedKmh,
    required this.temperatureC,
    required this.whPerKm,
  });

  final int speedKmh;
  final int temperatureC;
  final int whPerKm;
}

class StationStat {
  const StationStat({
    required this.name,
    required this.kind,
    required this.energyKwh,
    required this.cost,
    required this.sessions,
  });

  final String name;
  final String kind;
  final double energyKwh;
  final double cost;
  final int sessions;
}
