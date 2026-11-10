import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/features/triage/data/datasources/clinical_rules_engine.dart';
import 'package:rmpzd/features/triage/domain/entities/clinical_alert.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';

void main() {
  late ClinicalRulesEngine rulesEngine;

  setUp(() {
    rulesEngine = ClinicalRulesEngine();
  });

  test('Crisis hipertensiva (PA >= 160/110) debe disparar Emergencia Inmediata', () {
    final patient = PatientAssessment(
      patientId: 'TEST-01',
      municipio: 'Uribia',
      departamento: 'La Guajira',
      etnia: 'Wayuu',
      zona: 'Rural dispersa',
      edadMaterna: 30,
      semanasGestacion: 32,
      numeroControles: 1,
      distanciaKm: 80.0,
      tiempoTrasladoHoras: 4.0,
      hemoglobina: 10.5,
      presionSistolica: 165.0,
      presionDiastolica: 112.0,
      imc: 29.0,
      antecedentePreeclampsia: true,
      antecedenteDiabetes: false,
      partoInstitucionalPrevio: false,
      afiliacionSgsss: 'Subsidiado',
      fechaEvaluacion: DateTime.now(),
    );

    final alerts = rulesEngine.evaluate(patient);
    final hasEmergency = alerts.any((a) => a.severity == AlertSeverity.immediateEmergency);

    expect(hasEmergency, isTrue);
    expect(alerts.any((a) => a.title.contains('Crisis Hipertensiva')), isTrue);
  });

  test('Paciente normal y estable no debe tener emergencias inmediatas', () {
    final patient = PatientAssessment(
      patientId: 'TEST-02',
      municipio: 'Valledupar',
      departamento: 'Cesar',
      etnia: 'No Indígena',
      zona: 'Urbana',
      edadMaterna: 25,
      semanasGestacion: 20,
      numeroControles: 4,
      distanciaKm: 2.0,
      tiempoTrasladoHoras: 0.3,
      hemoglobina: 12.5,
      presionSistolica: 115.0,
      presionDiastolica: 75.0,
      imc: 23.0,
      antecedentePreeclampsia: false,
      antecedenteDiabetes: false,
      partoInstitucionalPrevio: true,
      afiliacionSgsss: 'Contributivo',
      fechaEvaluacion: DateTime.now(),
    );

    final alerts = rulesEngine.evaluate(patient);
    final hasEmergency = alerts.any((a) => a.severity == AlertSeverity.immediateEmergency);

    expect(hasEmergency, isFalse);
  });
}
