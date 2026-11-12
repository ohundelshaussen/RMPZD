enum DashboardPeriod { days7, days30, days90, all }

extension DashboardPeriodLabel on DashboardPeriod {
  String get label => switch (this) {
    DashboardPeriod.days7 => '7 días',
    DashboardPeriod.days30 => '30 días',
    DashboardPeriod.days90 => '90 días',
    DashboardPeriod.all => 'Todo',
  };
}

class DashboardFilter {
  final DashboardPeriod period;
  final String? department;

  const DashboardFilter({
    this.period = DashboardPeriod.days30,
    this.department,
  });

  bool get shouldGroupWeekly =>
      period == DashboardPeriod.days90 || period == DashboardPeriod.all;

  Map<String, dynamic> toRpcParams({DateTime? now}) {
    final today = now ?? DateTime.now();
    final startOfTomorrow = DateTime(
      today.year,
      today.month,
      today.day + 1,
    );
    final start = switch (period) {
      DashboardPeriod.days7 => DateTime(
        today.year,
        today.month,
        today.day - 6,
      ),
      DashboardPeriod.days30 => DateTime(
        today.year,
        today.month,
        today.day - 29,
      ),
      DashboardPeriod.days90 => DateTime(
        today.year,
        today.month,
        today.day - 89,
      ),
      DashboardPeriod.all => null,
    };

    return {
      'p_from': start?.toUtc().toIso8601String(),
      'p_to': period == DashboardPeriod.all
          ? null
          : startOfTomorrow.toUtc().toIso8601String(),
      'p_departamento': department,
    };
  }

  String cacheKey({DateTime? now}) {
    final params = toRpcParams(now: now);
    return '${params['p_from'] ?? 'all'}|'
        '${params['p_to'] ?? 'all'}|${department ?? 'all'}';
  }

  DashboardFilter copyWith({
    DashboardPeriod? period,
    String? department,
    bool clearDepartment = false,
  }) {
    return DashboardFilter(
      period: period ?? this.period,
      department: clearDepartment ? null : department ?? this.department,
    );
  }
}
