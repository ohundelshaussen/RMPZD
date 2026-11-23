import '../../domain/entities/remote_assessment.dart';
import '../../domain/repositories/admin_records_repository.dart';
import '../datasources/admin_records_remote_datasource.dart';

class AdminRecordsRepositoryImpl implements AdminRecordsRepository {
  final AdminRecordsRemoteDataSource _remoteDataSource;

  const AdminRecordsRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<RemoteAssessment>> getAssessments({
    required int offset,
    required int limit,
    AdminAssessmentFilters filters = const AdminAssessmentFilters(),
  }) async {
    final rows = await _remoteDataSource.fetchAssessments(
      offset: offset,
      limit: limit,
      filters: filters,
    );
    return rows.map(RemoteAssessment.fromJson).toList();
  }

  @override
  Future<RemoteAssessment> updateAssessment({
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    final row = await _remoteDataSource.updateAssessment(
      id: id,
      updates: updates,
    );
    return RemoteAssessment.fromJson(row);
  }

  @override
  Future<void> deleteAssessment({required String id}) async {
    await _remoteDataSource.deleteAssessment(id: id);
  }
}
