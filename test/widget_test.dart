import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/app/app.dart';
import 'package:rmpzd/features/history/presentation/providers/history_provider.dart';
import 'package:rmpzd/features/triage/domain/entities/assessment_record.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';
import 'package:rmpzd/features/triage/domain/repositories/assessment_repository.dart';
import 'package:rmpzd/features/triage/domain/services/risk_classifier.dart';
import 'package:rmpzd/features/triage/domain/usecases/evaluate_maternal_risk_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/get_assessment_history_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/get_unsynced_count_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/save_assessment_usecase.dart';
import 'package:rmpzd/features/triage/presentation/providers/triage_provider.dart';

void main() {
  testWidgets('RMPZD starts on the triage form with injected dependencies', (
    tester,
  ) async {
    final repository = _FakeAssessmentRepository();
    final providers = [
      ChangeNotifierProvider(
        create: (_) => TriageProvider(
          evaluateMaternalRisk: EvaluateMaternalRiskUseCase(
            _FakeRiskClassifier(),
          ),
          saveAssessment: SaveAssessmentUseCase(repository),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => HistoryProvider(
          getAssessmentHistory: GetAssessmentHistoryUseCase(repository),
          getUnsyncedCount: GetUnsyncedCountUseCase(repository),
        ),
      ),
    ];

    await tester.pumpWidget(RmpzdApp(providers: providers));
    await tester.pump();

    expect(find.text('Triage Materno'), findsOneWidget);
    expect(find.text('EVALUAR RIESGO OBSTÉTRICO'), findsOneWidget);
  });
}

class _FakeRiskClassifier implements RiskClassifier {
  @override
  Future<TriageResult> classify(PatientAssessment patient) {
    throw UnimplementedError('The smoke test does not submit the form.');
  }
}

class _FakeAssessmentRepository implements AssessmentRepository {
  @override
  Future<List<AssessmentRecord>> getHistory() async => [];

  @override
  Future<int> getUnsyncedCount() async => 0;

  @override
  Future<int> saveAssessment(
    PatientAssessment patient,
    TriageResult result,
  ) async => 1;
}
