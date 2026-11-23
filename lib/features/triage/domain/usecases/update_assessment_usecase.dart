import '../entities/assessment_record.dart';
import '../entities/patient_assessment.dart';
import '../entities/triage_result.dart';
import '../repositories/assessment_repository.dart';

class UpdateAssessmentUseCase {
  final AssessmentRepository repository;

  const UpdateAssessmentUseCase(this.repository);

  Future<AssessmentRecord> execute(
    AssessmentRecord existingRecord,
    PatientAssessment updatedPatient,
    TriageResult updatedResult,
  ) {
    return repository.updateAssessment(
      existingRecord,
      updatedPatient,
      updatedResult,
    );
  }
}
