import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teslamate_mobile/app.dart';
import 'package:teslamate_mobile/data/reader_api_client.dart';
import 'package:teslamate_mobile/data/reader_api_config_store.dart';
import 'package:teslamate_mobile/data/teslamate_repository.dart';
import 'package:teslamate_mobile/models/teslamate_models.dart';
import 'package:teslamate_mobile/screens/charge_detail_screen.dart';
import 'package:teslamate_mobile/screens/dashboard_screen.dart';
import 'package:teslamate_mobile/screens/drive_detail_screen.dart';
import 'package:teslamate_mobile/screens/drives_screen.dart';
import 'package:teslamate_mobile/screens/insights_screen.dart';

GarageLensApp testApp({ReaderApiConfig? initialConfig}) {
  return GarageLensApp(
    configStore: MemoryReaderApiConfigStore(initialConfig: initialConfig),
  );
}

GarageLensApp connectedTestApp({
  required MemoryReaderApiConfigStore configStore,
  required TeslamateRepository repository,
  ReaderApiConnectionTester? connectionTester,
  bool autoRefreshBatches = false,
}) {
  return GarageLensApp(
    configStore: configStore,
    remoteRepositoryFactory: (_) => repository,
    connectionTester: connectionTester ?? (_) async {},
    autoRefreshBatches: autoRefreshBatches,
  );
}

TeslamateDashboardData? _cachedMockData;

Future<TeslamateDashboardData> mockDashboardData(WidgetTester tester) async {
  if (_cachedMockData != null) {
    return _cachedMockData!;
  }

  final dataFuture = MockTeslamateRepository().loadDashboard();
  await tester.pump(const Duration(milliseconds: 200));
  _cachedMockData = await dataFuture;
  return _cachedMockData!;
}

class StaticTeslamateRepository implements TeslamateRepository {
  StaticTeslamateRepository(
    this.data, {
    this.throwOnFirstLoad = false,
    this.throwOnRefresh = false,
  });

  final TeslamateDashboardData data;
  final bool throwOnFirstLoad;
  final bool throwOnRefresh;
  int batchLoads = 0;

  @override
  Future<TeslamateDashboardData> loadDashboard() async => data;

  @override
  Stream<TeslamateDashboardData> loadDashboardBatches() async* {
    batchLoads += 1;
    if (throwOnFirstLoad && batchLoads == 1) {
      throw const ReaderApiException(
        'HandshakeException: Connection terminated during handshake',
      );
    }
    if (throwOnRefresh && batchLoads > 1) {
      throw const ReaderApiException('Reader API request timed out.');
    }
    yield data;
  }
}

class BatchedTeslamateRepository implements TeslamateRepository {
  BatchedTeslamateRepository(this.batches);

  final List<TeslamateDashboardData> batches;

  @override
  Future<TeslamateDashboardData> loadDashboard() async => batches.last;

  @override
  Stream<TeslamateDashboardData> loadDashboardBatches() async* {
    for (final batch in batches) {
      yield batch;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

class SlowFirstBatchTeslamateRepository implements TeslamateRepository {
  SlowFirstBatchTeslamateRepository(this.data);

  final TeslamateDashboardData data;

  @override
  Future<TeslamateDashboardData> loadDashboard() async => data;

  @override
  Stream<TeslamateDashboardData> loadDashboardBatches() async* {
    await Future<void>.delayed(const Duration(seconds: 2));
    yield data;
  }
}

class MemoryReaderApiConfigStore extends ReaderApiConfigStore {
  MemoryReaderApiConfigStore({ReaderApiConfig? initialConfig}) : super() {
    _config = initialConfig ?? ReaderApiConfig.empty();
  }

  late ReaderApiConfig _config;

  @override
  Future<ReaderApiConfig> load() async => _config.normalized;

  @override
  Future<void> save(ReaderApiConfig config) async {
    _config = config.normalized;
  }

  @override
  Future<void> clear() async {
    _config = ReaderApiConfig.empty();
  }
}

Future<void> pumpGarageLens(WidgetTester tester) async {
  await tester.pumpWidget(testApp());
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> tapSave(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(button);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(button);
}

void main() {
  testWidgets('starts with data hidden until Reader credentials are verified', (
    tester,
  ) async {
    await pumpGarageLens(tester);

    expect(find.text('Connect Reader'), findsOneWidget);
    expect(find.text('Data hidden'), findsNothing);
    expect(find.text('Vehicle hidden'), findsNothing);
    expect(find.text('Reader API URL'), findsOneWidget);
    expect(find.text('Access token'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Test & Save'), findsNothing);
    expect(find.text('Clear connection'), findsNothing);
    expect(find.text('Open /api/ping'), findsNothing);
    expect(find.text('Model Y'), findsNothing);
    expect(find.text('Supercharger Sunnyvale'), findsNothing);
  });

  testWidgets('accepts Reader URL and token input before verification', (
    tester,
  ) async {
    await pumpGarageLens(tester);

    await tester.enterText(
      find.byType(EditableText).at(0),
      'https://reader.example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'token');
    await tester.pump();

    final urlField = tester.widget<TextField>(find.byType(TextField).at(0));
    final tokenField = tester.widget<TextField>(find.byType(TextField).at(1));

    expect(urlField.controller?.text, 'https://reader.example.com');
    expect(tokenField.controller?.text, 'token');
    expect(find.text('Data hidden'), findsNothing);
  });

  testWidgets('rejects invalid Reader URL before saving', (tester) async {
    await pumpGarageLens(tester);

    await tester.enterText(find.byType(EditableText).at(0), 'not-a-url');
    await tester.enterText(find.byType(EditableText).at(1), 'token');
    await tapSave(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(
      find.text('Connection failed: Enter a valid HTTPS Reader API URL.'),
      findsOneWidget,
    );
    expect(find.text('Connect Reader'), findsOneWidget);
    expect(find.text('Data hidden'), findsNothing);
  });

  testWidgets('rejects missing access token before saving', (tester) async {
    await pumpGarageLens(tester);

    await tester.enterText(
      find.byType(EditableText).at(0),
      'https://reader.example.com',
    );
    await tapSave(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(
      find.text('Connection failed: Enter the Reader API access token.'),
      findsOneWidget,
    );
    expect(find.text('Connect Reader'), findsOneWidget);
    expect(find.text('Data hidden'), findsNothing);
  });

  testWidgets('verified Reader credentials save config and unlock dashboard', (
    tester,
  ) async {
    final configStore = MemoryReaderApiConfigStore();
    final repository = StaticTeslamateRepository(
      await mockDashboardData(tester),
    );
    ReaderApiConfig? verifiedConfig;

    await tester.pumpWidget(
      connectedTestApp(
        configStore: configStore,
        repository: repository,
        connectionTester: (config) async {
          verifiedConfig = config;
        },
      ),
    );
    await advance(tester);

    await tester.enterText(
      find.byType(EditableText).at(0),
      ' https://reader.example.com/ ',
    );
    await tester.enterText(find.byType(EditableText).at(1), ' test-token ');
    await tapSave(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final savedConfig = await configStore.load();
    expect(verifiedConfig?.baseUrl, 'https://reader.example.com');
    expect(verifiedConfig?.accessToken, 'test-token');
    expect(savedConfig.baseUrl, 'https://reader.example.com');
    expect(savedConfig.accessToken, 'test-token');
    expect(savedConfig.isConfigured, isTrue);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Model Y'), findsOneWidget);
    expect(find.text('Remote data'), findsNothing);
    expect(find.text('Open /api/ping'), findsNothing);
    expect(find.text('Data hidden'), findsNothing);
    expect(find.text('Connect Reader'), findsNothing);
  });

  testWidgets('failed Reader verification does not save or unlock data', (
    tester,
  ) async {
    final configStore = MemoryReaderApiConfigStore();
    final repository = StaticTeslamateRepository(
      await mockDashboardData(tester),
    );

    await tester.pumpWidget(
      connectedTestApp(
        configStore: configStore,
        repository: repository,
        connectionTester: (_) async {
          throw const ReaderApiException('HTTP 401 unauthorized');
        },
      ),
    );
    await advance(tester);

    await tester.enterText(
      find.byType(EditableText).at(0),
      'https://reader.example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'wrong-token');
    await tapSave(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final savedConfig = await configStore.load();
    expect(savedConfig.isConfigured, isFalse);
    expect(
      find.text(
        'Connection failed: Reader API token was not accepted. Check the access token.',
      ),
      findsOneWidget,
    );
    expect(find.text('Connect Reader'), findsOneWidget);
    expect(find.text('Data hidden'), findsNothing);
    expect(find.text('Model Y'), findsNothing);
  });

  testWidgets('save button shows Connecting while validating Reader', (
    tester,
  ) async {
    final configStore = MemoryReaderApiConfigStore();
    final repository = StaticTeslamateRepository(
      await mockDashboardData(tester),
    );

    await tester.pumpWidget(
      connectedTestApp(
        configStore: configStore,
        repository: repository,
        connectionTester: (_) async {
          await Future<void>.delayed(const Duration(seconds: 1));
        },
      ),
    );
    await advance(tester);

    await tester.enterText(
      find.byType(EditableText).at(0),
      'https://reader.example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'test-token');
    await tapSave(tester);
    await tester.pump();

    expect(find.text('Connecting'), findsOneWidget);
    expect(find.text('Testing'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'verified Reader credentials show loading until first data batch',
    (tester) async {
      final configStore = MemoryReaderApiConfigStore();
      final repository = SlowFirstBatchTeslamateRepository(
        await mockDashboardData(tester),
      );

      await tester.pumpWidget(
        connectedTestApp(
          configStore: configStore,
          repository: repository,
          connectionTester: (_) async {},
        ),
      );
      await advance(tester);

      await tester.enterText(
        find.byType(EditableText).at(0),
        'https://reader.example.com',
      );
      await tester.enterText(find.byType(EditableText).at(1), 'test-token');
      await tapSave(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Loading TeslaMate data'), findsOneWidget);
      expect(find.text('Hidden vehicle'), findsNothing);
      expect(find.text('Overview'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Model Y'), findsOneWidget);
    },
  );

  testWidgets('refresh failure after login keeps dashboard unlocked', (
    tester,
  ) async {
    final configStore = MemoryReaderApiConfigStore(
      initialConfig: const ReaderApiConfig(
        baseUrl: 'https://reader.example.com',
        accessToken: 'test-token',
      ),
    );
    final repository = StaticTeslamateRepository(
      await mockDashboardData(tester),
      throwOnRefresh: true,
    );

    await tester.pumpWidget(
      connectedTestApp(
        configStore: configStore,
        repository: repository,
        autoRefreshBatches: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Model Y'), findsOneWidget);
    expect(find.text('Data hidden'), findsNothing);
    expect(find.text('Connect Reader'), findsNothing);
    expect(
      find.text(
        'Some Reader API data is still loading slowly. Showing the latest loaded data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('first remote load failure keeps data hidden', (tester) async {
    final configStore = MemoryReaderApiConfigStore(
      initialConfig: const ReaderApiConfig(
        baseUrl: 'https://reader.example.com',
        accessToken: 'test-token',
      ),
    );
    final repository = StaticTeslamateRepository(
      await mockDashboardData(tester),
      throwOnFirstLoad: true,
    );

    await tester.pumpWidget(
      connectedTestApp(configStore: configStore, repository: repository),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Connect Reader'), findsOneWidget);
    expect(find.text('Data hidden'), findsNothing);
    expect(find.text('Model Y'), findsNothing);
    expect(
      find.text(
        'This phone network could not open a secure connection to the Reader API. Try turning VPN off/on, switch Wi-Fi/5G, or open /api/ping in the phone browser.',
      ),
      findsWidgets,
    );
  });

  testWidgets('insight detail updates when analytics batch arrives', (
    tester,
  ) async {
    final fullData = await mockDashboardData(tester);
    final firstBatch = fullData.copyWith(
      analytics: AnalyticsData(
        currentDrive: fullData.analytics.currentDrive,
        currentCharge: fullData.analytics.currentCharge,
        chargingCosts: fullData.analytics.chargingCosts,
        batteryStats: fullData.analytics.batteryStats,
        dataQuality: fullData.analytics.dataQuality,
        amortization: fullData.analytics.amortization,
        stateTimeline: fullData.analytics.stateTimeline,
        monthlyMileage: const [],
        rangeDegradation: const [],
        chargingCurves: const [],
        speedRates: const [],
        speedTemperature: const [],
        topStations: const [],
      ),
    );
    final dataNotifier = ValueNotifier<TeslamateDashboardData>(firstBatch);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InsightsScreen(data: firstBatch, dataListenable: dataNotifier),
        ),
      ),
    );
    await tester.pump();

    final batteryCard = find.text('Battery and range').first;
    await tester.ensureVisible(batteryCard);
    await tester.tap(batteryCard);
    await advance(tester);

    expect(find.text('Battery Health'), findsOneWidget);
    expect(
      find.text(
        'Analytics chart data is still loading. Pull latest data or retry Reader API refresh.',
      ),
      findsOneWidget,
    );

    dataNotifier.value = fullData;
    await tester.pump();

    expect(
      find.text(
        'Analytics chart data is still loading. Pull latest data or retry Reader API refresh.',
      ),
      findsNothing,
    );
    expect(find.text('Range degradation'), findsOneWidget);
    dataNotifier.dispose();
  });

  testWidgets('insights quick links open focused detail pages', (tester) async {
    final data = await mockDashboardData(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InsightsScreen(data: data)),
      ),
    );
    await tester.pump();

    expect(find.text('Current state'), findsOneWidget);
    expect(find.text('Charging cost'), findsOneWidget);
    expect(find.text('22 official areas'), findsNothing);

    final rangeLink = find.text('Range loss');
    await tester.dragUntilVisible(
      rangeLink,
      find.byType(Scrollable).first,
      const Offset(-180, 0),
    );
    await tester.tap(rangeLink);
    await advance(tester);

    expect(find.widgetWithText(AppBar, 'Range Loss'), findsOneWidget);
    expect(find.text('Capacity'), findsOneWidget);
    expect(find.text('Degradation'), findsOneWidget);
    expect(find.text('Range degradation'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Vampire Drain'),
      find.byType(Scrollable).last,
      const Offset(0, -180),
    );
    expect(find.text('Vampire Drain'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    final dataQualityLink = find.text('Data quality');
    await tester.dragUntilVisible(
      dataQualityLink,
      find.byType(Scrollable).first,
      const Offset(-180, 0),
    );
    await tester.ensureVisible(dataQualityLink);
    await tester.tap(dataQualityLink);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Data Quality'), findsOneWidget);
    expect(find.text('Incomplete drives'), findsOneWidget);
    expect(find.text('Missing positions'), findsOneWidget);
    expect(find.text('Last healthy sample'), findsOneWidget);
  });

  testWidgets('tracking drives entry opens focused drive tracking page', (
    tester,
  ) async {
    final data = await mockDashboardData(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InsightsScreen(data: data)),
      ),
    );
    await tester.pump();

    final drivesModule = find.text('Drives and trips');
    await tester.dragUntilVisible(
      drivesModule,
      find.byType(ListView).first,
      const Offset(0, -220),
    );
    await tester.tap(drivesModule);
    await tester.pumpAndSettle();

    final trackingEntry = find.widgetWithText(ListTile, 'Tracking Drives');
    await tester.dragUntilVisible(
      trackingEntry,
      find.byType(ListView).last,
      const Offset(0, -220),
    );
    await tester.tap(trackingEntry);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Tracking Drives'), findsOneWidget);
    expect(find.text('Energy consumed and elevation profile'), findsOneWidget);
    expect(find.textContaining('Wh/km'), findsWidgets);
  });

  testWidgets('drive detail route tracking uses map attribution', (
    tester,
  ) async {
    final data = await mockDashboardData(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DrivesScreen(
            data: data,
            readerApiConfig: ReaderApiConfig.empty(),
            usingRemoteData: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final driveCard = find.text(data.drives.first.startLocation).first;
    await tester.ensureVisible(driveCard);
    await tester.tap(driveCard);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Drive detail'), findsOneWidget);
    expect(find.text('Route tracking'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(find.byTooltip('Reset map'), findsOneWidget);
    expect(find.textContaining('Map data:'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'OpenStreetMap' || widget.data == 'Amap'),
      ),
      findsOneWidget,
    );
    await tester.dragUntilVisible(
      find.text('Speed'),
      find.byType(Scrollable).last,
      const Offset(0, -240),
    );
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('50 km/h'), findsOneWidget);
    expect(find.textContaining('km/h'), findsWidgets);
    expect(find.text('0 km/h'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Battery'),
      find.byType(Scrollable).last,
      const Offset(0, -240),
    );
    expect(find.text('Battery'), findsOneWidget);
    expect(find.text('74 %'), findsOneWidget);
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('drive detail hides raw Reader API detail errors', (
    tester,
  ) async {
    final data = await mockDashboardData(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: DriveDetailScreen(
          carId: data.carId,
          drive: data.drives.first,
          readerApiConfig: const ReaderApiConfig(
            baseUrl: 'https://reader.example.com',
            accessToken: 'token',
          ),
          usingRemoteData: true,
          detailFuture: Future<DriveRecord>.delayed(
            Duration.zero,
            () => throw const ReaderApiException(
              'native_connection_failed: IllegalStateException: OkHttp IPv4 failed',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Drive detail is taking too long to load'),
      findsOneWidget,
    );
    expect(find.textContaining('OkHttp'), findsNothing);
    expect(find.textContaining('native_connection_failed'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Speed'),
      find.byType(Scrollable).last,
      const Offset(0, -240),
    );
    expect(find.text('Speed'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Battery'),
      find.byType(Scrollable).last,
      const Offset(0, -240),
    );
    expect(find.text('Battery'), findsOneWidget);
  });

  testWidgets('charge detail shows peak power instead of final zero sample', (
    tester,
  ) async {
    final charge = ChargeSession(
      id: 140,
      startedAt: DateTime(2026, 5, 1, 14, 31),
      duration: const Duration(minutes: 28),
      location: 'Charging',
      startBatteryLevel: 14,
      endBatteryLevel: 43,
      addedKwh: 20.7,
      rangeAddedKm: 125,
      cost: 0,
      maxPowerKw: 89,
      voltage: 398,
      currentA: 224,
      chargeCurve: const [
        ChartPoint(label: '14%', value: 0),
        ChartPoint(label: '15%', value: 88),
        ChartPoint(label: '29%', value: 89),
        ChartPoint(label: '43%', value: 0),
      ],
      batteryCurve: const [
        ChartPoint(label: '0m', value: 14),
        ChartPoint(label: '14m', value: 28),
        ChartPoint(label: '28m', value: 43),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChargeDetailScreen(
          carId: 1,
          charge: charge,
          readerApiConfig: ReaderApiConfig.empty(),
          usingRemoteData: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(AppBar, 'Charge detail'), findsOneWidget);
    expect(find.text('Charging power'), findsOneWidget);
    expect(find.text('89 kW'), findsOneWidget);
    expect(find.text('0 kW'), findsNothing);
  });

  testWidgets('vehicle detail explains sample time and opens location map', (
    tester,
  ) async {
    final data = await mockDashboardData(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            data: data,
            readerApiConfig: ReaderApiConfig.empty(),
            usingRemoteData: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(data.vehicle.displayName).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Vehicle detail'), findsOneWidget);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Vehicle sample time'), findsOneWidget);
    expect(
      find.text('Latest vehicle state timestamp written by TeslaMate.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Current location'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Current location'), findsOneWidget);
    expect(find.textContaining('Map data:'), findsOneWidget);
    expect(find.text('Coordinates'), findsOneWidget);
  });

  test('Reader config store saves normalized URL and token', () async {
    final store = MemoryReaderApiConfigStore();

    await store.save(
      const ReaderApiConfig(
        baseUrl: ' https://reader.example.com/ ',
        accessToken: ' token ',
      ),
    );

    final saved = await store.load();
    expect(saved.baseUrl, 'https://reader.example.com');
    expect(saved.accessToken, 'token');
    expect(saved.isConfigured, isTrue);
  });
}
