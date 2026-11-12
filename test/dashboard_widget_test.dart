import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/features/dashboard/domain/entities/dashboard_filter.dart';
import 'package:rmpzd/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:rmpzd/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:rmpzd/features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';
import 'package:rmpzd/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:rmpzd/features/dashboard/presentation/widgets/dashboard_operation_view.dart';

void main() {
  testWidgets('operation view renders real aggregate sections', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _provider(_Repository(_stats(total: 12)));
    await provider.refresh();

    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    expect(find.text('Distribución por nivel de riesgo'), findsOneWidget);
    expect(find.text('Equidad por grupo étnico'), findsOneWidget);
    expect(find.text('Wayuu'), findsOneWidget);
    expect(find.textContaining('Alto riesgo: 25.0%'), findsOneWidget);
  });

  testWidgets('operation view shows a friendly empty state', (tester) async {
    final provider = _provider(_Repository(_stats(total: 0)));
    await provider.refresh();

    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    expect(
      find.text('No hay evaluaciones para estos filtros.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('dashboard-kpis')), findsNothing);
  });
}

Widget _app(DashboardProvider provider) => ChangeNotifierProvider.value(
  value: provider,
  child: const MaterialApp(home: Scaffold(body: DashboardOperationView())),
);

DashboardProvider _provider(_Repository repository) => DashboardProvider(
  getStats: GetDashboardStatsUseCase(repository),
  repository: repository,
);

DashboardStats _stats({required int total}) => DashboardStats(
  generatedAt: null,
  summary: DashboardSummary(
    total: total,
    highRisk: total == 0 ? 0 : 3,
    emergencies: 1,
    averageHighRiskProbability: 0.31,
    averageAdverseProbability: 0.2,
    withFollowUp: 4,
    activeDoctors: 2,
  ),
  riskSlices: const [
    RiskSlice(level: 'Bajo Riesgo', total: 5),
    RiskSlice(level: 'Riesgo Moderado', total: 4),
    RiskSlice(level: 'Alto Riesgo Obstétrico', total: 3),
  ],
  departments: const [],
  municipalities: const [],
  ethnicities: const [
    EthnicityStat(
      ethnicity: 'Wayuu',
      total: 12,
      highRisk: 3,
      emergencies: 1,
      averageHighRiskProbability: 0.31,
    ),
  ],
  zones: const [],
  dailyStats: [
    DailyStat(day: DateTime(2026, 11, 8), total: 3, highRisk: 1),
    DailyStat(day: DateTime(2026, 11, 9), total: 5, highRisk: 2),
    DailyStat(day: DateTime(2026, 11, 10), total: 4, highRisk: 0),
  ],
  doctors: const [],
  departmentOptions: const ['Cesar'],
);

class _Repository implements DashboardRepository {
  final DashboardStats _stats;

  const _Repository(this._stats);

  @override
  Future<DashboardStats> getStats(DashboardFilter filter) async => _stats;

  @override
  Future<DashboardCacheEntry?> getCachedStats(DashboardFilter filter) async =>
      null;
}
