import '../entities/patient_assessment.dart';
import '../entities/triage_result.dart';
import '../services/risk_classifier.dart';

class EvaluateMaternalRiskUseCase {
  final RiskClassifier classifier;

  EvaluateMaternalRiskUseCase(this.classifier);

  Future<TriageResult> execute(PatientAssessment patient) async {
    return classifier.classify(patient);
  }
}
