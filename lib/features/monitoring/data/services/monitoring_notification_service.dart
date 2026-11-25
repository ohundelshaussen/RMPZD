import '../../domain/entities/monitoring_case.dart';

abstract interface class MonitoringNotificationService {
  Stream<String> get openedCaseIds;
  String? takeInitialCaseId();

  Future<void> initialize();
  Future<void> requestPermission();
  Future<void> show(MonitoringAlert alert);
}
