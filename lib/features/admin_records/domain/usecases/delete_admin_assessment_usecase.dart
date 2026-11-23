import '../repositories/admin_records_repository.dart';

class DeleteAdminAssessmentUseCase {
  final AdminRecordsRepository _repository;

  const DeleteAdminAssessmentUseCase(this._repository);

  Future<void> execute({required String id}) {
    return _repository.deleteAssessment(id: id);
  }
}
