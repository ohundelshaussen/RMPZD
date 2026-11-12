class DashboardSummary {
  final int total;
  final int highRisk;
  final int emergencies;
  final double averageHighRiskProbability;
  final double averageAdverseProbability;
  final int withFollowUp;
  final int activeDoctors;

  const DashboardSummary({
    required this.total,
    required this.highRisk,
    required this.emergencies,
    required this.averageHighRiskProbability,
    required this.averageAdverseProbability,
    required this.withFollowUp,
    required this.activeDoctors,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const <String, dynamic>{};
    return DashboardSummary(
      total: _asInt(map['total']),
      highRisk: _asInt(map['alto_riesgo']),
      emergencies: _asInt(map['emergencias']),
      averageHighRiskProbability: _asDouble(map['prob_alto_promedio']),
      averageAdverseProbability: _asDouble(map['prob_adverso_promedio']),
      withFollowUp: _asInt(map['con_seguimiento']),
      activeDoctors: _asInt(map['medicos_activos']),
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'alto_riesgo': highRisk,
    'emergencias': emergencies,
    'prob_alto_promedio': averageHighRiskProbability,
    'prob_adverso_promedio': averageAdverseProbability,
    'con_seguimiento': withFollowUp,
    'medicos_activos': activeDoctors,
  };
}

class RiskSlice {
  final String level;
  final int total;

  const RiskSlice({required this.level, required this.total});

  factory RiskSlice.fromJson(Map<String, dynamic> json) => RiskSlice(
    level: _asString(json['nivel']),
    total: _asInt(json['total']),
  );

  Map<String, dynamic> toJson() => {'nivel': level, 'total': total};
}

class TerritoryStat {
  final String name;
  final String? department;
  final int total;
  final int highRisk;
  final int emergencies;

  const TerritoryStat({
    required this.name,
    this.department,
    required this.total,
    required this.highRisk,
    this.emergencies = 0,
  });

  factory TerritoryStat.departmentFromJson(Map<String, dynamic> json) =>
      TerritoryStat(
        name: _asString(json['departamento']),
        total: _asInt(json['total']),
        highRisk: _asInt(json['altos']),
        emergencies: _asInt(json['emergencias']),
      );

  factory TerritoryStat.municipalityFromJson(Map<String, dynamic> json) =>
      TerritoryStat(
        name: _asString(json['municipio']),
        department: _asNullableString(json['departamento']),
        total: _asInt(json['total']),
        highRisk: _asInt(json['altos']),
      );

  factory TerritoryStat.zoneFromJson(Map<String, dynamic> json) =>
      TerritoryStat(
        name: _asString(json['zona']),
        total: _asInt(json['total']),
        highRisk: _asInt(json['altos']),
      );

  Map<String, dynamic> toDepartmentJson() => {
    'departamento': name,
    'total': total,
    'altos': highRisk,
    'emergencias': emergencies,
  };

  Map<String, dynamic> toMunicipalityJson() => {
    'municipio': name,
    'departamento': department,
    'total': total,
    'altos': highRisk,
  };

  Map<String, dynamic> toZoneJson() => {
    'zona': name,
    'total': total,
    'altos': highRisk,
  };
}

class EthnicityStat {
  final String ethnicity;
  final int total;
  final int highRisk;
  final int emergencies;
  final double averageHighRiskProbability;

  const EthnicityStat({
    required this.ethnicity,
    required this.total,
    required this.highRisk,
    required this.emergencies,
    required this.averageHighRiskProbability,
  });

  factory EthnicityStat.fromJson(Map<String, dynamic> json) => EthnicityStat(
    ethnicity: _asString(json['etnia']),
    total: _asInt(json['total']),
    highRisk: _asInt(json['altos']),
    emergencies: _asInt(json['emergencias']),
    averageHighRiskProbability: _asDouble(json['prob_alto_promedio']),
  );

  Map<String, dynamic> toJson() => {
    'etnia': ethnicity,
    'total': total,
    'altos': highRisk,
    'emergencias': emergencies,
    'prob_alto_promedio': averageHighRiskProbability,
  };
}

class DailyStat {
  final DateTime day;
  final int total;
  final int highRisk;

  const DailyStat({
    required this.day,
    required this.total,
    required this.highRisk,
  });

  factory DailyStat.fromJson(Map<String, dynamic> json) {
    final rawDay = _asString(json['dia']);
    final parsed = DateTime.tryParse(rawDay);
    return DailyStat(
      day: parsed == null
          ? DateTime(1970)
          : DateTime(parsed.year, parsed.month, parsed.day),
      total: _asInt(json['total']),
      highRisk: _asInt(json['altos']),
    );
  }

  Map<String, dynamic> toJson() => {
    'dia': _dateString(day),
    'total': total,
    'altos': highRisk,
  };
}

class DoctorStat {
  final String name;
  final int total;
  final int highRisk;
  final DateTime? lastEvaluation;

  const DoctorStat({
    required this.name,
    required this.total,
    required this.highRisk,
    required this.lastEvaluation,
  });

  factory DoctorStat.fromJson(Map<String, dynamic> json) {
    final rawDate = json['ultima_evaluacion'];
    return DoctorStat(
      name: _asString(json['nombre']),
      total: _asInt(json['total']),
      highRisk: _asInt(json['altos']),
      lastEvaluation: rawDate is String ? DateTime.tryParse(rawDate) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'nombre': name,
    'total': total,
    'altos': highRisk,
    'ultima_evaluacion': lastEvaluation?.toIso8601String(),
  };
}

class DashboardStats {
  final DateTime? generatedAt;
  final DashboardSummary summary;
  final List<RiskSlice> riskSlices;
  final List<TerritoryStat> departments;
  final List<TerritoryStat> municipalities;
  final List<EthnicityStat> ethnicities;
  final List<TerritoryStat> zones;
  final List<DailyStat> dailyStats;
  final List<DoctorStat> doctors;
  final List<String> departmentOptions;

  const DashboardStats({
    required this.generatedAt,
    required this.summary,
    required this.riskSlices,
    required this.departments,
    required this.municipalities,
    required this.ethnicities,
    required this.zones,
    required this.dailyStats,
    required this.doctors,
    required this.departmentOptions,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final rawGenerated = json['generado_en'];
    return DashboardStats(
      generatedAt: rawGenerated is String
          ? DateTime.tryParse(rawGenerated)
          : null,
      summary: DashboardSummary.fromJson(_asMap(json['resumen'])),
      riskSlices: _list(json['por_riesgo'], RiskSlice.fromJson),
      departments: _list(
        json['por_departamento'],
        TerritoryStat.departmentFromJson,
      ),
      municipalities: _list(
        json['por_municipio'],
        TerritoryStat.municipalityFromJson,
      ),
      ethnicities: _list(json['por_etnia'], EthnicityStat.fromJson),
      zones: _list(json['por_zona'], TerritoryStat.zoneFromJson),
      dailyStats: _list(json['por_dia'], DailyStat.fromJson),
      doctors: _list(json['por_medico'], DoctorStat.fromJson),
      departmentOptions: _stringList(json['departamentos']),
    );
  }

  Map<String, dynamic> toJson() => {
    'generado_en': generatedAt?.toIso8601String(),
    'resumen': summary.toJson(),
    'por_riesgo': riskSlices.map((item) => item.toJson()).toList(),
    'por_departamento': departments
        .map((item) => item.toDepartmentJson())
        .toList(),
    'por_municipio': municipalities
        .map((item) => item.toMunicipalityJson())
        .toList(),
    'por_etnia': ethnicities.map((item) => item.toJson()).toList(),
    'por_zona': zones.map((item) => item.toZoneJson()).toList(),
    'por_dia': dailyStats.map((item) => item.toJson()).toList(),
    'por_medico': doctors.map((item) => item.toJson()).toList(),
    'departamentos': departmentOptions,
  };
}

List<T> _list<T>(
  Object? value,
  T Function(Map<String, dynamic>) parse,
) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList();
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<String> _stringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : [];

String _asString(Object? value) => value is String ? value : '';

String? _asNullableString(Object? value) => value is String ? value : null;

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return value is String ? int.tryParse(value) ?? 0 : 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return value is String ? double.tryParse(value) ?? 0 : 0;
}

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
