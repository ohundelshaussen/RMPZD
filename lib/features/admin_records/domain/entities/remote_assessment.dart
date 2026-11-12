class RemoteAssessment {
  final Map<String, dynamic> fields;
  final String? doctorId;
  final String? doctorName;
  final String? doctorEmail;

  const RemoteAssessment({
    required this.fields,
    required this.doctorId,
    required this.doctorName,
    required this.doctorEmail,
  });

  factory RemoteAssessment.fromJson(Map<String, dynamic> json) {
    final profileValue = json['profiles'];
    final profile = profileValue is Map<String, dynamic>
        ? profileValue
        : profileValue is List && profileValue.isNotEmpty
        ? profileValue.first as Map<String, dynamic>
        : null;
    final rawName = profile?['full_name'];
    final rawEmail = profile?['email'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : null;
    final email = rawEmail is String && rawEmail.trim().isNotEmpty
        ? rawEmail.trim()
        : null;

    return RemoteAssessment(
      fields: Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(json)..remove('profiles'),
      ),
      doctorId: json['created_by'] as String?,
      doctorName: name ?? email,
      doctorEmail: email,
    );
  }

  String? get patientId => fields['patient_id']?.toString();
  String? get municipality => fields['municipio']?.toString();
  String? get department => fields['departamento']?.toString();
  String? get riskLevel => fields['nivel_riesgo_predicho']?.toString();
  bool get hasImmediateAlert {
    final value = fields['alerta_clinica_inmediata'];
    return value == true || value == 1 || value == '1';
  }

  DateTime? get evaluationDate {
    final value = fields['fecha_evaluacion'];
    return value is String ? DateTime.tryParse(value) : null;
  }
}
