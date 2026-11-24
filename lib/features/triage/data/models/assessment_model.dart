import '../../../../core/constants/clinical_thresholds.dart';
import '../../domain/entities/assessment_record.dart';
import '../../domain/entities/clinical_alert.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';

class AssessmentModel {
  final AssessmentRecord record;
  final int syncAttempts;
  final DateTime? updatedAt;

  const AssessmentModel({
    required this.record,
    this.syncAttempts = 0,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final patient = record.patient;
    final result = record.result;

    return {
      'id': record.idLocal,
      'patient_id': patient.patientId,
      'municipio': patient.municipio,
      'departamento': patient.departamento,
      'etnia': patient.etnia,
      'zona': patient.zona,
      'edad_materna': patient.edadMaterna,
      'semanas_gestacion': patient.semanasGestacion,
      'numero_controles': patient.numeroControles,
      'distancia_km': patient.distanciaKm,
      'tiempo_traslado_horas': patient.tiempoTrasladoHoras,
      'hemoglobina': patient.hemoglobina,
      'presion_sistolica': patient.presionSistolica,
      'presion_diastolica': patient.presionDiastolica,
      'imc': patient.imc,
      'antecedente_preeclampsia': patient.antecedentePreeclampsia ? 1 : 0,
      'antecedente_diabetes': patient.antecedenteDiabetes ? 1 : 0,
      'parto_institucional_previo': patient.partoInstitucionalPrevio ? 1 : 0,
      'afiliacion_sgsss': patient.afiliacionSgsss,
      'fecha_evaluacion': record.fechaGuardado.toIso8601String(),
      'nivel_riesgo_predicho': result.riskLabel,
      'probabilidad_riesgo_alto': result.probAlto,
      'alerta_clinica_inmediata': result.hasImmediateEmergency ? 1 : 0,
      'descripcion_alerta': result.clinicalAlerts.isNotEmpty
          ? result.clinicalAlerts.map((alert) => alert.title).join(' | ')
          : null,
      'probabilidad_desenlace_adverso': result.probDesenlaceAdverso,
      'sincronizado': record.isSynced ? 1 : 0,
      'uuid': record.uuid,
      'owner_id': record.ownerId,
      'sync_status': record.syncStatus.name,
      'last_sync_error': record.lastSyncError,
      'sync_attempts': syncAttempts,
      'updated_at': (updatedAt ?? record.fechaGuardado)
          .toUtc()
          .toIso8601String(),
      'codigo_consulta': record.consultationCode?.replaceAll('-', ''),
      'nombre_paciente': patient.nombrePaciente,
      'direccion_paciente': patient.direccionPaciente,
      'latitud': patient.latitud,
      'longitud': patient.longitud,
      'precision_gps_m': patient.precisionGpsM,
      'ubicacion_capturada_at': patient.ubicacionCapturadaAt
          ?.toUtc()
          .toIso8601String(),
      'consentimiento_datos': patient.consentimientoDatos ? 1 : 0,
      'consentimiento_at': record.consentimientoAt?.toUtc().toIso8601String(),
    };
  }

  factory AssessmentModel.fromRemoteJson(Map<String, dynamic> map) {
    final fechaGuardado = DateTime.parse(map['fecha_evaluacion'] as String);
    final id = map['id'];
    final ownerId = map['created_by'];
    if (id is! String || id.isEmpty) {
      throw const FormatException(
        'La evaluación remota no tiene un UUID válido.',
      );
    }
    if (ownerId is! String || ownerId.isEmpty) {
      throw const FormatException('La evaluación remota no tiene propietario.');
    }

    final hasConsent = _remoteBool(map['consentimiento_datos']);
    final patient = PatientAssessment(
      patientId: map['patient_id'] as String,
      municipio: map['municipio'] as String,
      departamento: map['departamento'] as String,
      etnia: map['etnia'] as String,
      zona: map['zona'] as String,
      edadMaterna: (map['edad_materna'] as num).toInt(),
      semanasGestacion: (map['semanas_gestacion'] as num).toInt(),
      numeroControles: (map['numero_controles'] as num).toInt(),
      distanciaKm: (map['distancia_km'] as num).toDouble(),
      tiempoTrasladoHoras: (map['tiempo_traslado_horas'] as num).toDouble(),
      hemoglobina: (map['hemoglobina'] as num).toDouble(),
      presionSistolica: (map['presion_sistolica'] as num).toDouble(),
      presionDiastolica: (map['presion_diastolica'] as num).toDouble(),
      imc: (map['imc'] as num).toDouble(),
      antecedentePreeclampsia: _remoteBool(map['antecedente_preeclampsia']),
      antecedenteDiabetes: _remoteBool(map['antecedente_diabetes']),
      partoInstitucionalPrevio: _remoteBool(map['parto_institucional_previo']),
      afiliacionSgsss: map['afiliacion_sgsss'] as String,
      fechaEvaluacion: fechaGuardado,
      nombrePaciente: hasConsent ? map['nombre_paciente'] as String? : null,
      direccionPaciente: hasConsent
          ? map['direccion_paciente'] as String?
          : null,
      latitud: hasConsent ? (map['latitud'] as num?)?.toDouble() : null,
      longitud: hasConsent ? (map['longitud'] as num?)?.toDouble() : null,
      precisionGpsM: hasConsent
          ? (map['precision_gps_m'] as num?)?.toDouble()
          : null,
      ubicacionCapturadaAt:
          hasConsent && map['ubicacion_capturada_at'] is String
          ? DateTime.parse(map['ubicacion_capturada_at'] as String)
          : null,
      consentimientoDatos: hasConsent,
    );

    final hasImmediateEmergency = _remoteBool(map['alerta_clinica_inmediata']);
    final probabilityAdverseOutcome =
        (map['probabilidad_desenlace_adverso'] as num).toDouble();
    final alertTitles =
        (map['descripcion_alerta'] as String?)
            ?.split(' | ')
            .where((title) => title.isNotEmpty)
            .toList() ??
        [];
    final result = TriageResult(
      riskLevel: _riskLevelFromLabel(map['nivel_riesgo_predicho'] as String),
      probAlto: (map['probabilidad_riesgo_alto'] as num).toDouble(),
      probMedio: 0,
      probBajo: 0,
      riesgoDesenlaceAdverso:
          probabilityAdverseOutcome >=
          ClinicalThresholds.aiAdverseOutcomeThreshold,
      probDesenlaceAdverso: probabilityAdverseOutcome,
      clinicalAlerts: alertTitles
          .map(
            (title) => ClinicalAlert(
              title: title,
              description: '',
              severity: hasImmediateEmergency
                  ? AlertSeverity.immediateEmergency
                  : AlertSeverity.warning,
              actionRequired: '',
            ),
          )
          .toList(),
      hasImmediateEmergency: hasImmediateEmergency,
    );

    final updatedAtValue = map['updated_at'];
    final consentAtValue = map['consentimiento_at'];
    return AssessmentModel(
      updatedAt: updatedAtValue is String
          ? DateTime.parse(updatedAtValue)
          : null,
      record: AssessmentRecord(
        patient: patient,
        result: result,
        uuid: id,
        ownerId: ownerId,
        syncStatus: SyncStatus.synced,
        consultationCode: null,
        consentimientoAt: hasConsent && consentAtValue is String
            ? DateTime.parse(consentAtValue)
            : null,
        fechaGuardado: fechaGuardado,
      ),
    );
  }

  static bool _remoteBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toRemoteJson() {
    final patient = record.patient;
    final result = record.result;
    final hasConsent = patient.consentimientoDatos;
    return {
      'id': record.uuid,
      'created_by': record.ownerId,
      'patient_id': patient.patientId,
      'municipio': patient.municipio,
      'departamento': patient.departamento,
      'etnia': patient.etnia,
      'zona': patient.zona,
      'edad_materna': patient.edadMaterna,
      'semanas_gestacion': patient.semanasGestacion,
      'numero_controles': patient.numeroControles,
      'distancia_km': patient.distanciaKm,
      'tiempo_traslado_horas': patient.tiempoTrasladoHoras,
      'hemoglobina': patient.hemoglobina,
      'presion_sistolica': patient.presionSistolica,
      'presion_diastolica': patient.presionDiastolica,
      'imc': patient.imc,
      'antecedente_preeclampsia': patient.antecedentePreeclampsia,
      'antecedente_diabetes': patient.antecedenteDiabetes,
      'parto_institucional_previo': patient.partoInstitucionalPrevio,
      'afiliacion_sgsss': patient.afiliacionSgsss,
      'fecha_evaluacion': record.fechaGuardado.toUtc().toIso8601String(),
      'nivel_riesgo_predicho': result.riskLabel,
      'probabilidad_riesgo_alto': result.probAlto,
      'alerta_clinica_inmediata': result.hasImmediateEmergency,
      'descripcion_alerta': result.clinicalAlerts.isNotEmpty
          ? result.clinicalAlerts.map((alert) => alert.title).join(' | ')
          : null,
      'probabilidad_desenlace_adverso': result.probDesenlaceAdverso,
      'codigo_consulta': record.consultationCode?.replaceAll('-', ''),
      'nombre_paciente': hasConsent ? patient.nombrePaciente : null,
      'direccion_paciente': hasConsent ? patient.direccionPaciente : null,
      'latitud': hasConsent ? patient.latitud : null,
      'longitud': hasConsent ? patient.longitud : null,
      'precision_gps_m': hasConsent ? patient.precisionGpsM : null,
      'ubicacion_capturada_at': hasConsent
          ? patient.ubicacionCapturadaAt?.toUtc().toIso8601String()
          : null,
      'consentimiento_datos': hasConsent,
      'consentimiento_at': hasConsent
          ? record.consentimientoAt?.toUtc().toIso8601String()
          : null,
    };
  }

  factory AssessmentModel.fromMap(Map<String, dynamic> map) {
    final hasImmediateEmergency =
        (map['alerta_clinica_inmediata'] as int? ?? 0) == 1;
    final alertTitles =
        (map['descripcion_alerta'] as String?)
            ?.split(' | ')
            .where((title) => title.isNotEmpty)
            .toList() ??
        [];
    final probabilityAdverseOutcome =
        (map['probabilidad_desenlace_adverso'] as num).toDouble();
    final fechaGuardado = DateTime.parse(map['fecha_evaluacion'] as String);
    final uuid = map['uuid'];
    final updatedAtValue = map['updated_at'];
    if (uuid is! String || uuid.isEmpty) {
      throw const FormatException(
        'El UUID local de la evaluación no es válido.',
      );
    }

    final patient = PatientAssessment(
      patientId: map['patient_id'] as String,
      municipio: map['municipio'] as String,
      departamento: map['departamento'] as String,
      etnia: map['etnia'] as String,
      zona: map['zona'] as String,
      edadMaterna: map['edad_materna'] as int,
      semanasGestacion: map['semanas_gestacion'] as int,
      numeroControles: map['numero_controles'] as int,
      distanciaKm: (map['distancia_km'] as num).toDouble(),
      tiempoTrasladoHoras: (map['tiempo_traslado_horas'] as num).toDouble(),
      hemoglobina: (map['hemoglobina'] as num).toDouble(),
      presionSistolica: (map['presion_sistolica'] as num).toDouble(),
      presionDiastolica: (map['presion_diastolica'] as num).toDouble(),
      imc: (map['imc'] as num).toDouble(),
      antecedentePreeclampsia: (map['antecedente_preeclampsia'] as int) == 1,
      antecedenteDiabetes: (map['antecedente_diabetes'] as int) == 1,
      partoInstitucionalPrevio: (map['parto_institucional_previo'] as int) == 1,
      afiliacionSgsss: map['afiliacion_sgsss'] as String,
      fechaEvaluacion: fechaGuardado,
      nombrePaciente: map['nombre_paciente'] as String?,
      direccionPaciente: map['direccion_paciente'] as String?,
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
      precisionGpsM: (map['precision_gps_m'] as num?)?.toDouble(),
      ubicacionCapturadaAt: map['ubicacion_capturada_at'] is String
          ? DateTime.parse(map['ubicacion_capturada_at'] as String)
          : null,
      consentimientoDatos: (map['consentimiento_datos'] as int? ?? 0) == 1,
    );

    final result = TriageResult(
      riskLevel: _riskLevelFromLabel(map['nivel_riesgo_predicho'] as String),
      probAlto: (map['probabilidad_riesgo_alto'] as num).toDouble(),
      probMedio: 0,
      probBajo: 0,
      riesgoDesenlaceAdverso:
          probabilityAdverseOutcome >=
          ClinicalThresholds.aiAdverseOutcomeThreshold,
      probDesenlaceAdverso: probabilityAdverseOutcome,
      clinicalAlerts: alertTitles
          .map(
            (title) => ClinicalAlert(
              title: title,
              description: '',
              severity: hasImmediateEmergency
                  ? AlertSeverity.immediateEmergency
                  : AlertSeverity.warning,
              actionRequired: '',
            ),
          )
          .toList(),
      hasImmediateEmergency: hasImmediateEmergency,
    );

    return AssessmentModel(
      syncAttempts: (map['sync_attempts'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAtValue is String
          ? DateTime.parse(updatedAtValue)
          : null,
      record: AssessmentRecord(
        patient: patient,
        result: result,
        idLocal: map['id'] as int?,
        uuid: uuid,
        ownerId: map['owner_id'] as String?,
        syncStatus: SyncStatus.values.firstWhere(
          (status) =>
              status.name == (map['sync_status'] as String? ?? 'pending'),
          orElse: () => SyncStatus.pending,
        ),
        lastSyncError: map['last_sync_error'] as String?,
        consultationCode: map['codigo_consulta'] as String?,
        consentimientoAt: map['consentimiento_at'] is String
            ? DateTime.parse(map['consentimiento_at'] as String)
            : null,
        fechaGuardado: fechaGuardado,
      ),
    );
  }

  static RiskLevel _riskLevelFromLabel(String label) {
    if (label.contains('Alto')) return RiskLevel.alto;
    if (label.contains('Medio') || label.contains('Moderado')) {
      return RiskLevel.medio;
    }
    return RiskLevel.bajo;
  }
}
