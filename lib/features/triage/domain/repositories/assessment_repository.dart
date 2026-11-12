import '../entities/assessment_record.dart';
import '../entities/patient_assessment.dart';
import '../entities/triage_result.dart';

abstract class AssessmentRepository {
  Future<int> saveAssessment(
    PatientAssessment patient,
    TriageResult result, {
    required String ownerId,
  });
  Future<List<AssessmentRecord>> getHistory({required String ownerId});
  Future<int> getUnsyncedCount({required String ownerId});
}
