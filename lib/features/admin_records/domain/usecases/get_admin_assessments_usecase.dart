import '../entities/remote_assessment.dart';
import '../repositories/admin_records_repository.dart';

class GetAdminAssessmentsUseCase {
  final AdminRecordsRepository _repository;

  const GetAdminAssessmentsUseCase(this._repository);

  Future<List<RemoteAssessment>> execute({
    required int offset,
    int limit = 30,
    AdminAssessmentFilters filters = const AdminAssessmentFilters(),
  }) {
    return _repository.getAssessments(
      offset: offset,
      limit: limit,
      filters: filters,
    );
  }
}
