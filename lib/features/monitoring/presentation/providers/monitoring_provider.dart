import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/case_remote_data_source.dart';
import '../../data/services/monitoring_notification_service.dart';
import '../../domain/entities/monitoring_case.dart';

class MonitoringProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const pageSize = 50;

  final CaseRemoteDataSource caseRemoteDataSource;
  final MonitoringNotificationService notificationService;
  final AuthProvider authProvider;
  final Future<void> Function() syncFacilityCatalog;

  List<MonitoringCase> _newCases = const [];
  List<MonitoringCase> get newCases => _newCases;

  List<MonitoringCase> _myCases = const [];
  List<MonitoringCase> get myCases => _myCases;

  List<MonitoringCase> _closedCases = const [];
  List<MonitoringCase> get closedCases => _closedCases;

  int _newCasesCount = 0;
  int get newCasesCount => _newCasesCount;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _notificationErrorMessage;
  String? get notificationErrorMessage => _notificationErrorMessage;

  bool _newCasesHaveMore = false;
  bool _myCasesHaveMore = false;
  bool get newCasesHaveMore => _newCasesHaveMore;
  bool get myCasesHaveMore => _myCasesHaveMore;

  bool _loadingMoreNew = false;
  bool _loadingMoreMine = false;
  bool get loadingMoreNew => _loadingMoreNew;
  bool get loadingMoreMine => _loadingMoreMine;

  bool _active = false;
  bool _isRefreshing = false;
  bool _refreshAgain = false;
  bool _hasConnectedOnce = false;
  int _sessionGeneration = 0;
  String? _activeMonitorId;
  String? _pendingCaseId;
  final Set<String> _alertedCaseIds = {};
  StreamSubscription<MonitoringCaseChange>? _changesSubscription;
  StreamSubscription<String>? _openedCasesSubscription;
  final StreamController<MonitoringAlert> _alerts =
      StreamController<MonitoringAlert>.broadcast();
  final StreamController<String> _caseOpenRequests =
      StreamController<String>.broadcast();

  Stream<MonitoringAlert> get alerts => _alerts.stream;
  Stream<String> get caseOpenRequests => _caseOpenRequests.stream;

  MonitoringProvider({
    required this.caseRemoteDataSource,
    required this.notificationService,
    required this.authProvider,
    required this.syncFacilityCatalog,
  }) {
    WidgetsBinding.instance.addObserver(this);
    authProvider.addListener(_onAuthChanged);
    _changesSubscription = caseRemoteDataSource.changes.listen(
      _onCaseChanged,
      onError: (Object _) => _setConnection(false),
    );
    _onAuthChanged();
  }

  String? takePendingCaseId() {
    final caseId = _pendingCaseId;
    _pendingCaseId = null;
    return caseId;
  }

  List<MonitoringCase> casesFor(MonitoringCaseStatus status) =>
      switch (status) {
        MonitoringCaseStatus.nuevo => _newCases,
        MonitoringCaseStatus.enGestion => _myCases,
        MonitoringCaseStatus.cerrado => _closedCases,
      };

  Future<void> refreshLists() async {
    if (!_active || _activeMonitorId == null) return;
    if (_isRefreshing) {
      _refreshAgain = true;
      return;
    }

    _isRefreshing = true;
    _isLoading = true;
    notifyListeners();
    do {
      _refreshAgain = false;
      final monitorId = _activeMonitorId;
      if (!_active || monitorId == null) break;
      try {
        final results = await Future.wait<Object>([
          caseRemoteDataSource.fetchCases(
            status: MonitoringCaseStatus.nuevo,
            offset: 0,
            limit: pageSize,
          ),
          caseRemoteDataSource.fetchCases(
            status: MonitoringCaseStatus.enGestion,
            assignedTo: monitorId,
            offset: 0,
            limit: pageSize,
          ),
          caseRemoteDataSource.fetchCases(
            status: MonitoringCaseStatus.cerrado,
            closedBy: monitorId,
            offset: 0,
            limit: pageSize,
          ),
          caseRemoteDataSource.fetchNewCasesCount(),
        ]);
        if (!_active || _activeMonitorId != monitorId) continue;
        _newCases = _sorted(results[0] as List<MonitoringCase>);
        _myCases = _sorted(results[1] as List<MonitoringCase>);
        _closedCases = _sortClosed(results[2] as List<MonitoringCase>);
        _newCasesCount = results[3] as int;
        _newCasesHaveMore = _newCases.length == pageSize;
        _myCasesHaveMore = _myCases.length == pageSize;
        _errorMessage = null;
      } on Object {
        _errorMessage = 'No se pudieron cargar las alertas.';
      }
    } while (_refreshAgain && _active);
    _isLoading = false;
    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> loadMore(MonitoringCaseStatus status) async {
    if (!_active || _isRefreshing || status == MonitoringCaseStatus.cerrado) {
      return;
    }
    final isNew = status == MonitoringCaseStatus.nuevo;
    if ((isNew && (!_newCasesHaveMore || _loadingMoreNew)) ||
        (!isNew && (!_myCasesHaveMore || _loadingMoreMine))) {
      return;
    }
    if (isNew) {
      _loadingMoreNew = true;
    } else {
      _loadingMoreMine = true;
    }
    notifyListeners();

    try {
      final current = casesFor(status);
      final fetched = await caseRemoteDataSource.fetchCases(
        status: status,
        assignedTo: isNew ? null : _activeMonitorId,
        offset: current.length,
        limit: pageSize,
      );
      if (_active) {
        final merged = _deduplicate([...current, ...fetched]);
        if (isNew) {
          _newCases = _sorted(merged);
          _newCasesHaveMore = fetched.length == pageSize;
        } else {
          _myCases = _sorted(merged);
          _myCasesHaveMore = fetched.length == pageSize;
        }
      }
    } on Object {
      _errorMessage = 'No se pudieron cargar más alertas.';
    } finally {
      _loadingMoreNew = false;
      _loadingMoreMine = false;
      notifyListeners();
    }
  }

  void _onAuthChanged() {
    final profile = authProvider.profile;
    if (profile?.role == UserRole.monitor && profile!.active) {
      if (_activeMonitorId == profile.id && _active) return;
      unawaited(_startMonitorSession(profile.id));
    } else if (_active) {
      unawaited(_stopMonitorSession());
    }
  }

  Future<void> _startMonitorSession(String monitorId) async {
    final generation = ++_sessionGeneration;
    if (_active) await _stopMonitorSession(invalidate: false);
    if (!_isCurrentMonitorSession(monitorId, generation)) return;
    _active = true;
    _activeMonitorId = monitorId;
    _isConnected = false;
    _hasConnectedOnce = false;
    _errorMessage = null;
    _notificationErrorMessage = null;
    notifyListeners();

    _openedCasesSubscription = notificationService.openedCaseIds.listen(
      _caseOpenRequests.add,
    );
    try {
      await notificationService.initialize();
      await notificationService.requestPermission();
      if (!_isCurrentMonitorSession(monitorId, generation)) return;
      _pendingCaseId = notificationService.takeInitialCaseId();
      if (_pendingCaseId != null) {
        _caseOpenRequests.add(_pendingCaseId!);
      }
    } on Object {
      _notificationErrorMessage =
          'No se pudieron habilitar las notificaciones.';
    }

    try {
      await caseRemoteDataSource.startRealtime(
        onConnectionChanged: _onConnectionChanged,
      );
    } on Object {
      _setConnection(false);
      _errorMessage = 'No se pudo conectar con las alertas en tiempo real.';
    }
    if (!_isCurrentMonitorSession(monitorId, generation)) return;
    try {
      await syncFacilityCatalog();
    } on Object {
      _errorMessage = 'No se pudo descargar el catálogo de centros.';
    }
    await refreshLists();
  }

  bool _isCurrentMonitorSession(String monitorId, int generation) =>
      generation == _sessionGeneration &&
      authProvider.profile?.role == UserRole.monitor &&
      authProvider.profile?.id == monitorId;

  Future<void> _stopMonitorSession({bool invalidate = true}) async {
    if (invalidate) _sessionGeneration++;
    _active = false;
    _activeMonitorId = null;
    _isConnected = false;
    _hasConnectedOnce = false;
    _pendingCaseId = null;
    _alertedCaseIds.clear();
    _newCases = const [];
    _myCases = const [];
    _closedCases = const [];
    _newCasesCount = 0;
    _isLoading = false;
    _newCasesHaveMore = false;
    _myCasesHaveMore = false;
    _errorMessage = null;
    _notificationErrorMessage = null;
    final openedCasesSubscription = _openedCasesSubscription;
    _openedCasesSubscription = null;
    notifyListeners();
    await caseRemoteDataSource.stopRealtime();
    await openedCasesSubscription?.cancel();
  }

  void _onConnectionChanged(bool connected) {
    if (!_active) return;
    final wasConnected = _isConnected;
    _setConnection(connected);
    if (connected && _hasConnectedOnce && !wasConnected) {
      unawaited(refreshLists());
    }
    if (connected) _hasConnectedOnce = true;
  }

  void _setConnection(bool connected) {
    if (_isConnected == connected) return;
    _isConnected = connected;
    notifyListeners();
  }

  void _onCaseChanged(MonitoringCaseChange change) {
    if (!_active) return;
    final item = change.current;
    if (change.type == MonitoringChangeType.insert &&
        item != null &&
        _alertedCaseIds.add(change.caseId)) {
      final alert = MonitoringAlert.fromCase(item);
      _alerts.add(alert);
      unawaited(_showNotification(alert));
    }
    unawaited(refreshLists());
  }

  Future<void> _showNotification(MonitoringAlert alert) async {
    try {
      await notificationService.show(alert);
    } on Object {
      _notificationErrorMessage =
          'No se pudo mostrar la notificación de alerta.';
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active) {
      unawaited(refreshLists());
    }
  }

  static List<MonitoringCase> _sorted(List<MonitoringCase> cases) {
    final unique = _deduplicate(cases);
    unique.sort((left, right) {
      final priority = left.priority.index.compareTo(right.priority.index);
      return priority != 0
          ? priority
          : left.createdAt.compareTo(right.createdAt);
    });
    return unique;
  }

  static List<MonitoringCase> _sortClosed(List<MonitoringCase> cases) {
    final unique = _deduplicate(cases);
    unique.sort(
      (left, right) => (right.closedAt ?? right.createdAt).compareTo(
        left.closedAt ?? left.createdAt,
      ),
    );
    return unique;
  }

  static List<MonitoringCase> _deduplicate(List<MonitoringCase> cases) {
    final byId = <String, MonitoringCase>{};
    for (final item in cases) {
      byId[item.id] = item;
    }
    return byId.values.toList();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    authProvider.removeListener(_onAuthChanged);
    unawaited(_changesSubscription?.cancel());
    unawaited(_openedCasesSubscription?.cancel());
    unawaited(caseRemoteDataSource.stopRealtime());
    unawaited(_alerts.close());
    unawaited(_caseOpenRequests.close());
    super.dispose();
  }
}
