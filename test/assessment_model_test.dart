import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/features/triage/data/models/assessment_model.dart';
import 'package:rmpzd/features/triage/domain/entities/assessment_record.dart';
import 'package:rmpzd/features/triage/domain/entities/clinical_alert.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';

void main() {
  test(
    'maps an assessment record to and from the existing database columns',
    () {
      final date = DateTime(2026, 11, 11, 10);
      final record = AssessmentRecord(
        patient: PatientAssessment(
          patientId: 'MP-TEST',
          municipio: 'Valledupar',
          departamento: 'Cesar',
          etnia: 'No Indígena',
          zona: 'Urbana',
          edadMaterna: 24,
          semanasGestacion: 28,
          numeroControles: 3,
          distanciaKm: 18.5,
          tiempoTrasladoHoras: 1.8,
          hemoglobina: 11.2,
          presionSistolica: 120,
          presionDiastolica: 75,
          imc: 25.4,
          antecedentePreeclampsia: false,
          antecedenteDiabetes: false,
          partoInstitucionalPrevio: true,
          afiliacionSgsss: 'Subsidiado',
          fechaEvaluacion: date,
        ),
        result: const TriageResult(
          riskLevel: RiskLevel.alto,
          probAlto: 0.6,
          probMedio: 0.3,
          probBajo: 0.1,
          riesgoDesenlaceAdverso: true,
          probDesenlaceAdverso: 0.7,
          clinicalAlerts: [
            ClinicalAlert(
              title: 'Alerta de prueba',
              description: 'Descripción',
              severity: AlertSeverity.immediateEmergency,
              actionRequired: 'Remitir',
            ),
          ],
          hasImmediateEmergency: true,
        ),
        idLocal: 42,
        fechaGuardado: date,
        sincronizado: true,
      );

      final model = AssessmentModel(record: record);
      final row = model.toMap();
      final restored = AssessmentModel.fromMap(row).record;

      expect(
        row.keys,
        containsAll([
          'id',
          'patient_id',
          'municipio',
          'departamento',
          'etnia',
          'zona',
          'edad_materna',
          'semanas_gestacion',
          'numero_controles',
          'distancia_km',
          'tiempo_traslado_horas',
          'hemoglobina',
          'presion_sistolica',
          'presion_diastolica',
          'imc',
          'antecedente_preeclampsia',
          'antecedente_diabetes',
          'parto_institucional_previo',
          'afiliacion_sgsss',
          'fecha_evaluacion',
          'nivel_riesgo_predicho',
          'probabilidad_riesgo_alto',
          'alerta_clinica_inmediata',
          'descripcion_alerta',
          'probabilidad_desenlace_adverso',
          'sincronizado',
        ]),
      );
      expect(row, hasLength(26));
      expect(model.toJson(), row);
      expect(restored.idLocal, 42);
      expect(restored.patient.patientId, 'MP-TEST');
      expect(restored.patient.presionSistolica, 120);
      expect(restored.fechaGuardado, date);
      expect(restored.sincronizado, isTrue);
      expect(restored.result.riskLevel, RiskLevel.alto);
      expect(restored.result.probAlto, 0.6);
      expect(restored.result.riesgoDesenlaceAdverso, isTrue);
      expect(restored.result.hasImmediateEmergency, isTrue);
      expect(restored.result.clinicalAlerts.map((alert) => alert.title), [
        'Alerta de prueba',
      ]);
    },
  );
}
