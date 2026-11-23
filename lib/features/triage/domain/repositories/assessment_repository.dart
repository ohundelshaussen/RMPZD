import '../entities/assessment_record.dart';
import '../entities/patient_assessment.dart';
import '../entities/triage_result.dart';

abstract class AssessmentRepository {
  Future<AssessmentRecord> saveAssessment(
    PatientAssessment patient,
    TriageResult result, {
    required String ownerId,
  });
  Future<AssessmentRecord> updateAssessment(
    AssessmentRecord existingRecord,
    PatientAssessment updatedPatient,
    TriageResult updatedResult,
  );
  Future<void> deleteAssessment({required String uuid});
  Future<List<AssessmentRecord>> getHistory({required String ownerId});
  Future<int> getUnsyncedCount({required String ownerId});
}
