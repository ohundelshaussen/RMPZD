import '../entities/patient_assessment.dart';
import '../entities/triage_result.dart';
import '../repositories/assessment_repository.dart';

class SaveAssessmentUseCase {
  final AssessmentRepository repository;

  SaveAssessmentUseCase(this.repository);

  Future<int> execute(
    PatientAssessment patient,
    TriageResult result, {
    required String ownerId,
  }) async {
    return repository.saveAssessment(patient, result, ownerId: ownerId);
  }
}
