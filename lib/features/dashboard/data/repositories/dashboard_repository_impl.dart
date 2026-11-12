import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/dashboard_filter.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_cache.dart';
import '../datasources/dashboard_remote_data_source.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource remoteDataSource;
  final DashboardLocalCache localCache;

  const DashboardRepositoryImpl({
    required this.remoteDataSource,
    required this.localCache,
  });

  @override
  Future<DashboardStats> getStats(DashboardFilter filter) async {
    try {
      final stats = await remoteDataSource.fetchStats(filter);
      await localCache.write(filter, stats, DateTime.now());
      return stats;
    } on PostgrestException catch (error) {
      throw DashboardRequestFailure(code: error.code, message: error.message);
    }
  }

  @override
  Future<DashboardCacheEntry?> getCachedStats(DashboardFilter filter) =>
      localCache.read(filter);
}
