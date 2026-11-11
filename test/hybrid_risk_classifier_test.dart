import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/features/triage/data/datasources/ai_inference_engine.dart';
import 'package:rmpzd/features/triage/data/datasources/clinical_rules_engine.dart';
import 'package:rmpzd/features/triage/data/services/hybrid_risk_classifier.dart';
import 'package:rmpzd/features/triage/domain/entities/ai_prediction.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';

void main() {
  test('immediate emergency overrides a low AI risk level', () async {
    final classifier = HybridRiskClassifier(
      rulesEngine: ClinicalRulesEngine(),
      aiEngine: _FakeAiInferenceEngine(
        const AiPrediction(
          riskLevel: RiskLevel.bajo,
          probAlto: 0.1,
          probMedio: 0.2,
          probBajo: 0.7,
          riesgoDesenlaceAdverso: false,
          probDesenlaceAdverso: 0.1,
        ),
      ),
    );

    final result = await classifier.classify(_emergencyPatient());

    expect(result.riskLevel, RiskLevel.alto);
    expect(result.hasImmediateEmergency, isTrue);
    expect(result.probBajo, 0.7);
  });
}

class _FakeAiInferenceEngine extends AiInferenceEngine {
  final AiPrediction prediction;

  _FakeAiInferenceEngine(this.prediction);

  @override
  Future<AiPrediction> predict(PatientAssessment patient) async => prediction;
}

PatientAssessment _emergencyPatient() {
  return PatientAssessment(
    patientId: 'MP-EMERGENCY',
    municipio: 'Uribia',
    departamento: 'La Guajira',
    etnia: 'Wayuu',
    zona: 'Rural dispersa',
    edadMaterna: 33,
    semanasGestacion: 34,
    numeroControles: 1,
    distanciaKm: 78,
    tiempoTrasladoHoras: 4.5,
    hemoglobina: 8.1,
    presionSistolica: 165,
    presionDiastolica: 112,
    imc: 31.5,
    antecedentePreeclampsia: true,
    antecedenteDiabetes: false,
    partoInstitucionalPrevio: false,
    afiliacionSgsss: 'Subsidiado',
    fechaEvaluacion: DateTime(2026),
  );
}
