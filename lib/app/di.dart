import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../core/database/database_helper.dart';
import '../features/history/presentation/providers/history_provider.dart';
import '../features/triage/data/datasources/ai_inference_engine.dart';
import '../features/triage/data/datasources/assessment_local_datasource.dart';
import '../features/triage/data/datasources/clinical_rules_engine.dart';
import '../features/triage/data/repositories/assessment_repository_impl.dart';
import '../features/triage/data/services/hybrid_risk_classifier.dart';
import '../features/triage/domain/repositories/assessment_repository.dart';
import '../features/triage/domain/services/risk_classifier.dart';
import '../features/triage/domain/usecases/evaluate_maternal_risk_usecase.dart';
import '../features/triage/domain/usecases/get_assessment_history_usecase.dart';
import '../features/triage/domain/usecases/get_unsynced_count_usecase.dart';
import '../features/triage/domain/usecases/save_assessment_usecase.dart';
import '../features/triage/presentation/providers/triage_provider.dart';

List<SingleChildWidget> createAppProviders() {
  return [
    Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),
    Provider<AssessmentLocalDataSource>(
      create: (context) =>
          AssessmentLocalDataSource(dbHelper: context.read<DatabaseHelper>()),
    ),
    Provider<ClinicalRulesEngine>(create: (_) => ClinicalRulesEngine()),
    Provider<AiInferenceEngine>(create: (_) => AiInferenceEngine()),
    Provider<AssessmentRepository>(
      create: (context) => AssessmentRepositoryImpl(
        localDataSource: context.read<AssessmentLocalDataSource>(),
      ),
    ),
    Provider<RiskClassifier>(
      create: (context) => HybridRiskClassifier(
        rulesEngine: context.read<ClinicalRulesEngine>(),
        aiEngine: context.read<AiInferenceEngine>(),
      ),
    ),
    Provider<EvaluateMaternalRiskUseCase>(
      create: (context) =>
          EvaluateMaternalRiskUseCase(context.read<RiskClassifier>()),
    ),
    Provider<SaveAssessmentUseCase>(
      create: (context) =>
          SaveAssessmentUseCase(context.read<AssessmentRepository>()),
    ),
    Provider<GetAssessmentHistoryUseCase>(
      create: (context) =>
          GetAssessmentHistoryUseCase(context.read<AssessmentRepository>()),
    ),
    Provider<GetUnsyncedCountUseCase>(
      create: (context) =>
          GetUnsyncedCountUseCase(context.read<AssessmentRepository>()),
    ),
    ChangeNotifierProvider<TriageProvider>(
      create: (context) => TriageProvider(
        evaluateMaternalRisk: context.read<EvaluateMaternalRiskUseCase>(),
        saveAssessment: context.read<SaveAssessmentUseCase>(),
      ),
    ),
    ChangeNotifierProvider<HistoryProvider>(
      create: (context) => HistoryProvider(
        getAssessmentHistory: context.read<GetAssessmentHistoryUseCase>(),
        getUnsyncedCount: context.read<GetUnsyncedCountUseCase>(),
      ),
    ),
  ];
}
