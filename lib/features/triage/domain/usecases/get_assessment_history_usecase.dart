import '../entities/assessment_record.dart';
import '../repositories/assessment_repository.dart';

class GetAssessmentHistoryUseCase {
  final AssessmentRepository repository;

  GetAssessmentHistoryUseCase(this.repository);

  Future<List<AssessmentRecord>> execute({required String ownerId}) async {
    return repository.getHistory(ownerId: ownerId);
  }
}
