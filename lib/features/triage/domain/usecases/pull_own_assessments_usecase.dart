import '../repositories/assessment_repository.dart';

class PullOwnAssessmentsUseCase {
  final AssessmentRepository repository;

  const PullOwnAssessmentsUseCase(this.repository);

  Future<int> execute({required String ownerId}) {
    return repository.pullOwnAssessments(ownerId: ownerId);
  }
}
