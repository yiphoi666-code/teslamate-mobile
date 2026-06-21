import 'dart:convert';
import 'dart:io';

import 'reader_api_client.dart';

class ReaderApiConfigStore {
  ReaderApiConfigStore({File? file}) : _file = file ?? _defaultFile();

  final File _file;

  Future<ReaderApiConfig> load() async {
    try {
      if (!await _file.exists()) {
        return ReaderApiConfig.empty();
      }

      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return ReaderApiConfig.fromJson(decoded).normalized;
      }
    } catch (_) {
      return ReaderApiConfig.empty();
    }

    return ReaderApiConfig.empty();
  }

  Future<void> save(ReaderApiConfig config) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(config.normalized.toJson()));
  }

  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  static File _defaultFile() {
    if (Platform.isAndroid) {
      return File(
        '/data/user/0/com.kaylabs.teslamate_mobile/files/reader_api_config.json',
      );
    }

    return File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}garage_lens'
      '${Platform.pathSeparator}reader_api_config.json',
    );
  }
}
