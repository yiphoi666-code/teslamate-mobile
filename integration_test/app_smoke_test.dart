import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:teslamate_mobile/app.dart';
import 'package:teslamate_mobile/data/reader_api_client.dart';
import 'package:teslamate_mobile/data/reader_api_config_store.dart';

class MemoryReaderApiConfigStore extends ReaderApiConfigStore {
  MemoryReaderApiConfigStore() : super();

  ReaderApiConfig _config = ReaderApiConfig.empty();

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connect reader screen accepts URL and token input', (
    tester,
  ) async {
    await tester.pumpWidget(
      GarageLensApp(configStore: MemoryReaderApiConfigStore()),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Connect Reader'), findsOneWidget);
    expect(find.text('TeslaMate Reader API'), findsOneWidget);
    expect(find.text('Reader API URL'), findsOneWidget);
    expect(find.text('Access token'), findsOneWidget);
    expect(find.text('Test & Save'), findsOneWidget);

    await tester.enterText(
      find.byType(EditableText).first,
      'https://reader.example.com',
    );
    await tester.enterText(find.byType(EditableText).last, 'token');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('https://reader.example.com'), findsOneWidget);
    expect(find.text('Test & Save'), findsOneWidget);
  });
}
