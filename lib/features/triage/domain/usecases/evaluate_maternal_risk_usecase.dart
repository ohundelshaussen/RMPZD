import '../entities/patient_assessment.dart';
import '../entities/triage_result.dart';
import '../repositories/assessment_repository.dart';

class EvaluateMaternalRiskUseCase {
  final AssessmentRepository repository;

  EvaluateMaternalRiskUseCase(this.repository);

  Future<TriageResult> execute(PatientAssessment patient) async {
    return await repository.evaluateRisk(patient);
  }
}
