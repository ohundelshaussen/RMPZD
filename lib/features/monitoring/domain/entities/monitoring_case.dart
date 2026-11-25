enum MonitoringCaseStatus {
  nuevo('nuevo'),
  enGestion('en_gestion'),
  cerrado('cerrado');

  const MonitoringCaseStatus(this.value);

  final String value;

  static MonitoringCaseStatus parse(Object? value) => switch (value) {
    'en_gestion' => MonitoringCaseStatus.enGestion,
    'cerrado' => MonitoringCaseStatus.cerrado,
    _ => MonitoringCaseStatus.nuevo,
  };
}

enum MonitoringPriority {
  critica('critica'),
  alta('alta');

  const MonitoringPriority(this.value);

  final String value;

  static MonitoringPriority parse(Object? value) =>
      value == 'critica' ? MonitoringPriority.critica : MonitoringPriority.alta;
}

class MonitoringCase {
  final String id;
  final String assessmentId;
  final MonitoringCaseStatus status;
  final MonitoringPriority priority;
  final String? assignedTo;
  final DateTime createdAt;
  final String? municipality;
  final String? department;
  final String? riskLevel;
  final String? alertDescription;
  final String? patientId;
  final String? patientName;
  final int? gestationWeeks;
  final int? maternalAge;
  final DateTime? closedAt;
  final String? closedBy;
  final String? result;

  const MonitoringCase({
    required this.id,
    required this.assessmentId,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.assignedTo,
    this.municipality,
    this.department,
    this.riskLevel,
    this.alertDescription,
    this.patientId,
    this.patientName,
    this.gestationWeeks,
    this.maternalAge,
    this.closedAt,
    this.closedBy,
    this.result,
  });

  factory MonitoringCase.fromJson(Map<String, dynamic> json) {
    final assessment = _embeddedAssessment(json['assessments']);
    return MonitoringCase(
      id: _string(json['id']) ?? '',
      assessmentId: _string(json['assessment_id']) ?? '',
      status: MonitoringCaseStatus.parse(json['estado']),
      priority: MonitoringPriority.parse(json['prioridad']),
      assignedTo: _string(json['asignado_a']),
      createdAt:
          DateTime.tryParse(_string(json['creado_en']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      municipality: _string(json['municipio']),
      department: _string(json['departamento']),
      riskLevel: _string(json['nivel_riesgo']),
      alertDescription: _string(json['descripcion_alerta']),
      patientId: _string(assessment?['patient_id']),
      patientName: _string(assessment?['nombre_paciente']),
      gestationWeeks: _integer(assessment?['semanas_gestacion']),
      maternalAge: _integer(assessment?['edad_materna']),
      closedAt: DateTime.tryParse(_string(json['cerrado_en']) ?? ''),
      closedBy: _string(json['cerrado_por']),
      result: _string(json['resultado']),
    );
  }

  static Map<String, dynamic>? _embeddedAssessment(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  static String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return value is String ? int.tryParse(value) : null;
  }
}

enum MonitoringChangeType { insert, update, delete }

class MonitoringCaseChange {
  final MonitoringChangeType type;
  final MonitoringCase? current;
  final String caseId;

  const MonitoringCaseChange({
    required this.type,
    required this.caseId,
    this.current,
  });
}

class MonitoringAlert {
  final String caseId;
  final MonitoringPriority priority;
  final String? municipality;
  final String? department;

  const MonitoringAlert({
    required this.caseId,
    required this.priority,
    this.municipality,
    this.department,
  });

  factory MonitoringAlert.fromCase(MonitoringCase item) => MonitoringAlert(
    caseId: item.id,
    priority: item.priority,
    municipality: item.municipality,
    department: item.department,
  );

  String get title => priority == MonitoringPriority.critica
      ? 'Alerta crítica'
      : 'Alerta de alto riesgo';

  String get location => [
    municipality ?? 'Municipio no disponible',
    department ?? 'Departamento no disponible',
  ].join(', ');

  String get notificationText => '$title · $location';
}
