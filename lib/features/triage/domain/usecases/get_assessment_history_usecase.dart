import '../entities/assessment_record.dart';
import '../repositories/assessment_repository.dart';

class GetAssessmentHistoryUseCase {
  final AssessmentRepository repository;

  GetAssessmentHistoryUseCase(this.repository);

  Future<List<AssessmentRecord>> execute() async {
    return repository.getHistory();
  }
}
