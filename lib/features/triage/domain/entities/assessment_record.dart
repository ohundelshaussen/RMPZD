import 'patient_assessment.dart';
import 'triage_result.dart';

class AssessmentRecord {
  final PatientAssessment patient;
  final TriageResult result;
  final int? idLocal;
  final DateTime fechaGuardado;
  final bool sincronizado;

  const AssessmentRecord({
    required this.patient,
    required this.result,
    this.idLocal,
    required this.fechaGuardado,
    this.sincronizado = false,
  });
}
