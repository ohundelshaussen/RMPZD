import '../entities/patient_assessment.dart';
import '../entities/triage_result.dart';

abstract class RiskClassifier {
  Future<TriageResult> classify(PatientAssessment patient);
}
