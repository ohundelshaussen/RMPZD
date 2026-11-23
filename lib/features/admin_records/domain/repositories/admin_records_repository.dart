import '../entities/remote_assessment.dart';

class AdminPermissionException implements Exception {
  final String message;

  const AdminPermissionException(this.message);

  @override
  String toString() => message;
}

class AdminAssessmentFilters {
  final String? doctorId;
  final String? riskLevel;
  final String? department;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? searchQuery;

  const AdminAssessmentFilters({
    this.doctorId,
    this.riskLevel,
    this.department,
    this.fromDate,
    this.toDate,
    this.searchQuery,
  });

  bool get hasActiveFilters =>
      doctorId != null ||
      riskLevel != null ||
      department != null ||
      fromDate != null ||
      toDate != null ||
      (searchQuery != null && searchQuery!.trim().isNotEmpty);

  int get activeFilterCount {
    var count = 0;
    if (doctorId != null) count++;
    if (riskLevel != null) count++;
    if (department != null) count++;
    if (fromDate != null || toDate != null) count++;
    if (searchQuery != null && searchQuery!.trim().isNotEmpty) count++;
    return count;
  }
}

abstract interface class AdminRecordsRepository {
  Future<List<RemoteAssessment>> getAssessments({
    required int offset,
    required int limit,
    AdminAssessmentFilters filters = const AdminAssessmentFilters(),
  });

  Future<RemoteAssessment> updateAssessment({
    required String id,
    required Map<String, dynamic> updates,
  });

  Future<void> deleteAssessment({required String id});
}
