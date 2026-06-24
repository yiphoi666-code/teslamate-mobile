import 'package:flutter/material.dart';

import '../data/reader_api_client.dart';
import '../models/teslamate_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.data,
    required this.readerApiConfig,
    required this.usingRemoteData,
    required this.dataSourceError,
    required this.onReaderApiConfigSaved,
    required this.onReaderApiConfigCleared,
    this.compact = false,
    this.header,
    this.closeOnSuccess = true,
    super.key,
  });

  final TeslamateDashboardData data;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;
  final String? dataSourceError;
  final Future<void> Function(ReaderApiConfig config) onReaderApiConfigSaved;
  final Future<void> Function() onReaderApiConfigCleared;
  final bool compact;
  final Widget? header;
  final bool closeOnSuccess;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _testing = false;
  bool _testSucceeded = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.readerApiConfig.baseUrl,
    );
    _tokenController = TextEditingController(
      text: widget.readerApiConfig.accessToken,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _testAndSaveReaderApi() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _testing = true;
      _testSucceeded = false;
      _testMessage = null;
    });

    try {
      final config = _typedConfig();
      final client = ReaderApiClient(config: config);
      await client.testConnection();
      if (mounted) {
        setState(() {
          _testSucceeded = true;
          _testMessage = 'Reader verified. Loading vehicle data...';
        });
      }
      await widget.onReaderApiConfigSaved(config);

      if (mounted && widget.closeOnSuccess && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _testSucceeded = false;
          _testMessage = 'Connection failed: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _clearConnection() async {
    await widget.onReaderApiConfigCleared();
    if (mounted && widget.closeOnSuccess && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  ReaderApiConfig _typedConfig() {
    final config = ReaderApiConfig(
      baseUrl: _urlController.text,
      accessToken: _tokenController.text,
    ).normalized;
    final uri = Uri.tryParse(config.baseUrl);
    final validUrl =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    if (!config.isConfigured || !validUrl) {
      throw const ReaderApiException(
        'Enter a valid http or https Reader API URL.',
      );
    }

    return config;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (widget.header != null) ...[
          widget.header!,
          const SizedBox(height: 16),
        ],
        Text('Data source', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TeslaMate Reader API',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste your Reader API URL and access token. The app verifies these first, then loads TeslaMate data in batches.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Chip(
                  avatar: Icon(_dataSourceIcon(), size: 18),
                  label: Text(_dataSourceLabel()),
                  visualDensity: VisualDensity.compact,
                ),
                if (widget.dataSourceError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.dataSourceError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  enabled: !_testing,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Reader API URL',
                    hintText: 'https://reader.example.com',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tokenController,
                  enabled: !_testing,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Access token',
                    prefixIcon: Icon(Icons.key),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_testMessage != null) ...[
                  _ConnectionStatusMessage(
                    succeeded: _testSucceeded,
                    message: _testMessage!,
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _testing ? null : _testAndSaveReaderApi,
                      icon: _testing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_sync),
                      label: Text(_testing ? 'Testing' : 'Test & Save'),
                    ),
                    if (widget.readerApiConfig.isConfigured)
                      TextButton.icon(
                        onPressed: _testing ? null : _clearConnection,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Clear connection'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.compact)
          const SizedBox.shrink()
        else ...[
          const SizedBox(height: 18),
          Text('Display', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: true,
                  onChanged: (_) {},
                  secondary: const Icon(Icons.speed),
                  title: const Text('Metric units'),
                  subtitle: const Text('km, kWh, Wh/km'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: false,
                  onChanged: (_) {},
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Charging alerts'),
                  subtitle: const Text('Notify when a session completes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Garage Lens'),
              subtitle: Text(
                'A mobile viewer for self-hosted TeslaMate Reader API data. Current vehicle: ${widget.data.vehicle.displayName}.',
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _dataSourceIcon() {
    if (widget.usingRemoteData) {
      return Icons.cloud_done;
    }

    if (widget.readerApiConfig.isConfigured) {
      return Icons.cloud_off;
    }

    return Icons.data_object;
  }

  String _dataSourceLabel() {
    if (widget.usingRemoteData) {
      return 'Remote data';
    }

    if (widget.readerApiConfig.isConfigured) {
      return 'Connection issue';
    }

    return 'Data hidden';
  }
}

class _ConnectionStatusMessage extends StatelessWidget {
  const _ConnectionStatusMessage({
    required this.succeeded,
    required this.message,
  });

  final bool succeeded;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = succeeded ? scheme.primary : scheme.error;
    final background = succeeded
        ? scheme.primaryContainer.withValues(alpha: 0.35)
        : scheme.errorContainer.withValues(alpha: 0.35);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            succeeded ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
