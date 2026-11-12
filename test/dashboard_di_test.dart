import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/app/di.dart';
import 'package:rmpzd/core/database/database_helper.dart';
import 'package:rmpzd/core/network/connectivity_service.dart';
import 'package:rmpzd/core/sync/sync_provider.dart';
import 'package:rmpzd/core/sync/sync_service.dart';
import 'package:rmpzd/features/admin_records/data/datasources/admin_records_remote_datasource.dart';
import 'package:rmpzd/features/admin_records/domain/repositories/admin_records_repository.dart';
import 'package:rmpzd/features/admin_records/domain/usecases/get_admin_assessments_usecase.dart';
import 'package:rmpzd/features/admin_records/presentation/providers/admin_records_provider.dart';
import 'package:rmpzd/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:rmpzd/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:rmpzd/features/auth/data/datasources/network_status_datasource.dart';
import 'package:rmpzd/features/auth/domain/repositories/auth_repository.dart';
import 'package:rmpzd/features/auth/domain/usecases/get_current_profile_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:rmpzd/features/auth/presentation/providers/auth_provider.dart';
import 'package:rmpzd/features/dashboard/data/datasources/dashboard_local_cache.dart';
import 'package:rmpzd/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:rmpzd/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:rmpzd/features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';
import 'package:rmpzd/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:rmpzd/features/history/presentation/providers/history_provider.dart';
import 'package:rmpzd/features/triage/data/datasources/ai_inference_engine.dart';
import 'package:rmpzd/features/triage/data/datasources/assessment_local_datasource.dart';
import 'package:rmpzd/features/triage/data/datasources/assessment_remote_datasource.dart';
import 'package:rmpzd/features/triage/data/datasources/clinical_rules_engine.dart';
import 'package:rmpzd/features/triage/domain/repositories/assessment_repository.dart';
import 'package:rmpzd/features/triage/domain/services/risk_classifier.dart';
import 'package:rmpzd/features/triage/domain/usecases/evaluate_maternal_risk_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/get_assessment_history_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/get_unsynced_count_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/save_assessment_usecase.dart';
import 'package:rmpzd/features/triage/presentation/providers/triage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'createAppProviders resolves every provider in declaration order',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MultiProvider(
          providers: createAppProviders(
            supabaseClient: null,
            sharedPreferences: preferences,
          ),
          child: Builder(
            builder: (context) {
              final providers = <Object>[
                context.read<ConnectivityService>(),
                context.read<NetworkStatusDataSource>(),
                context.read<AuthRemoteDataSource>(),
                context.read<AuthLocalDataSource>(),
                context.read<AuthRepository>(),
                context.read<SignInUseCase>(),
                context.read<SignOutUseCase>(),
                context.read<GetCurrentProfileUseCase>(),
                context.read<AuthProvider>(),
                context.read<AdminRecordsRemoteDataSource>(),
                context.read<AdminRecordsRepository>(),
                context.read<GetAdminAssessmentsUseCase>(),
                context.read<AdminRecordsProvider>(),
                context.read<DashboardRemoteDataSource>(),
                context.read<DashboardLocalCache>(),
                context.read<DashboardRepository>(),
                context.read<GetDashboardStatsUseCase>(),
                context.read<DashboardProvider>(),
                context.read<DatabaseHelper>(),
                context.read<AssessmentLocalDataSource>(),
                context.read<AssessmentRemoteDataSource>(),
                context.read<ClinicalRulesEngine>(),
                context.read<AiInferenceEngine>(),
                context.read<AssessmentRepository>(),
                context.read<RiskClassifier>(),
                context.read<EvaluateMaternalRiskUseCase>(),
                context.read<SaveAssessmentUseCase>(),
                context.read<GetAssessmentHistoryUseCase>(),
                context.read<GetUnsyncedCountUseCase>(),
                context.read<SyncService>(),
                context.read<HistoryProvider>(),
                context.read<SyncProvider>(),
                context.read<TriageProvider>(),
              ];
              expect(providers, hasLength(33));
              return const SizedBox();
            },
          ),
        ),
      );
    },
  );
}
