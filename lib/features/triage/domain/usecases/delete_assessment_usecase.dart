import '../repositories/assessment_repository.dart';

class DeleteAssessmentUseCase {
  final AssessmentRepository repository;

  const DeleteAssessmentUseCase(this.repository);

  Future<void> execute({required String uuid}) {
    return repository.deleteAssessment(uuid: uuid);
  }
}
