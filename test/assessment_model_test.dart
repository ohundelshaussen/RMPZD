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
        uuid: '97c76ec7-9228-4de0-88c3-f2efee432939',
        ownerId: 'doctor-1',
        syncStatus: SyncStatus.synced,
        fechaGuardado: date,
      );

      final updatedAt = date.add(const Duration(hours: 2));
      final model = AssessmentModel(
        record: record,
        syncAttempts: 2,
        updatedAt: updatedAt,
      );
      final row = model.toMap();
      final restoredModel = AssessmentModel.fromMap(row);
      final restored = restoredModel.record;

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
          'uuid',
          'owner_id',
          'sync_status',
          'last_sync_error',
          'sync_attempts',
          'updated_at',
        ]),
      );
      expect(row, hasLength(32));
      expect(model.toJson(), row);
      expect(restored.idLocal, 42);
      expect(restoredModel.syncAttempts, 2);
      expect(restoredModel.updatedAt, updatedAt.toUtc());
      expect(restored.patient.patientId, 'MP-TEST');
      expect(restored.patient.presionSistolica, 120);
      expect(restored.fechaGuardado, date);
      expect(restored.isSynced, isTrue);
      expect(restored.result.riskLevel, RiskLevel.alto);
      expect(restored.result.probAlto, 0.6);
      expect(restored.result.riesgoDesenlaceAdverso, isTrue);
      expect(restored.result.hasImmediateEmergency, isTrue);
      expect(restored.result.clinicalAlerts.map((alert) => alert.title), [
        'Alerta de prueba',
      ]);
    },
  );

  test('creates the Supabase payload with UTC dates and no local columns', () {
    final date = DateTime.parse('2026-11-11T15:00:00-05:00');
    final record = AssessmentRecord(
      patient: PatientAssessment(
        patientId: 'MP-REMOTE',
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
        antecedentePreeclampsia: true,
        antecedenteDiabetes: false,
        partoInstitucionalPrevio: true,
        afiliacionSgsss: 'Subsidiado',
        fechaEvaluacion: date,
      ),
      result: const TriageResult(
        riskLevel: RiskLevel.medio,
        probAlto: 0.3,
        probMedio: 0.6,
        probBajo: 0.1,
        riesgoDesenlaceAdverso: false,
        probDesenlaceAdverso: 0.2,
        clinicalAlerts: [],
        hasImmediateEmergency: false,
      ),
      uuid: '97c76ec7-9228-4de0-88c3-f2efee432939',
      ownerId: 'doctor-1',
      fechaGuardado: date,
    );

    final payload = AssessmentModel(record: record).toRemoteJson();

    expect(payload['id'], record.uuid);
    expect(payload['created_by'], 'doctor-1');
    expect(payload['antecedente_preeclampsia'], isTrue);
    expect(payload['antecedente_diabetes'], isFalse);
    expect(payload['parto_institucional_previo'], isTrue);
    expect(payload['alerta_clinica_inmediata'], isFalse);
    expect(payload['fecha_evaluacion'], '2026-11-11T20:00:00.000Z');
    expect(
      payload.keys,
      isNot(
        contains(
          anyOf(
            'owner_id',
            'sync_status',
            'sync_attempts',
            'sincronizado',
            'last_sync_error',
          ),
        ),
      ),
    );
    expect(payload, hasLength(26));
  });
}
