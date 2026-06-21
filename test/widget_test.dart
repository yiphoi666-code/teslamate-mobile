import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teslamate_mobile/app.dart';
import 'package:teslamate_mobile/data/reader_api_client.dart';
import 'package:teslamate_mobile/data/reader_api_config_store.dart';
import 'package:teslamate_mobile/data/teslamate_repository.dart';
import 'package:teslamate_mobile/models/teslamate_models.dart';

GarageLensApp testApp({ReaderApiConfig? initialConfig}) {
  return GarageLensApp(
    configStore: MemoryReaderApiConfigStore(initialConfig: initialConfig),
  );
}

Widget unlockedTestApp(TeslamateDashboardData data) {
  return MaterialApp(
    home: HomeShell(
      data: data,
      readerApiConfig: ReaderApiConfig.empty(),
      usingRemoteData: true,
      isLocked: false,
      dataSourceError: null,
      onReaderApiConfigSaved: (_) async {},
      onReaderApiConfigCleared: () async {},
    ),
  );
}

class MemoryReaderApiConfigStore extends ReaderApiConfigStore {
  MemoryReaderApiConfigStore({ReaderApiConfig? initialConfig}) : super() {
    _config = initialConfig ?? ReaderApiConfig.empty();
  }

  late ReaderApiConfig _config;

  @override
  Future<ReaderApiConfig> load() async => _config;

  @override
  Future<void> save(ReaderApiConfig config) async {
    _config = config;
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

Future<void> pumpUnlockedGarageLens(WidgetTester tester) async {
  final data = await MockTeslamateRepository().loadDashboard();
  await tester.pumpWidget(unlockedTestApp(data));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('starts with data hidden until Reader credentials are verified', (
    tester,
  ) async {
    await pumpGarageLens(tester);

    expect(find.text('Connect Reader'), findsOneWidget);
    expect(find.text('Data hidden'), findsWidgets);
    expect(find.text('Vehicle hidden'), findsOneWidget);
    expect(find.text('Reader API URL'), findsOneWidget);
    expect(find.text('Access token'), findsOneWidget);
    expect(find.text('Test & Save'), findsOneWidget);
    expect(find.text('Model Y'), findsNothing);
    expect(find.text('Supercharger Sunnyvale'), findsNothing);
  });

  testWidgets('loads unlocked dashboard and navigates to charging', (
    tester,
  ) async {
    await pumpUnlockedGarageLens(tester);

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Model Y'), findsWidgets);
    expect(find.text('This month'), findsOneWidget);

    await tester.tap(find.text('Charges'));
    await advance(tester);

    expect(find.text('Charging sessions'), findsOneWidget);
    expect(find.text('Supercharger Sunnyvale'), findsOneWidget);
  }, skip: true);

  testWidgets('shows dashboard-derived insights with chart sections', (
    tester,
  ) async {
    await pumpUnlockedGarageLens(tester);

    await tester.tap(find.text('Insights'));
    await advance(tester);

    expect(find.text('TeslaMate insights'), findsOneWidget);
    expect(find.text('Dashboard groups'), findsOneWidget);
    expect(find.text('Vehicle live view'), findsOneWidget);
    expect(find.text('Charging analytics'), findsOneWidget);

    await tester.tap(find.text('Charging analytics'));
    await advance(tester);

    expect(find.text('Charge Level'), findsWidgets);
    expect(find.text('Charging Stats'), findsWidgets);
  }, skip: true);

  testWidgets('settings names the TeslaMate Reader API data source', (
    tester,
  ) async {
    await pumpUnlockedGarageLens(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Drives'), findsOneWidget);
    expect(find.text('Charges'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await advance(tester);

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Data source'), findsOneWidget);
    expect(find.text('TeslaMate Reader API'), findsOneWidget);
    expect(find.text('Reader API URL'), findsOneWidget);
    expect(find.text('Access token'), findsOneWidget);
    expect(find.text('Test & Save'), findsOneWidget);
    expect(find.text('Clear connection'), findsOneWidget);
  }, skip: true);

  testWidgets('opens drive detail and visited map pages', (tester) async {
    await pumpUnlockedGarageLens(tester);

    await tester.tap(find.text('Drives'));
    await advance(tester);

    await tester.tap(find.text('Visited Lifetime Map'));
    await advance(tester);

    expect(find.text('Lifetime routes'), findsOneWidget);
    expect(find.text('Visited Lifetime Map'), findsWidgets);

    await tester.pageBack();
    await advance(tester);

    await tester.tap(find.text('Palo Alto Office'));
    await advance(tester);

    expect(find.text('Drive detail'), findsOneWidget);
    expect(find.text('Route tracking'), findsOneWidget);
  }, skip: true);

  testWidgets('opens charge detail page', (tester) async {
    await pumpUnlockedGarageLens(tester);

    await tester.tap(find.text('Charges'));
    await advance(tester);

    await tester.tap(find.text('Supercharger Sunnyvale'));
    await advance(tester);

    expect(find.text('Charge detail'), findsOneWidget);
    expect(find.text('Charging power'), findsOneWidget);
    expect(find.text('Battery level'), findsOneWidget);
  }, skip: true);

  testWidgets('home cards open detail pages and coverage card is hidden', (
    tester,
  ) async {
    await pumpUnlockedGarageLens(tester);

    await tester.tap(find.text('Model Y').first);
    await advance(tester);

    expect(find.text('Vehicle detail'), findsOneWidget);

    await tester.pageBack();
    await advance(tester);

    await tester.tap(find.text('Distance'));
    await advance(tester);

    expect(find.text('Distance detail'), findsWidgets);

    await tester.pageBack();
    await advance(tester);

    await tester.tap(find.text('Insights'));
    await advance(tester);

    expect(find.text('Official screenshot coverage'), findsNothing);
  }, skip: true);
}
