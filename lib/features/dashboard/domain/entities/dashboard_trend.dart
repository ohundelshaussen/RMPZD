import 'dashboard_stats.dart';

List<DailyStat> groupDailyStatsByWeek(List<DailyStat> dailyStats) {
  final totals = <DateTime, ({int total, int highRisk})>{};
  for (final stat in dailyStats) {
    final date = DateTime(stat.day.year, stat.day.month, stat.day.day);
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final current = totals[weekStart] ?? (total: 0, highRisk: 0);
    totals[weekStart] = (
      total: current.total + stat.total,
      highRisk: current.highRisk + stat.highRisk,
    );
  }
  return totals.entries
      .map(
        (entry) => DailyStat(
          day: entry.key,
          total: entry.value.total,
          highRisk: entry.value.highRisk,
        ),
      )
      .toList()
    ..sort((a, b) => a.day.compareTo(b.day));
}

double percentageOf(int value, int total) =>
    total <= 0 ? 0 : (value / total) * 100;
