import '../entities/patient_assessment.dart';
import '../entities/triage_result.dart';

abstract class AssessmentRepository {
  Future<TriageResult> evaluateRisk(PatientAssessment patient);
  Future<int> saveAssessment(PatientAssessment patient, TriageResult result);
  Future<List<Map<String, dynamic>>> getHistory();
  Future<int> getUnsyncedCount();
}
