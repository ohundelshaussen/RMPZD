import '../repositories/assessment_repository.dart';

class GetUnsyncedCountUseCase {
  final AssessmentRepository repository;

  GetUnsyncedCountUseCase(this.repository);

  Future<int> execute() async {
    return repository.getUnsyncedCount();
  }
}
