import '../../domain/entities/clinical_alert.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/repositories/assessment_repository.dart';
import '../datasources/ai_inference_engine.dart';
import '../datasources/assessment_local_datasource.dart';
import '../datasources/clinical_rules_engine.dart';

class AssessmentRepositoryImpl implements AssessmentRepository {
  final ClinicalRulesEngine rulesEngine;
  final AiInferenceEngine aiEngine;
  final AssessmentLocalDataSource localDataSource;

  AssessmentRepositoryImpl({
    ClinicalRulesEngine? rulesEngine,
    AiInferenceEngine? aiEngine,
    AssessmentLocalDataSource? localDataSource,
  })  : rulesEngine = rulesEngine ?? ClinicalRulesEngine(),
        aiEngine = aiEngine ?? AiInferenceEngine(),
        localDataSource = localDataSource ?? AssessmentLocalDataSource();

  @override
  Future<TriageResult> evaluateRisk(PatientAssessment patient) async {
    // 1. Capa Determinista (Reglas Clínicas Obstétricas)
    final alerts = rulesEngine.evaluate(patient);
    final hasEmergency = alerts.any(
      (a) => a.severity == AlertSeverity.immediateEmergency,
    );

    // 2. Capa Estadística (Modelo Predictivo IA)
    final aiPrediction = await aiEngine.predict(patient);

    var finalRiskLevel = aiPrediction['risk_level'] as RiskLevel;

    // Si hay una emergencia médica obstétrica inmediata (ej. crisis hipertensiva >= 160/110),
    // el sistema híbrido eleva de inmediato el nivel a ALTO con prioridad clínica absoluta.
    if (hasEmergency) {
      finalRiskLevel = RiskLevel.alto;
    }

    return TriageResult(
      riskLevel: finalRiskLevel,
      probAlto: aiPrediction['prob_alto'] as double,
      probMedio: aiPrediction['prob_medio'] as double,
      probBajo: aiPrediction['prob_bajo'] as double,
      riesgoDesenlaceAdverso:
          aiPrediction['riesgo_desenlace_adverso'] as bool,
      probDesenlaceAdverso:
          aiPrediction['prob_desenlace_adverso'] as double,
      clinicalAlerts: alerts,
      hasImmediateEmergency: hasEmergency,
    );
  }

  @override
  Future<int> saveAssessment(
      PatientAssessment patient, TriageResult result) async {
    return await localDataSource.insertAssessment(
      patient: patient,
      result: result,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory() async {
    return await localDataSource.getAssessments();
  }

  @override
  Future<int> getUnsyncedCount() async {
    return await localDataSource.getUnsyncedCount();
  }
}
