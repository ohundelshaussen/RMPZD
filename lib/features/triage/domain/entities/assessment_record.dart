import 'patient_assessment.dart';
import 'triage_result.dart';

enum SyncStatus { pending, synced, error }

class AssessmentRecord {
  final PatientAssessment patient;
  final TriageResult result;
  final int? idLocal;
  final String uuid;
  final String? ownerId;
  final SyncStatus syncStatus;
  final String? lastSyncError;
  final DateTime fechaGuardado;

  const AssessmentRecord({
    required this.patient,
    required this.result,
    this.idLocal,
    required this.uuid,
    required this.ownerId,
    this.syncStatus = SyncStatus.pending,
    this.lastSyncError,
    required this.fechaGuardado,
  });

  bool get isSynced => syncStatus == SyncStatus.synced;
}
