import '../entities/dashboard_filter.dart';
import '../entities/dashboard_stats.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardStatsUseCase {
  final DashboardRepository _repository;

  const GetDashboardStatsUseCase(this._repository);

  Future<DashboardStats> execute(DashboardFilter filter) =>
      _repository.getStats(filter);
}
