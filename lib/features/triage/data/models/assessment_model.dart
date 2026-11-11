import '../../../../core/constants/clinical_thresholds.dart';
import '../../domain/entities/assessment_record.dart';
import '../../domain/entities/clinical_alert.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';

class AssessmentModel {
  final AssessmentRecord record;

  const AssessmentModel({required this.record});

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
      'sincronizado': record.sincronizado ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() => toMap();

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
      record: AssessmentRecord(
        patient: patient,
        result: result,
        idLocal: map['id'] as int?,
        fechaGuardado: fechaGuardado,
        sincronizado: (map['sincronizado'] as int? ?? 0) == 1,
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
