import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/teslamate_models.dart';

class ReaderApiConfig {
  const ReaderApiConfig({required this.baseUrl, required this.accessToken});

  factory ReaderApiConfig.empty() {
    return const ReaderApiConfig(baseUrl: '', accessToken: '');
  }

  factory ReaderApiConfig.fromEnvironment() {
    return const ReaderApiConfig(
      baseUrl: String.fromEnvironment('READER_API_URL'),
      accessToken: String.fromEnvironment('READER_API_TOKEN'),
    );
  }

  factory ReaderApiConfig.fromJson(Map<String, dynamic> json) {
    return ReaderApiConfig(
      baseUrl: json['baseUrl']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
    );
  }

  final String baseUrl;
  final String accessToken;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  ReaderApiConfig get normalized {
    return ReaderApiConfig(
      baseUrl: baseUrl.trim().replaceAll(RegExp(r'/$'), ''),
      accessToken: accessToken.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    final value = normalized;
    return {'baseUrl': value.baseUrl, 'accessToken': value.accessToken};
  }
}

class ReaderApiClient {
  ReaderApiClient({required ReaderApiConfig config, http.Client? httpClient})
    : _config = config,
      _httpClient = httpClient ?? http.Client();

  final ReaderApiConfig _config;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> testHealth({
    String? baseUrl,
    String? accessToken,
  }) async {
    final response = await _getRaw(
      baseUrl: baseUrl,
      accessToken: accessToken,
      path: '/api/health',
      timeout: const Duration(seconds: 8),
    );
    return _decodeObject(response);
  }

  Future<void> testConnection() async {
    final health = await testHealth();
    final status = health['status']?.toString() ?? 'ok';
    if (status != 'ok') {
      throw ReaderApiException(
        'Reader API is reachable, but not ready: $status.',
      );
    }

    final cars = await _getObjectList(
      '/api/cars',
      timeout: const Duration(seconds: 8),
    );
    if (cars.isEmpty) {
      throw const ReaderApiException('Reader API did not return any cars.');
    }
  }

  Future<TeslamateDashboardData> loadDashboard() async {
    final cars = await _getObjectList(
      '/api/cars',
      timeout: const Duration(seconds: 12),
    );
    if (cars.isEmpty) {
      throw ReaderApiException('Reader API did not return any cars.');
    }

    final carId = _parseId(cars.first['id']);
    final dashboard = await _getObject(
      '/api/cars/$carId/overview',
      timeout: const Duration(seconds: 60),
    );
    return _DashboardMapper().fromJson(dashboard, carId: carId);
  }

  Future<DriveRecord> loadDriveDetail({
    required int carId,
    required int driveId,
  }) async {
    final drive = await _getObject('/api/cars/$carId/drives/$driveId');
    return _DashboardMapper().driveFromJson(drive);
  }

  Future<ChargeSession> loadChargeDetail({
    required int carId,
    required int chargeId,
  }) async {
    final charge = await _getObject(
      '/api/cars/$carId/charging/sessions/$chargeId',
    );
    return _DashboardMapper().chargeFromJson(charge);
  }

  Future<List<List<RoutePoint>>> loadVisitedRoutes({required int carId}) async {
    final data = await _getObject('/api/cars/$carId/visited-map');
    return _DashboardMapper().visitedRoutesFromJson(data);
  }

  Future<http.Response> _getRaw({
    required String path,
    String? baseUrl,
    String? accessToken,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final resolvedBaseUrl = (baseUrl ?? _config.baseUrl).trim();
    final resolvedToken = accessToken ?? _config.accessToken;
    final uri = Uri.parse(
      '${resolvedBaseUrl.replaceAll(RegExp(r'/$'), '')}$path',
    );

    final response = await _httpClient
        .get(
          uri,
          headers: {
            'accept': 'application/json',
            if (resolvedToken.trim().isNotEmpty)
              'authorization': 'Bearer ${resolvedToken.trim()}',
          },
        )
        .timeout(
          timeout,
          onTimeout: () {
            throw const ReaderApiException('Reader API request timed out.');
          },
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReaderApiException(
        'Reader API returned HTTP ${response.statusCode}.',
      );
    }

    return response;
  }

  Future<Map<String, dynamic>> _getObject(
    String path, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    return _decodeObject(await _getRaw(path: path, timeout: timeout));
  }

  Future<List<Map<String, dynamic>>> _getObjectList(
    String path, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final decoded = jsonDecode(
      (await _getRaw(path: path, timeout: timeout)).body,
    );
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw ReaderApiException('Reader API returned an unexpected list shape.');
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ReaderApiException('Reader API returned an unexpected object shape.');
  }

  int _parseId(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ReaderApiException implements Exception {
  const ReaderApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _DashboardMapper {
  TeslamateDashboardData fromJson(
    Map<String, dynamic> json, {
    required int carId,
  }) {
    final vehicle = _vehicle(json['vehicle']);
    final monthly = _monthlyStats(json['monthlyStats']);
    final drives = _list(json['drives']).map(_drive).toList();
    final charges = _list(json['charges']).map(_charge).toList();
    final locations = _list(json['locations']).map(_location).toList();
    final database = _database(json['database']);
    final analytics = _analytics(json['analytics'], monthly, drives, charges);

    return TeslamateDashboardData(
      carId: carId,
      vehicle: vehicle,
      monthlyStats: monthly,
      drives: drives,
      charges: charges,
      locations: locations,
      database: database,
      analytics: analytics,
    );
  }

  DriveRecord driveFromJson(Map<String, dynamic> json) {
    return _drive(json);
  }

  ChargeSession chargeFromJson(Map<String, dynamic> json) {
    return _charge(json);
  }

  List<List<RoutePoint>> visitedRoutesFromJson(Map<String, dynamic> json) {
    return _list(json['routes'])
        .map((route) {
          return _list(route['points']).map(_routePoint).toList();
        })
        .where((route) => route.length >= 2)
        .toList();
  }

  VehicleSnapshot _vehicle(Object? value) {
    final json = _map(value);
    return VehicleSnapshot(
      displayName: _string(json, 'displayName', fallback: 'Tesla'),
      model: _string(json, 'model', fallback: 'Unknown model'),
      state: _vehicleState(_string(json, 'state', fallback: 'offline')),
      batteryLevel: _int(json, 'batteryLevel'),
      usableBatteryLevel: _int(json, 'usableBatteryLevel'),
      ratedRangeKm: _double(json, 'ratedRangeKm'),
      idealRangeKm: _double(json, 'idealRangeKm'),
      odometerKm: _double(json, 'odometerKm'),
      locationName: _string(json, 'locationName', fallback: 'Unknown'),
      latitude: _double(json, 'latitude'),
      longitude: _double(json, 'longitude'),
      lastSeen: _date(json, 'lastSeen'),
      outsideTempC: _double(json, 'outsideTempC'),
      insideTempC: _double(json, 'insideTempC'),
      powerKw: _double(json, 'powerKw'),
      pluggedIn: _bool(json, 'pluggedIn'),
    );
  }

  MonthlyStats _monthlyStats(Object? value) {
    final json = _map(value);
    return MonthlyStats(
      distanceKm: _double(json, 'distanceKm'),
      driveCount: _int(json, 'driveCount'),
      energyKwh: _double(json, 'energyKwh'),
      chargeEnergyKwh: _doubleOr(json, 'chargeEnergyKwh', 0),
      efficiencyWhPerKm: _int(json, 'efficiencyWhPerKm'),
      chargeCount: _int(json, 'chargeCount'),
      chargingCost: _double(json, 'chargingCost'),
      onlineHours: _double(json, 'onlineHours'),
      asleepHours: _double(json, 'asleepHours'),
    );
  }

  DriveRecord _drive(Map<String, dynamic> json) {
    return DriveRecord(
      id: _int(json, 'id'),
      startedAt: _date(json, 'startedAt'),
      duration: Duration(minutes: _int(json, 'durationMinutes')),
      startLocation: _string(json, 'startLocation', fallback: 'Start'),
      endLocation: _string(json, 'endLocation', fallback: 'End'),
      startLatitude: _double(json, 'startLatitude'),
      startLongitude: _double(json, 'startLongitude'),
      endLatitude: _double(json, 'endLatitude'),
      endLongitude: _double(json, 'endLongitude'),
      distanceKm: _double(json, 'distanceKm'),
      energyKwh: _double(json, 'energyKwh'),
      efficiencyWhPerKm: _int(json, 'efficiencyWhPerKm'),
      maxSpeedKmh: _int(json, 'maxSpeedKmh'),
      averageSpeedKmh: _double(json, 'averageSpeedKmh'),
      startBatteryLevel: _int(json, 'startBatteryLevel'),
      endBatteryLevel: _int(json, 'endBatteryLevel'),
      route: _list(json['route']).map(_routePoint).toList(),
      speedCurve: _list(json['speedCurve']).map(_chartPoint).toList(),
      elevationCurve: _list(json['elevationCurve']).map(_chartPoint).toList(),
      batteryCurve: _list(json['batteryCurve']).map(_chartPoint).toList(),
    );
  }

  ChargeSession _charge(Map<String, dynamic> json) {
    return ChargeSession(
      id: _int(json, 'id'),
      startedAt: _date(json, 'startedAt'),
      duration: Duration(minutes: _int(json, 'durationMinutes')),
      location: _string(json, 'location', fallback: 'Charging location'),
      startBatteryLevel: _int(json, 'startBatteryLevel'),
      endBatteryLevel: _int(json, 'endBatteryLevel'),
      addedKwh: _double(json, 'addedKwh'),
      rangeAddedKm: _double(json, 'rangeAddedKm'),
      cost: _double(json, 'cost'),
      maxPowerKw: _double(json, 'maxPowerKw'),
      voltage: _int(json, 'voltage'),
      currentA: _int(json, 'currentA'),
      chargeCurve: _list(json['chargeCurve']).map(_chartPoint).toList(),
      batteryCurve: _list(json['batteryCurve']).map(_chartPoint).toList(),
    );
  }

  LocationVisit _location(Map<String, dynamic> json) {
    return LocationVisit(
      name: _string(json, 'name', fallback: 'Location'),
      address: _string(json, 'address', fallback: ''),
      kind: _string(json, 'kind', fallback: 'Visit'),
      visitCount: _int(json, 'visitCount'),
      lastVisitedAt: _date(json, 'lastVisitedAt'),
      distanceFromHomeKm: _double(json, 'distanceFromHomeKm'),
    );
  }

  DatabaseInfo _database(Object? value) {
    final json = _map(value);
    return DatabaseInfo(
      connected: _bool(json, 'connected'),
      databaseName: _string(json, 'databaseName', fallback: 'unknown'),
      schemaVersion: _string(json, 'schemaVersion', fallback: 'unknown'),
      databaseSizeMb: _double(json, 'databaseSizeMb'),
      carRows: _int(json, 'carRows'),
      driveRows: _int(json, 'driveRows'),
      positionRows: _int(json, 'positionRows'),
      chargeRows: _int(json, 'chargeRows'),
      chargingProcessRows: _int(json, 'chargingProcessRows'),
      stateRows: _int(json, 'stateRows'),
      geofenceRows: _int(json, 'geofenceRows'),
      firstDataAt: _date(json, 'firstDataAt'),
      latestDataAt: _date(json, 'latestDataAt'),
      readerApiVersion: _string(json, 'readerApiVersion', fallback: 'unknown'),
    );
  }

  AnalyticsData _analytics(
    Object? value,
    MonthlyStats monthly,
    List<DriveRecord> drives,
    List<ChargeSession> charges,
  ) {
    final json = _map(value);
    final currentDrive = _map(json['currentDrive']);
    final currentCharge = _map(json['currentCharge']);
    final chargingCosts = _map(json['chargingCosts']);
    final isDriving = _bool(currentDrive, 'isDriving');
    final isCharging = _bool(currentCharge, 'isCharging');
    final firstDrive = isDriving && drives.isNotEmpty ? drives.first : null;
    final firstCharge = isCharging && charges.isNotEmpty ? charges.first : null;
    final totalChargeEnergy = monthly.chargeEnergyKwh > 0
        ? monthly.chargeEnergyKwh
        : charges.fold<double>(0, (sum, charge) => sum + charge.addedKwh);
    final totalChargingCost = monthly.chargingCost;

    return AnalyticsData(
      currentDrive: CurrentDriveSnapshot(
        isDriving: isDriving,
        elapsed: Duration(
          minutes: _intOr(
            currentDrive,
            'elapsedMinutes',
            firstDrive?.duration.inMinutes ?? 0,
          ),
        ),
        distanceKm: _doubleOr(
          currentDrive,
          'distanceKm',
          firstDrive?.distanceKm ?? 0,
        ),
        averageSpeedKmh: _doubleOr(
          currentDrive,
          'averageSpeedKmh',
          firstDrive?.averageSpeedKmh ?? 0,
        ),
        efficiencyWhPerKm: _intOr(
          currentDrive,
          'efficiencyWhPerKm',
          firstDrive?.efficiencyWhPerKm ?? 0,
        ),
        energyKwh: _doubleOr(
          currentDrive,
          'energyKwh',
          firstDrive?.energyKwh ?? 0,
        ),
        elevationGainM: _doubleOr(currentDrive, 'elevationGainM', 0),
        currentRangeKm: _doubleOr(currentDrive, 'currentRangeKm', 0),
        odometerKm: _doubleOr(currentDrive, 'odometerKm', 0),
      ),
      currentCharge: CurrentChargeSnapshot(
        isCharging: isCharging,
        addedKwh: _doubleOr(
          currentCharge,
          'addedKwh',
          firstCharge?.addedKwh ?? 0,
        ),
        addedRangeKm: _doubleOr(
          currentCharge,
          'addedRangeKm',
          firstCharge?.rangeAddedKm ?? 0,
        ),
        powerKw: _doubleOr(
          currentCharge,
          'powerKw',
          firstCharge?.maxPowerKw ?? 0,
        ),
        voltage: _intOr(currentCharge, 'voltage', firstCharge?.voltage ?? 0),
        currentA: _intOr(currentCharge, 'currentA', firstCharge?.currentA ?? 0),
        minutesRemaining: _intOr(currentCharge, 'minutesRemaining', 0),
        odometerKm: _doubleOr(currentCharge, 'odometerKm', 0),
      ),
      chargingCosts: ChargingCostSummary(
        totalEnergyUsedKwh: _doubleOr(
          chargingCosts,
          'totalEnergyUsedKwh',
          totalChargeEnergy,
        ),
        freeEnergyKwh: _doubleOr(chargingCosts, 'freeEnergyKwh', 0),
        acEnergyKwh: _doubleOr(chargingCosts, 'acEnergyKwh', 0),
        dcEnergyKwh: _doubleOr(chargingCosts, 'dcEnergyKwh', 0),
        superchargerEnergyKwh: _doubleOr(
          chargingCosts,
          'superchargerEnergyKwh',
          0,
        ),
        acCost: _doubleOr(chargingCosts, 'acCost', 0),
        dcCost: _doubleOr(chargingCosts, 'dcCost', 0),
        superchargerCost: _doubleOr(chargingCosts, 'superchargerCost', 0),
        totalCost: _doubleOr(chargingCosts, 'totalCost', totalChargingCost),
        costPer100Km: _doubleOr(
          chargingCosts,
          'costPer100Km',
          monthly.distanceKm == 0
              ? 0
              : totalChargingCost / monthly.distanceKm * 100,
        ),
        costPerKwh: _doubleOr(
          chargingCosts,
          'costPerKwh',
          totalChargeEnergy == 0 ? 0 : totalChargingCost / totalChargeEnergy,
        ),
        netConsumptionWhPerKm: _intOr(
          chargingCosts,
          'netConsumptionWhPerKm',
          monthly.efficiencyWhPerKm,
        ),
        grossConsumptionWhPerKm: _intOr(
          chargingCosts,
          'grossConsumptionWhPerKm',
          monthly.efficiencyWhPerKm,
        ),
      ),
      batteryStats: BatteryStats(
        estimatedCapacityKwh: _double(
          _map(json['batteryStats']),
          'estimatedCapacityKwh',
        ),
        nominalFullPackKwh: _double(
          _map(json['batteryStats']),
          'nominalFullPackKwh',
        ),
        degradationPercent: _double(
          _map(json['batteryStats']),
          'degradationPercent',
        ),
        ratedRangeNowKm: _double(_map(json['batteryStats']), 'ratedRangeNowKm'),
        ratedRangeStartKm: _double(
          _map(json['batteryStats']),
          'ratedRangeStartKm',
        ),
        bestRangeKm: _double(_map(json['batteryStats']), 'bestRangeKm'),
        worstRangeKm: _double(_map(json['batteryStats']), 'worstRangeKm'),
      ),
      dataQuality: DataQualitySummary(
        incompleteDrives: _int(_map(json['dataQuality']), 'incompleteDrives'),
        incompleteCharges: _int(_map(json['dataQuality']), 'incompleteCharges'),
        missingPositions: _int(_map(json['dataQuality']), 'missingPositions'),
        lastHealthyAt: _date(_map(json['dataQuality']), 'lastHealthyAt'),
      ),
      amortization: AmortizationSummary(
        purchasePrice: _double(_map(json['amortization']), 'purchasePrice'),
        currentValue: _double(_map(json['amortization']), 'currentValue'),
        savingsToDate: _double(_map(json['amortization']), 'savingsToDate'),
        breakEvenPercent: _double(
          _map(json['amortization']),
          'breakEvenPercent',
        ),
        estimatedBreakEvenDate: _date(
          _map(json['amortization']),
          'estimatedBreakEvenDate',
        ),
      ),
      stateTimeline: _list(json['stateTimeline']).map((item) {
        return StateTimelineSegment(
          label: _string(item, 'label', fallback: 'Unknown'),
          hours: _double(item, 'hours'),
        );
      }).toList(),
      monthlyMileage: _list(json['monthlyMileage']).map(_chartPoint).toList(),
      rangeDegradation: _list(
        json['rangeDegradation'],
      ).map(_chartPoint).toList(),
      chargingCurves: _list(json['chargingCurves']).map((item) {
        return ChargingCurve(
          label: _string(item, 'label', fallback: 'Curve'),
          colorHex: _int(item, 'colorHex'),
          points: _list(item['points']).map(_chartPoint).toList(),
        );
      }).toList(),
      speedRates: _list(json['speedRates']).map((item) {
        return SpeedRateBucket(
          speedKmh: _int(item, 'speedKmh'),
          netWhPerKm: _int(item, 'netWhPerKm'),
          grossWhPerKm: _int(item, 'grossWhPerKm'),
          distanceKm: _double(item, 'distanceKm'),
        );
      }).toList(),
      speedTemperature: _list(json['speedTemperature']).map((item) {
        return TemperatureEfficiencyPoint(
          speedKmh: _int(item, 'speedKmh'),
          temperatureC: _int(item, 'temperatureC'),
          whPerKm: _int(item, 'whPerKm'),
        );
      }).toList(),
      topStations: _list(json['topStations']).map((item) {
        return StationStat(
          name: _string(item, 'name', fallback: 'Station'),
          kind: _string(item, 'kind', fallback: 'Charging'),
          energyKwh: _double(item, 'energyKwh'),
          cost: _double(item, 'cost'),
          sessions: _int(item, 'sessions'),
        );
      }).toList(),
    );
  }

  RoutePoint _routePoint(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: _double(json, 'latitude'),
      longitude: _double(json, 'longitude'),
      label: _string(json, 'label', fallback: ''),
    );
  }

  ChartPoint _chartPoint(Map<String, dynamic> json) {
    return ChartPoint(
      label: _string(json, 'label', fallback: ''),
      value: _double(json, 'value'),
    );
  }

  VehicleState _vehicleState(String value) {
    return switch (value.toLowerCase()) {
      'online' => VehicleState.online,
      'asleep' => VehicleState.asleep,
      'charging' => VehicleState.charging,
      _ => VehicleState.offline,
    };
  }

  List<Map<String, dynamic>> _list(Object? value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return const {};
  }

  String _string(
    Map<String, dynamic> json,
    String key, {
    required String fallback,
  }) {
    final value = json[key];
    if (value == null) {
      return fallback;
    }
    return value.toString();
  }

  int _int(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _intOr(Map<String, dynamic> json, String key, int fallback) {
    if (!json.containsKey(key)) {
      return fallback;
    }
    return _int(json, key);
  }

  double _double(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _doubleOr(Map<String, dynamic> json, String key, double fallback) {
    if (!json.containsKey(key)) {
      return fallback;
    }
    return _double(json, key);
  }

  bool _bool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
    return value?.toString().toLowerCase() == 'true';
  }

  DateTime _date(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
