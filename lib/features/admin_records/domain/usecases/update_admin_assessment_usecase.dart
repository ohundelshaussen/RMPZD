import '../entities/remote_assessment.dart';
import '../repositories/admin_records_repository.dart';

class UpdateAdminAssessmentUseCase {
  final AdminRecordsRepository _repository;

  const UpdateAdminAssessmentUseCase(this._repository);

  Future<RemoteAssessment> execute({
    required String id,
    required Map<String, dynamic> updates,
  }) {
    return _repository.updateAssessment(id: id, updates: updates);
  }
}
