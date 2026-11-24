import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/dashboard_filter.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/dashboard_trend.dart';
import '../providers/dashboard_provider.dart';

class DashboardOperationView extends StatefulWidget {
  const DashboardOperationView({super.key});

  @override
  State<DashboardOperationView> createState() => _DashboardOperationViewState();
}

class _DashboardOperationViewState extends State<DashboardOperationView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<DashboardProvider>();
      if (provider.stats == null) provider.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        key: const ValueKey('dashboard-operation-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _filters(provider),
          const SizedBox(height: 12),
          if (provider.isFromCache) _cacheBanner(provider),
          if (provider.state == DashboardLoadState.loading &&
              provider.stats == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 52),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.state == DashboardLoadState.error)
            _errorState(provider)
          else if (provider.stats case final stats?)
            if (stats.summary.total == 0)
              _emptyState()
            else
              _dashboardContent(provider, stats),
        ],
      ),
    );
  }

  Widget _filters(DashboardProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros del tablero',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final period in DashboardPeriod.values)
                  ChoiceChip(
                    label: Text(period.label),
                    selected: provider.filter.period == period,
                    onSelected: (_) => provider.setPeriod(period),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey(provider.filter.department),
              initialValue: provider.filter.department,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Departamento'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos'),
                ),
                for (final department
                    in provider.stats?.departmentOptions ?? const <String>[])
                  DropdownMenuItem<String?>(
                    value: department,
                    child: Text(department, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: provider.setDepartment,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cacheBanner(DashboardProvider provider) {
    final cachedAt = provider.cachedAt;
    final formatted = cachedAt == null
        ? ''
        : DateFormat('dd/MM/yyyy HH:mm').format(cachedAt.toLocal());
    return Container(
      key: const ValueKey('dashboard-cache-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión · datos del $formatted',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(DashboardProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            provider.errorMessage ?? 'No se pudo cargar el dashboard.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: provider.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 18),
        child: Column(
          children: [
            const Icon(
              Icons.analytics_outlined,
              size: 42,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay evaluaciones para estos filtros.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Prueba otro período o departamento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardContent(DashboardProvider provider, DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kpis(stats.summary),
        const SizedBox(height: 12),
        _riskSection(stats.riskSlices),
        const SizedBox(height: 12),
        _trendSection(
          provider.trendStats,
          weekly: provider.filter.shouldGroupWeekly,
        ),
        const SizedBox(height: 12),
        _territorySection('Por departamento', stats.departments),
        const SizedBox(height: 12),
        _territorySection(
          'Top 10 municipios',
          stats.municipalities,
          showDepartment: true,
        ),
        const SizedBox(height: 12),
        _ethnicitySection(stats.ethnicities),
        const SizedBox(height: 12),
        _zoneSection(stats.zones),
        const SizedBox(height: 12),
        _doctorSection(stats.doctors),
      ],
    );
  }

  Widget _kpis(DashboardSummary summary) {
    final total = summary.total;
    final kpis = [
      _Kpi('Evaluaciones', '${summary.total}', Icons.assignment_outlined),
      _Kpi(
        'Alto riesgo',
        '${summary.highRisk}',
        Icons.trending_up_rounded,
        subtitle: '${_percent(summary.highRisk, total)} del total',
        semanticDot: summary.highRisk > 0 ? AppColors.riskHigh : null,
      ),
      _Kpi(
        'Emergencias',
        '${summary.emergencies}',
        Icons.warning_amber_rounded,
        subtitle: '${_percent(summary.emergencies, total)} del total',
        semanticDot: summary.emergencies > 0 ? AppColors.emergencyRed : null,
      ),
      _Kpi(
        'Prob. media riesgo alto',
        _probability(summary.averageHighRiskProbability),
        Icons.analytics_outlined,
      ),
      _Kpi(
        'Con seguimiento',
        _percent(summary.withFollowUp, total),
        Icons.event_available_outlined,
      ),
      _Kpi(
        'Médicos activos',
        '${summary.activeDoctors}',
        Icons.medical_services_outlined,
      ),
    ];
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    return GridView.builder(
      key: const ValueKey('dashboard-kpis'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kpis.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 122 * textScale,
      ),
      itemBuilder: (context, index) {
        final item = kpis[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(item.icon, size: 17, color: AppColors.textMuted),
                    const Spacer(),
                    if (item.semanticDot case final dotColor?)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Flexible(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ),
                if (item.subtitle != null)
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _riskSection(List<RiskSlice> values) {
    final colors = {
      'Bajo Riesgo': AppColors.riskLow,
      'Riesgo Moderado': AppColors.riskMedium,
      'Alto Riesgo Obstétrico': AppColors.riskHigh,
    };
    final slices = values.where((item) => item.total > 0).toList();
    return _section(
      'Distribución por nivel de riesgo',
      slices.isEmpty
          ? const _NoChartData()
          : Column(
              children: [
                SizedBox(
                  height: 176,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 44,
                      sectionsSpace: 2,
                      sections: [
                        for (final item in slices)
                          PieChartSectionData(
                            value: item.total.toDouble(),
                            color: colors[item.level] ?? AppColors.primaryLight,
                            title: '${item.total}',
                            radius: 38,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < values.length; index++) ...[
                  if (index > 0)
                    const Divider(height: 12, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                colors[values[index].level] ??
                                AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            values[index].level,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${values[index].total}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _trendSection(List<DailyStat> values, {required bool weekly}) {
    return _section(
      weekly ? 'Evolución por semana' : 'Evolución por día',
      values.isEmpty
          ? const _NoChartData()
          : LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = math.max(
                  constraints.maxWidth,
                  values.length * (weekly ? 54.0 : 44.0),
                );
                final maxValue = values.fold<int>(
                  0,
                  (current, stat) =>
                      math.max(current, math.max(stat.total, stat.highRisk)),
                );
                final interval = math.max(1, (values.length / 6).ceil());
                return Column(
                  children: [
                    SizedBox(
                      height: 225,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          child: BarChart(
                            BarChartData(
                              maxY: maxValue == 0 ? 1 : maxValue * 1.15,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => const FlLine(
                                  color: AppColors.border,
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              barTouchData: BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) =>
                                        SideTitleWidget(
                                          meta: meta,
                                          child: Text(
                                            value.toInt().toString(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 ||
                                          index >= values.length ||
                                          index % interval != 0) {
                                        return const SizedBox.shrink();
                                      }
                                      return SideTitleWidget(
                                        meta: meta,
                                        child: Text(
                                          DateFormat(
                                            weekly ? 'dd/MM' : 'dd',
                                          ).format(values[index].day),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (
                                  var index = 0;
                                  index < values.length;
                                  index++
                                )
                                  BarChartGroupData(
                                    x: index,
                                    barsSpace: 3,
                                    barRods: [
                                      BarChartRodData(
                                        toY: values[index].total.toDouble(),
                                        color: AppColors.primary.withValues(
                                          alpha: 0.78,
                                        ),
                                        width: 8,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(3),
                                            ),
                                      ),
                                      BarChartRodData(
                                        toY: values[index].highRisk.toDouble(),
                                        color: AppColors.riskHigh,
                                        width: 8,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(3),
                                            ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      children: [
                        _LegendItem(
                          color: AppColors.primary.withValues(alpha: 0.78),
                          label: 'Total',
                        ),
                        const _LegendItem(
                          color: AppColors.riskHigh,
                          label: 'Alto riesgo',
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _territorySection(
    String title,
    List<TerritoryStat> values, {
    bool showDepartment = false,
  }) {
    final maxTotal = values.fold<int>(
      0,
      (current, item) => math.max(current, item.total),
    );
    return _section(
      title,
      values.isEmpty
          ? const _NoChartData()
          : Column(
              children: [
                for (final item in values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (showDepartment && item.department != null)
                                    Text(
                                      item.department!,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total ${item.total} · Altos ${item.highRisk}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 7,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const ColoredBox(
                                  color: AppColors.surfaceVariant,
                                ),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: maxTotal == 0
                                      ? 0
                                      : (item.total / maxTotal).clamp(0.0, 1.0),
                                  child: ColoredBox(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.28,
                                    ),
                                  ),
                                ),
                                if (item.highRisk > 0)
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: maxTotal == 0
                                        ? 0
                                        : (item.highRisk / maxTotal).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                    child: const ColoredBox(
                                      color: AppColors.riskHigh,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _ethnicitySection(List<EthnicityStat> values) {
    return _section(
      'Equidad por grupo étnico',
      values.isEmpty
          ? const _NoChartData()
          : Column(
              children: [
                for (final item in values)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.ethnicity,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              'n = ${item.total}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            _CompactMetric(
                              'Alto riesgo',
                              _percent(item.highRisk, item.total),
                            ),
                            _CompactMetric(
                              'Emergencias',
                              _percent(item.emergencies, item.total),
                            ),
                            _CompactMetric(
                              'Prob. media',
                              _probability(item.averageHighRiskProbability),
                            ),
                          ],
                        ),
                        if (item.total < 10) ...[
                          const SizedBox(height: 7),
                          const Text(
                            'Muestra pequeña; interpretar con cautela.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _zoneSection(List<TerritoryStat> values) {
    return _section(
      'Por zona',
      values.isEmpty
          ? const _NoChartData()
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in values)
                  Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Evaluaciones: ${item.total}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Alto riesgo: ${item.highRisk} '
                          '(${_percent(item.highRisk, item.total)})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _doctorSection(List<DoctorStat> values) {
    return _section(
      'Actividad por médico',
      values.isEmpty
          ? const _NoChartData()
          : Column(
              children: [
                for (var index = 0; index < values.length; index++) ...[
                  if (index > 0)
                    const Divider(height: 1, color: AppColors.border),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    dense: true,
                    leading: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    title: Text(
                      values[index].name.isEmpty
                          ? 'Médico sin nombre'
                          : values[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Evaluaciones ${values[index].total} · '
                      'Altos ${values[index].highRisk}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    trailing: values[index].lastEvaluation == null
                        ? null
                        : Text(
                            DateFormat(
                              'dd/MM/yy',
                            ).format(values[index].lastEvaluation!.toLocal()),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _section(String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  String _percent(int value, int total) =>
      '${percentageOf(value, total).toStringAsFixed(1)}%';

  String _probability(double value) => NumberFormat('0.0%').format(value);
}

class _Kpi {
  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? semanticDot;

  const _Kpi(
    this.title,
    this.value,
    this.icon, {
    this.subtitle,
    this.semanticDot,
  });
}

class _NoChartData extends StatelessWidget {
  const _NoChartData();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Text(
        'Sin datos para mostrar.',
        style: TextStyle(color: AppColors.textMuted),
      ),
    ),
  );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CompactMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label: ',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
