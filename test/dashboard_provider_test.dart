import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/features/dashboard/domain/entities/dashboard_filter.dart';
import 'package:rmpzd/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:rmpzd/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:rmpzd/features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';
import 'package:rmpzd/features/dashboard/presentation/providers/dashboard_provider.dart';

void main() {
  test('loads successfully and reloads when filters change', () async {
    final repository = _FakeRepository(stats: _stats(total: 5));
    final provider = _provider(repository);

    await provider.refresh();
    expect(provider.state, DashboardLoadState.loaded);
    expect(provider.stats?.summary.total, 5);

    await provider.setPeriod(DashboardPeriod.days90);
    await provider.setDepartment('Cesar');
    expect(repository.requestedFilters, hasLength(3));
    expect(repository.requestedFilters[1].period, DashboardPeriod.days90);
    expect(repository.requestedFilters[2].department, 'Cesar');
  });

  test('maps permission failures to a clear message', () async {
    final repository = _FakeRepository(
      error: const DashboardRequestFailure(code: '42501', message: 'denied'),
    );
    final provider = _provider(repository);

    await provider.refresh();

    expect(provider.state, DashboardLoadState.error);
    expect(provider.errorMessage, 'No tienes permisos para ver el dashboard.');
  });

  test('uses the cache after a network error and reports its timestamp', () async {
    final cachedAt = DateTime(2026, 11, 10, 12);
    final repository = _FakeRepository(
      error: const SocketException('offline'),
      cached: DashboardCacheEntry(stats: _stats(total: 7), cachedAt: cachedAt),
    );
    final provider = _provider(repository);

    await provider.refresh();

    expect(provider.state, DashboardLoadState.loaded);
    expect(provider.isFromCache, isTrue);
    expect(provider.cachedAt, cachedAt);
    expect(provider.stats?.summary.total, 7);
  });

  test('shows a connection error when no cache is available', () async {
    final provider = _provider(
      _FakeRepository(error: const SocketException('offline')),
    );

    await provider.refresh();

    expect(provider.state, DashboardLoadState.error);
    expect(provider.errorMessage, 'Se requiere conexión a internet.');
  });
}

DashboardProvider _provider(_FakeRepository repository) => DashboardProvider(
  getStats: GetDashboardStatsUseCase(repository),
  repository: repository,
);

DashboardStats _stats({required int total}) => DashboardStats(
  generatedAt: null,
  summary: DashboardSummary(
    total: total,
    highRisk: 1,
    emergencies: 0,
    averageHighRiskProbability: 0.2,
    averageAdverseProbability: 0.1,
    withFollowUp: 2,
    activeDoctors: 1,
  ),
  riskSlices: const [],
  departments: const [],
  municipalities: const [],
  ethnicities: const [],
  zones: const [],
  dailyStats: const [],
  doctors: const [],
  departmentOptions: const ['Cesar'],
);

class _FakeRepository implements DashboardRepository {
  final List<DashboardFilter> requestedFilters = [];
  final DashboardStats? result;
  final Object? error;
  final DashboardCacheEntry? cached;

  _FakeRepository({DashboardStats? stats, this.error, this.cached})
    : result = stats;

  @override
  Future<DashboardStats> getStats(DashboardFilter filter) async {
    requestedFilters.add(filter);
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<DashboardCacheEntry?> getCachedStats(DashboardFilter filter) async =>
      cached;
}
