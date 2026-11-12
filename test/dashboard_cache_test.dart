import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/features/dashboard/data/datasources/dashboard_local_cache.dart';
import 'package:rmpzd/features/dashboard/domain/entities/dashboard_filter.dart';
import 'package:rmpzd/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'stores the latest response separately for each filter combination',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = DashboardLocalCache(preferences: preferences);
      final filter = const DashboardFilter(
        period: DashboardPeriod.days7,
        department: 'Cesar',
      );
      final cachedAt = DateTime(2026, 11, 11, 12);
      final stats = DashboardStats(
        generatedAt: DateTime(2026, 11, 11),
        summary: const DashboardSummary(
          total: 14,
          highRisk: 3,
          emergencies: 1,
          averageHighRiskProbability: 0.4,
          averageAdverseProbability: 0.2,
          withFollowUp: 5,
          activeDoctors: 2,
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

      await cache.write(filter, stats, cachedAt);

      final cached = await cache.read(filter);
      expect(cached?.cachedAt, cachedAt);
      expect(cached?.stats.summary.total, 14);
      expect(
        await cache.read(
          const DashboardFilter(
            period: DashboardPeriod.days7,
            department: 'La Guajira',
          ),
        ),
        isNull,
      );
    },
  );
}
