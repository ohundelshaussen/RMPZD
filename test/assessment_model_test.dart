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
          telefonoPaciente: '3001234567',
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
        consultationCode: 'ABCD-2345',
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
          'probabilidad_riesgo_medio',
          'probabilidad_riesgo_bajo',
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
          'codigo_consulta',
          'nombre_paciente',
          'direccion_paciente',
          'telefono_paciente',
          'latitud',
          'longitud',
          'precision_gps_m',
          'ubicacion_capturada_at',
          'consentimiento_datos',
          'consentimiento_at',
        ]),
      );
      expect(row, hasLength(44));
      expect(row['codigo_consulta'], 'ABCD2345');
      expect(model.toJson(), row);
      expect(restored.idLocal, 42);
      expect(restoredModel.syncAttempts, 2);
      expect(restoredModel.updatedAt, updatedAt.toUtc());
      expect(restored.patient.patientId, 'MP-TEST');
      expect(restored.patient.presionSistolica, 120);
      expect(restored.fechaGuardado, date);
      expect(restored.consultationCode, 'ABCD2345');
      expect(restored.isSynced, isTrue);
      expect(restored.result.riskLevel, RiskLevel.alto);
      expect(restored.result.probAlto, 0.6);
      expect(restored.result.probMedio, 0.3);
      expect(restored.result.probBajo, 0.1);
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
        telefonoPaciente: '3001234567',
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
      consultationCode: 'ABCD-2345',
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
    expect(payload['codigo_consulta'], 'ABCD2345');
    expect(payload['consentimiento_datos'], isFalse);
    expect(payload['telefono_paciente'], isNull);
    expect(payload['nombre_paciente'], isNull);
    expect(payload['direccion_paciente'], isNull);
    expect(payload['latitud'], isNull);
    expect(payload['longitud'], isNull);
    expect(payload['precision_gps_m'], isNull);
    expect(payload['ubicacion_capturada_at'], isNull);
    expect(payload['consentimiento_at'], isNull);
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
    expect(payload, hasLength(36));
  });

  test(
    'persists consented identity and UTC timestamps in local and remote maps',
    () {
      final date = DateTime.parse('2026-11-11T15:00:00-05:00');
      final captureDate = DateTime.parse('2026-11-11T15:10:00-05:00');
      final consentDate = DateTime.parse('2026-11-11T15:12:00-05:00');
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
          antecedentePreeclampsia: false,
          antecedenteDiabetes: false,
          partoInstitucionalPrevio: true,
          afiliacionSgsss: 'Subsidiado',
          fechaEvaluacion: date,
          nombrePaciente: 'Paciente de prueba',
          direccionPaciente: 'Barrio Centro',
          latitud: 10.4631,
          longitud: -73.2532,
          precisionGpsM: 8.4,
          ubicacionCapturadaAt: captureDate,
          telefonoPaciente: '+57 (300) 123-4567',
          consentimientoDatos: true,
        ),
        result: const TriageResult(
          riskLevel: RiskLevel.bajo,
          probAlto: 0.1,
          probMedio: 0.2,
          probBajo: 0.7,
          riesgoDesenlaceAdverso: false,
          probDesenlaceAdverso: 0.1,
          clinicalAlerts: [],
          hasImmediateEmergency: false,
        ),
        uuid: '97c76ec7-9228-4de0-88c3-f2efee432939',
        ownerId: 'doctor-1',
        consentimientoAt: consentDate,
        fechaGuardado: date,
      );
      final model = AssessmentModel(record: record);
      final local = model.toMap();
      final payload = model.toRemoteJson();
      final restored = AssessmentModel.fromMap(local).record;

      expect(local['consentimiento_datos'], 1);
      expect(local['telefono_paciente'], '+57 (300) 123-4567');
      expect(local['ubicacion_capturada_at'], '2026-11-11T20:10:00.000Z');
      expect(local['consentimiento_at'], '2026-11-11T20:12:00.000Z');
      expect(payload['consentimiento_datos'], isTrue);
      expect(payload['nombre_paciente'], 'Paciente de prueba');
      expect(payload['telefono_paciente'], '3001234567');
      expect(payload['direccion_paciente'], 'Barrio Centro');
      expect(payload['latitud'], 10.4631);
      expect(payload['longitud'], -73.2532);
      expect(payload['precision_gps_m'], 8.4);
      expect(payload['ubicacion_capturada_at'], '2026-11-11T20:10:00.000Z');
      expect(payload['consentimiento_at'], '2026-11-11T20:12:00.000Z');
      expect(restored.patient.consentimientoDatos, isTrue);
      expect(restored.patient.telefonoPaciente, '+57 (300) 123-4567');
      expect(model.telefonoPaciente, '+57 (300) 123-4567');
      expect(restored.patient.nombrePaciente, 'Paciente de prueba');
      expect(restored.patient.latitud, 10.4631);
      expect(restored.consentimientoAt, DateTime.utc(2026, 11, 11, 20, 12));
    },
  );

  test(
    'redacts identity and GPS fields in local map when consent is false',
    () {
      final date = DateTime.parse('2026-11-11T15:00:00-05:00');
      final record = AssessmentRecord(
        patient: PatientAssessment(
          patientId: 'MP-NOCONSENT',
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
          nombrePaciente: 'Debe ocultarse',
          direccionPaciente: 'Calle falsa',
          latitud: 10.4631,
          longitud: -73.2532,
          precisionGpsM: 8.4,
          ubicacionCapturadaAt: date,
          telefonoPaciente: '3001234567',
          consentimientoDatos: false,
        ),
        result: const TriageResult(
          riskLevel: RiskLevel.bajo,
          probAlto: 0.1,
          probMedio: 0.2,
          probBajo: 0.7,
          riesgoDesenlaceAdverso: false,
          probDesenlaceAdverso: 0.1,
          clinicalAlerts: [],
          hasImmediateEmergency: false,
        ),
        uuid: '97c76ec7-9228-4de0-88c3-f2efee432939',
        ownerId: 'doctor-1',
        consentimientoAt: date,
        fechaGuardado: date,
      );

      final local = AssessmentModel(record: record).toMap();
      expect(local['consentimiento_datos'], 0);
      expect(local['telefono_paciente'], isNull);
      expect(local['nombre_paciente'], isNull);
      expect(local['direccion_paciente'], isNull);
      expect(local['latitud'], isNull);
      expect(local['longitud'], isNull);
      expect(local['precision_gps_m'], isNull);
      expect(local['ubicacion_capturada_at'], isNull);
      expect(local['consentimiento_at'], isNull);
    },
  );
}
