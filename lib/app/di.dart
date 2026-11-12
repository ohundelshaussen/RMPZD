import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/network/connectivity_service.dart';
import '../core/sync/sync_provider.dart';
import '../core/sync/sync_service.dart';
import '../core/database/database_helper.dart';
import '../features/auth/data/datasources/auth_local_datasource.dart';
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/datasources/network_status_datasource.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/get_current_profile_usecase.dart';
import '../features/auth/domain/usecases/sign_in_usecase.dart';
import '../features/auth/domain/usecases/sign_out_usecase.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/admin_records/data/datasources/admin_records_remote_datasource.dart';
import '../features/admin_records/data/repositories/admin_records_repository_impl.dart';
import '../features/admin_records/domain/repositories/admin_records_repository.dart';
import '../features/admin_records/domain/usecases/get_admin_assessments_usecase.dart';
import '../features/admin_records/presentation/providers/admin_records_provider.dart';
import '../features/dashboard/data/datasources/dashboard_local_cache.dart';
import '../features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import '../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';
import '../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../features/history/presentation/providers/history_provider.dart';
import '../features/triage/data/datasources/ai_inference_engine.dart';
import '../features/triage/data/datasources/assessment_local_datasource.dart';
import '../features/triage/data/datasources/assessment_remote_datasource.dart';
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

List<SingleChildWidget> createAppProviders({
  required SupabaseClient? supabaseClient,
  required SharedPreferences sharedPreferences,
  String? authInitializationError,
}) {
  return [
    Provider<ConnectivityService>(
      create: (_) => ConnectivityService(
        connectivity: Connectivity(),
        client: supabaseClient,
      ),
    ),
    Provider<NetworkStatusDataSource>(
      create: (_) => NetworkStatusDataSource(connectivity: Connectivity()),
    ),
    Provider<AuthRemoteDataSource>(
      create: (context) => AuthRemoteDataSource(
        client: supabaseClient,
        networkStatus: context.read<NetworkStatusDataSource>(),
        initializationError: authInitializationError,
      ),
    ),
    Provider<AuthLocalDataSource>(
      create: (_) => AuthLocalDataSource(preferences: sharedPreferences),
    ),
    Provider<AuthRepository>(
      create: (context) => AuthRepositoryImpl(
        remoteDataSource: context.read<AuthRemoteDataSource>(),
        localDataSource: context.read<AuthLocalDataSource>(),
      ),
    ),
    Provider<SignInUseCase>(
      create: (context) => SignInUseCase(context.read<AuthRepository>()),
    ),
    Provider<SignOutUseCase>(
      create: (context) => SignOutUseCase(context.read<AuthRepository>()),
    ),
    Provider<GetCurrentProfileUseCase>(
      create: (context) =>
          GetCurrentProfileUseCase(context.read<AuthRepository>()),
    ),
    ChangeNotifierProvider<AuthProvider>(
      create: (context) => AuthProvider(
        signInUseCase: context.read<SignInUseCase>(),
        signOutUseCase: context.read<SignOutUseCase>(),
        getCurrentProfileUseCase: context.read<GetCurrentProfileUseCase>(),
        repository: context.read<AuthRepository>(),
      ),
    ),
    Provider<AdminRecordsRemoteDataSource>(
      create: (_) =>
          SupabaseAdminRecordsRemoteDataSource(client: supabaseClient),
    ),
    Provider<AdminRecordsRepository>(
      create: (context) => AdminRecordsRepositoryImpl(
        context.read<AdminRecordsRemoteDataSource>(),
      ),
    ),
    Provider<GetAdminAssessmentsUseCase>(
      create: (context) =>
          GetAdminAssessmentsUseCase(context.read<AdminRecordsRepository>()),
    ),
    ChangeNotifierProvider<AdminRecordsProvider>(
      create: (context) => AdminRecordsProvider(
        getAssessments: context.read<GetAdminAssessmentsUseCase>(),
        connectivityService: context.read<ConnectivityService>(),
      ),
    ),
    Provider<DashboardRemoteDataSource>(
      create: (_) =>
          SupabaseDashboardRemoteDataSource(client: supabaseClient),
    ),
    Provider<DashboardLocalCache>(
      create: (_) => DashboardLocalCache(preferences: sharedPreferences),
    ),
    Provider<DashboardRepository>(
      create: (context) => DashboardRepositoryImpl(
        remoteDataSource: context.read<DashboardRemoteDataSource>(),
        localCache: context.read<DashboardLocalCache>(),
      ),
    ),
    Provider<GetDashboardStatsUseCase>(
      create: (context) =>
          GetDashboardStatsUseCase(context.read<DashboardRepository>()),
    ),
    ChangeNotifierProvider<DashboardProvider>(
      create: (context) => DashboardProvider(
        getStats: context.read<GetDashboardStatsUseCase>(),
        repository: context.read<DashboardRepository>(),
      ),
    ),
    Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),
    Provider<AssessmentLocalDataSource>(
      create: (context) =>
          AssessmentLocalDataSource(dbHelper: context.read<DatabaseHelper>()),
    ),
    Provider<AssessmentRemoteDataSource>(
      create: (_) => SupabaseAssessmentRemoteDataSource(client: supabaseClient),
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
    Provider<SyncService>(
      create: (context) => SyncService(
        localDataSource: context.read<AssessmentLocalDataSource>(),
        remoteDataSource: context.read<AssessmentRemoteDataSource>(),
        hasInternet: context.read<ConnectivityService>().hasInternet,
        currentOwnerId: () => context.read<AuthProvider>().profile?.id,
        hasSession: () => context.read<AuthProvider>().profile != null,
      ),
    ),
    ChangeNotifierProvider<HistoryProvider>(
      create: (context) => HistoryProvider(
        getAssessmentHistory: context.read<GetAssessmentHistoryUseCase>(),
        getUnsyncedCount: context.read<GetUnsyncedCountUseCase>(),
        currentOwnerId: () => context.read<AuthProvider>().profile?.id,
      ),
    ),
    ChangeNotifierProvider<SyncProvider>(
      lazy: false,
      create: (context) => SyncProvider(
        syncService: context.read<SyncService>(),
        connectivityService: context.read<ConnectivityService>(),
        authProvider: context.read<AuthProvider>(),
        getUnsyncedCount: context.read<GetUnsyncedCountUseCase>(),
        onSyncComplete: () => context.read<HistoryProvider>().loadHistory(),
      ),
    ),
    ChangeNotifierProvider<TriageProvider>(
      create: (context) => TriageProvider(
        evaluateMaternalRisk: context.read<EvaluateMaternalRiskUseCase>(),
        saveAssessment: context.read<SaveAssessmentUseCase>(),
        currentOwnerId: () => context.read<AuthProvider>().profile?.id,
        onAssessmentSaved: () async {
          final syncProvider = context.read<SyncProvider>();
          await syncProvider.syncNow();
        },
      ),
    ),
  ];
}
