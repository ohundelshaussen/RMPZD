import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/entities/dashboard_filter.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/dashboard_trend.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_stats_usecase.dart';

enum DashboardLoadState { loading, loaded, error }

class DashboardProvider extends ChangeNotifier {
  final GetDashboardStatsUseCase getStats;
  final DashboardRepository repository;

  DashboardProvider({
    required this.getStats,
    required this.repository,
  });

  DashboardFilter _filter = const DashboardFilter();
  DashboardFilter get filter => _filter;

  DashboardLoadState _state = DashboardLoadState.loading;
  DashboardLoadState get state => _state;

  DashboardStats? _stats;
  DashboardStats? get stats => _stats;

  bool _isFromCache = false;
  bool get isFromCache => _isFromCache;

  DateTime? _cachedAt;
  DateTime? get cachedAt => _cachedAt;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<DailyStat> get trendStats {
    final daily = _stats?.dailyStats ?? const <DailyStat>[];
    return _filter.shouldGroupWeekly ? groupDailyStatsByWeek(daily) : daily;
  }

  Future<void> setPeriod(DashboardPeriod period) async {
    if (_filter.period == period) return;
    _filter = _filter.copyWith(period: period);
    await refresh();
  }

  Future<void> setDepartment(String? department) async {
    if (_filter.department == department) return;
    _filter = _filter.copyWith(
      department: department,
      clearDepartment: department == null,
    );
    await refresh();
  }

  Future<void> refresh() async {
    final requestFilter = _filter;
    final requestId = ++_requestId;
    _state = DashboardLoadState.loading;
    _errorMessage = null;
    _isFromCache = false;
    notifyListeners();

    try {
      final result = await getStats.execute(requestFilter);
      if (requestId != _requestId) return;
      _stats = result;
      _cachedAt = DateTime.now();
      _state = DashboardLoadState.loaded;
    } catch (error) {
      if (requestId != _requestId) return;
      if (_isPermissionError(error)) {
        _state = DashboardLoadState.error;
        _errorMessage = 'No tienes permisos para ver el dashboard.';
      } else if (_isNetworkError(error)) {
        await _loadCacheOrNetworkError(requestFilter, requestId);
      } else {
        _state = DashboardLoadState.error;
        _errorMessage = 'No se pudo cargar el dashboard: $error';
      }
    }
    if (requestId == _requestId) notifyListeners();
  }

  int _requestId = 0;

  Future<void> _loadCacheOrNetworkError(
    DashboardFilter filter,
    int requestId,
  ) async {
    try {
      final cached = await repository.getCachedStats(filter);
      if (requestId != _requestId) return;
      if (cached == null) {
        _state = DashboardLoadState.error;
        _errorMessage = 'Se requiere conexión a internet.';
        return;
      }
      _stats = cached.stats;
      _cachedAt = cached.cachedAt;
      _isFromCache = true;
      _state = DashboardLoadState.loaded;
    } catch (cacheError) {
      _state = DashboardLoadState.error;
      _errorMessage =
          'Se requiere conexión a internet y no se pudo leer el caché: '
          '$cacheError';
    }
  }

  bool _isPermissionError(Object error) {
    if (error is DashboardRequestFailure) return error.code == '42501';
    final message = error.toString();
    return message.contains('42501');
  }

  bool _isNetworkError(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('clientexception') ||
        text.contains('timed out');
  }
}
