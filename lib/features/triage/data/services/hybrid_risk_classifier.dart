import '../../domain/entities/clinical_alert.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/services/risk_classifier.dart';
import '../datasources/ai_inference_engine.dart';
import '../datasources/clinical_rules_engine.dart';

class HybridRiskClassifier implements RiskClassifier {
  final ClinicalRulesEngine rulesEngine;
  final AiInferenceEngine aiEngine;

  HybridRiskClassifier({required this.rulesEngine, required this.aiEngine});

  @override
  Future<TriageResult> classify(PatientAssessment patient) async {
    // 1. Capa Determinista (Reglas Clínicas Obstétricas)
    final alerts = rulesEngine.evaluate(patient);
    final hasEmergency = alerts.any(
      (a) => a.severity == AlertSeverity.immediateEmergency,
    );

    // 2. Capa Estadística (Modelo Predictivo IA)
    final aiPrediction = await aiEngine.predict(patient);

    var finalRiskLevel = aiPrediction.riskLevel;

    // Si hay una emergencia médica obstétrica inmediata (ej. crisis hipertensiva >= 160/110),
    // el sistema híbrido eleva de inmediato el nivel a ALTO con prioridad clínica absoluta.
    if (hasEmergency) {
      finalRiskLevel = RiskLevel.alto;
    }

    return TriageResult(
      riskLevel: finalRiskLevel,
      probAlto: aiPrediction.probAlto,
      probMedio: aiPrediction.probMedio,
      probBajo: aiPrediction.probBajo,
      riesgoDesenlaceAdverso: aiPrediction.riesgoDesenlaceAdverso,
      probDesenlaceAdverso: aiPrediction.probDesenlaceAdverso,
      clinicalAlerts: alerts,
      hasImmediateEmergency: hasEmergency,
    );
  }
}
