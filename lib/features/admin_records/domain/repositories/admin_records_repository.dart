import '../entities/remote_assessment.dart';

class AdminAssessmentFilters {
  final String? doctorId;
  final String? riskLevel;
  final String? department;
  final DateTime? fromDate;
  final DateTime? toDate;

  const AdminAssessmentFilters({
    this.doctorId,
    this.riskLevel,
    this.department,
    this.fromDate,
    this.toDate,
  });
}

abstract interface class AdminRecordsRepository {
  Future<List<RemoteAssessment>> getAssessments({
    required int offset,
    required int limit,
    AdminAssessmentFilters filters = const AdminAssessmentFilters(),
  });
}
