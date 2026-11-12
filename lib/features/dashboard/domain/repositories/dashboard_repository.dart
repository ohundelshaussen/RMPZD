import '../entities/dashboard_filter.dart';
import '../entities/dashboard_stats.dart';

class DashboardCacheEntry {
  final DashboardStats stats;
  final DateTime cachedAt;

  const DashboardCacheEntry({required this.stats, required this.cachedAt});
}

class DashboardRequestFailure implements Exception {
  final String? code;
  final String message;

  const DashboardRequestFailure({required this.code, required this.message});

  @override
  String toString() => message;
}

abstract interface class DashboardRepository {
  Future<DashboardStats> getStats(DashboardFilter filter);

  Future<DashboardCacheEntry?> getCachedStats(DashboardFilter filter);
}
