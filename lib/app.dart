import 'package:flutter/material.dart';

import 'data/reader_api_config_store.dart';
import 'data/reader_api_client.dart';
import 'data/teslamate_repository.dart';
import 'models/teslamate_models.dart';
import 'screens/charges_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/drives_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

class GarageLensApp extends StatefulWidget {
  const GarageLensApp({this.configStore, super.key});

  final ReaderApiConfigStore? configStore;

  @override
  State<GarageLensApp> createState() => _GarageLensAppState();
}

class _GarageLensAppState extends State<GarageLensApp> {
  late final ReaderApiConfigStore _configStore;
  ReaderApiConfig _readerApiConfig = ReaderApiConfig.empty();
  bool _usingRemoteData = false;
  bool _isLocked = false;
  bool _isRefreshingData = false;
  String? _dataSourceError;
  late Future<TeslamateDashboardData> _dashboardFuture;
  TeslamateDashboardData? _dashboardData;

  @override
  void initState() {
    super.initState();
    _configStore = widget.configStore ?? ReaderApiConfigStore();
    _dashboardFuture = _loadDashboard();
  }

  Future<TeslamateDashboardData> _loadDashboard({
    ReaderApiConfig? overrideConfig,
  }) async {
    final config = overrideConfig ?? await _configStore.load();
    _readerApiConfig = config.normalized;
    _dataSourceError = null;

    if (_readerApiConfig.isConfigured) {
      try {
        final data = await _loadRemoteDashboardFirstBatch(_readerApiConfig);
        _usingRemoteData = true;
        _isLocked = false;
        _dashboardData = data;
        Future<void>.microtask(
          () => _refreshDashboardBatches(_readerApiConfig),
        );
        return data;
      } catch (error) {
        _usingRemoteData = false;
        _isLocked = _dashboardData == null;
        _dataSourceError = error.toString();
        if (_dashboardData != null) {
          return _dashboardData!;
        }
      }
    } else {
      _usingRemoteData = false;
      _isLocked = true;
    }

    final lockedData = await LockedTeslamateRepository().loadDashboard();
    _dashboardData = lockedData;
    return lockedData;
  }

  Future<void> _saveReaderApiConfig(ReaderApiConfig config) async {
    final normalized = config.normalized;
    await _configStore.save(normalized);
    setState(() {
      _readerApiConfig = normalized;
      _usingRemoteData = false;
      _isLocked = false;
      _isRefreshingData = false;
      _dataSourceError = null;
      _dashboardFuture = _loadDashboard(overrideConfig: normalized);
    });
  }

  Future<void> _clearReaderApiConfig() async {
    await _configStore.clear();
    setState(() {
      _dashboardData = null;
      _dashboardFuture = _loadDashboard(
        overrideConfig: ReaderApiConfig.empty(),
      );
    });
  }

  Future<TeslamateDashboardData> _loadRemoteDashboardFirstBatch(
    ReaderApiConfig config,
  ) async {
    await for (final data in RemoteTeslamateRepository(
      config: config,
    ).loadDashboardBatches()) {
      return data;
    }

    throw const ReaderApiException('Reader API did not return dashboard data.');
  }

  Future<void> _refreshDashboardBatches(ReaderApiConfig config) async {
    if (_isRefreshingData) {
      return;
    }

    setState(() {
      _isRefreshingData = true;
      _dataSourceError = null;
    });

    try {
      await for (final data in RemoteTeslamateRepository(
        config: config,
      ).loadDashboardBatches()) {
        if (!mounted) {
          return;
        }
        setState(() {
          _dashboardData = data;
          _dashboardFuture = Future.value(data);
          _usingRemoteData = true;
          _isLocked = false;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dataSourceError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshingData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garage Lens',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: FutureBuilder<TeslamateDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _LoadError();
          }

          if (!snapshot.hasData) {
            return const _LoadingShell();
          }

          return HomeShell(
            data: snapshot.data!,
            readerApiConfig: _readerApiConfig,
            usingRemoteData: _usingRemoteData,
            isLocked: _isLocked,
            isRefreshingData: _isRefreshingData,
            dataSourceError: _dataSourceError,
            onReaderApiConfigSaved: _saveReaderApiConfig,
            onReaderApiConfigCleared: _clearReaderApiConfig,
          );
        },
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.data,
    required this.readerApiConfig,
    required this.usingRemoteData,
    required this.isLocked,
    required this.isRefreshingData,
    required this.dataSourceError,
    required this.onReaderApiConfigSaved,
    required this.onReaderApiConfigCleared,
    super.key,
  });

  final TeslamateDashboardData data;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;
  final bool isLocked;
  final bool isRefreshingData;
  final String? dataSourceError;
  final Future<void> Function(ReaderApiConfig config) onReaderApiConfigSaved;
  final Future<void> Function() onReaderApiConfigCleared;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Overview',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route),
      label: 'Drives',
    ),
    NavigationDestination(
      icon: Icon(Icons.bolt_outlined),
      selectedIcon: Icon(Icons.bolt),
      label: 'Charges',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: 'Insights',
    ),
  ];

  String get _title {
    if (widget.isLocked) {
      return 'Connect Reader';
    }

    return switch (_index) {
      0 => 'Overview',
      1 => 'Drives',
      2 => 'Charging',
      _ => 'Insights',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLocked) {
      return LockedHomeShell(
        data: widget.data,
        readerApiConfig: widget.readerApiConfig,
        usingRemoteData: widget.usingRemoteData,
        dataSourceError: widget.dataSourceError,
        onReaderApiConfigSaved: widget.onReaderApiConfigSaved,
        onReaderApiConfigCleared: widget.onReaderApiConfigCleared,
      );
    }

    final pages = [
      DashboardScreen(
        data: widget.data,
        readerApiConfig: widget.readerApiConfig,
        usingRemoteData: widget.usingRemoteData,
      ),
      DrivesScreen(
        data: widget.data,
        readerApiConfig: widget.readerApiConfig,
        usingRemoteData: widget.usingRemoteData,
      ),
      ChargesScreen(
        data: widget.data,
        readerApiConfig: widget.readerApiConfig,
        usingRemoteData: widget.usingRemoteData,
      ),
      InsightsScreen(data: widget.data),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.tonalIcon(
              onPressed: _openSettings,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Settings'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.isRefreshingData) const LinearProgressIndicator(),
            Expanded(
              child: IndexedStack(index: _index, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: _destinations,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            child: SettingsScreen(
              data: widget.data,
              readerApiConfig: widget.readerApiConfig,
              usingRemoteData: widget.usingRemoteData,
              dataSourceError: widget.dataSourceError,
              onReaderApiConfigSaved: widget.onReaderApiConfigSaved,
              onReaderApiConfigCleared: widget.onReaderApiConfigCleared,
            ),
          ),
        ),
      ),
    );
  }
}

class LockedHomeShell extends StatelessWidget {
  const LockedHomeShell({
    required this.data,
    required this.readerApiConfig,
    required this.usingRemoteData,
    required this.dataSourceError,
    required this.onReaderApiConfigSaved,
    required this.onReaderApiConfigCleared,
    super.key,
  });

  final TeslamateDashboardData data;
  final ReaderApiConfig readerApiConfig;
  final bool usingRemoteData;
  final String? dataSourceError;
  final Future<void> Function(ReaderApiConfig config) onReaderApiConfigSaved;
  final Future<void> Function() onReaderApiConfigCleared;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Reader')),
      body: SafeArea(
        child: SettingsScreen(
          data: data,
          readerApiConfig: readerApiConfig,
          usingRemoteData: usingRemoteData,
          dataSourceError: dataSourceError,
          onReaderApiConfigSaved: onReaderApiConfigSaved,
          onReaderApiConfigCleared: onReaderApiConfigCleared,
          compact: true,
          header: _LockedHero(dataSourceError: dataSourceError),
          closeOnSuccess: false,
        ),
      ),
    );
  }
}

class _LockedHero extends StatelessWidget {
  const _LockedHero({required this.dataSourceError});

  final String? dataSourceError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17211F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: scheme.primaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data hidden',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Enter and verify a Reader API URL and access token to show TeslaMate data.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _LockedPill(label: 'Vehicle hidden'),
              _LockedPill(label: 'Trips hidden'),
              _LockedPill(label: 'Charging hidden'),
              _LockedPill(label: 'Charts hidden'),
            ],
          ),
          if (dataSourceError != null) ...[
            const SizedBox(height: 12),
            Text(
              dataSourceError!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.errorContainer),
            ),
          ],
        ],
      ),
    );
  }
}

class _LockedPill extends StatelessWidget {
  const _LockedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.visibility_off, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Loading TeslaMate data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 16),
              Text(
                'Could not load data',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Check the TeslaMate Reader API service and try again.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
