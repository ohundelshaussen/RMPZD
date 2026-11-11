import '../entities/assessment_record.dart';
import '../entities/patient_assessment.dart';
import '../entities/triage_result.dart';

abstract class AssessmentRepository {
  Future<int> saveAssessment(PatientAssessment patient, TriageResult result);
  Future<List<AssessmentRecord>> getHistory();
  Future<int> getUnsyncedCount();
}
