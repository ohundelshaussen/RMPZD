import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/features/dashboard/domain/entities/dashboard_filter.dart';
import 'package:rmpzd/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:rmpzd/features/dashboard/domain/entities/dashboard_trend.dart';

void main() {
  group('DashboardStats.fromJson', () {
    test('parses the complete RPC response', () {
      final stats = DashboardStats.fromJson(_completeResponse);

      expect(stats.summary.total, 20);
      expect(stats.summary.averageHighRiskProbability, 0.37);
      expect(stats.riskSlices.single.level, 'Alto Riesgo Obstétrico');
      expect(stats.departments.single.name, 'Cesar');
      expect(stats.municipalities.single.department, 'Cesar');
      expect(stats.ethnicities.single.ethnicity, 'Wayuu');
      expect(stats.zones.single.name, 'Rural');
      expect(stats.dailyStats.single.day, DateTime(2026, 11, 10));
      expect(stats.doctors.single.lastEvaluation, isNotNull);
      expect(stats.departmentOptions, ['Cesar']);
    });

    test('accepts empty lists, nulls and integers in decimal fields', () {
      final stats = DashboardStats.fromJson({
        'generado_en': null,
        'resumen': {
          'total': null,
          'alto_riesgo': 0,
          'prob_alto_promedio': 1,
          'prob_adverso_promedio': null,
        },
        'por_riesgo': [],
        'por_departamento': null,
        'por_municipio': [],
        'por_etnia': [],
        'por_zona': [],
        'por_dia': [],
        'por_medico': [],
        'departamentos': null,
      });

      expect(stats.generatedAt, isNull);
      expect(stats.summary.total, 0);
      expect(stats.summary.averageHighRiskProbability, 1.0);
      expect(stats.summary.averageHighRiskProbability, isA<double>());
      expect(stats.summary.averageAdverseProbability, 0.0);
      expect(stats.riskSlices, isEmpty);
      expect(stats.departments, isEmpty);
      expect(stats.departmentOptions, isEmpty);
    });
  });

  test('builds local calendar boundaries and nulls for all-time filter', () {
    final params = const DashboardFilter(
      period: DashboardPeriod.days7,
      department: 'Cesar',
    ).toRpcParams(now: DateTime(2026, 11, 11, 15));

    expect(params['p_from'], DateTime(2026, 11, 5).toUtc().toIso8601String());
    expect(
      params['p_to'],
      DateTime(2026, 11, 12).toUtc().toIso8601String(),
    );
    expect(params['p_departamento'], 'Cesar');

    final allParams = const DashboardFilter(
      period: DashboardPeriod.all,
    ).toRpcParams(now: DateTime(2026, 11, 11));
    expect(allParams['p_from'], isNull);
    expect(allParams['p_to'], isNull);
  });

  test('groups daily values into Monday-based weeks and guards zero totals', () {
    final grouped = groupDailyStatsByWeek([
      DailyStat(day: DateTime(2026, 11, 2), total: 3, highRisk: 1),
      DailyStat(day: DateTime(2026, 11, 4), total: 2, highRisk: 2),
      DailyStat(day: DateTime(2026, 11, 10), total: 5, highRisk: 1),
    ]);

    expect(grouped, hasLength(2));
    expect(grouped.first.day, DateTime(2026, 11, 2));
    expect(grouped.first.total, 5);
    expect(grouped.first.highRisk, 3);
    expect(percentageOf(3, 0), 0);
    expect(percentageOf(1, 4), 25);
  });
}

final Map<String, dynamic> _completeResponse = {
  'generado_en': '2026-11-11T12:00:00Z',
  'resumen': {
    'total': 20,
    'alto_riesgo': 4,
    'emergencias': 2,
    'prob_alto_promedio': 0.37,
    'prob_adverso_promedio': 1,
    'con_seguimiento': 8,
    'medicos_activos': 3,
  },
  'por_riesgo': [
    {'nivel': 'Alto Riesgo Obstétrico', 'total': 4},
  ],
  'por_departamento': [
    {'departamento': 'Cesar', 'total': 20, 'altos': 4, 'emergencias': 2},
  ],
  'por_municipio': [
    {
      'municipio': 'Valledupar',
      'departamento': 'Cesar',
      'total': 20,
      'altos': 4,
    },
  ],
  'por_etnia': [
    {
      'etnia': 'Wayuu',
      'total': 12,
      'altos': 3,
      'emergencias': 1,
      'prob_alto_promedio': 0.5,
    },
  ],
  'por_zona': [
    {'zona': 'Rural', 'total': 10, 'altos': 3},
  ],
  'por_dia': [
    {'dia': '2026-11-10', 'total': 2, 'altos': 1},
  ],
  'por_medico': [
    {
      'nombre': 'Dra. Test',
      'total': 8,
      'altos': 2,
      'ultima_evaluacion': '2026-11-10T18:00:00Z',
    },
  ],
  'departamentos': ['Cesar'],
};
