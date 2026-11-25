import '../../../../core/utils/consultation_code_generator.dart';

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

  String? get id => fields['id']?.toString();
  String? get patientId => fields['patient_id']?.toString();
  String? get patientName => _nonEmptyString(fields['nombre_paciente']);
  String? get municipality => _nonEmptyString(fields['municipio']);
  String? get department => _nonEmptyString(fields['departamento']);
  String? get riskLevel => _nonEmptyString(fields['nivel_riesgo_predicho']);
  String? get consultationCode => _nonEmptyString(fields['codigo_consulta']);
  String? get formattedConsultationCode {
    final code = consultationCode;
    return code == null ? null : ConsultationCodeGenerator.format(code);
  }

  bool get hasConsultationCodeHash =>
      _nonEmptyString(fields['codigo_consulta_hash']) != null;
  String? get ethnicity => _nonEmptyString(fields['etnia']);
  String? get zone => _nonEmptyString(fields['zona']);
  String? get affiliation => _nonEmptyString(fields['afiliacion_sgsss']);
  String? get address => _nonEmptyString(fields['direccion_paciente']);
  String? get telefonoPaciente =>
      consentimientoDatos ? _nonEmptyString(fields['telefono_paciente']) : null;
  double? get latitude => _toDouble(fields['latitud']);
  double? get longitude => _toDouble(fields['longitud']);
  double? get gpsAccuracyM => _toDouble(fields['precision_gps_m']);
  bool get consentimientoDatos => _toBool(fields['consentimiento_datos']) ?? false;
  int? get age => _toInt(fields['edad_materna']);
  int? get weeks => _toInt(fields['semanas_gestacion']);
  int? get visits => _toInt(fields['numero_controles']);
  double? get distanceKm => _toDouble(fields['distancia_km']);
  double? get travelTimeHours => _toDouble(fields['tiempo_traslado_horas']);
  double? get hemoglobin => _toDouble(fields['hemoglobina']);
  double? get systolic => _toDouble(fields['presion_sistolica']);
  double? get diastolic => _toDouble(fields['presion_diastolica']);
  double? get bmi => _toDouble(fields['imc']);
  bool? get preeclampsiaHistory => _toBool(fields['antecedente_preeclampsia']);
  bool? get diabetesHistory => _toBool(fields['antecedente_diabetes']);
  bool? get institutionalBirthHistory =>
      _toBool(fields['parto_institucional_previo']);
  double? get probHigh => _toDouble(fields['probabilidad_riesgo_alto']);
  double? get probAdverse =>
      _toDouble(fields['probabilidad_desenlace_adverso']);
  String? get alertDescription => _nonEmptyString(fields['descripcion_alerta']);

  bool get hasImmediateAlert =>
      _toBool(fields['alerta_clinica_inmediata']) ?? false;

  DateTime? get evaluationDate {
    final value = fields['fecha_evaluacion'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  static String? _nonEmptyString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool? _toBool(Object? value) {
    if (value is bool) return value;
    if (value == 1 || value == '1' || value == 'true') return true;
    if (value == 0 || value == '0' || value == 'false') return false;
    return null;
  }
}
