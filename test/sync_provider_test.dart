import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/app/di.dart';
import 'package:rmpzd/core/database/database_helper.dart';
import 'package:rmpzd/core/network/connectivity_service.dart';
import 'package:rmpzd/core/sync/sync_provider.dart';
import 'package:rmpzd/core/sync/sync_service.dart';
import 'package:rmpzd/features/auth/domain/entities/user_profile.dart';
import 'package:rmpzd/features/auth/domain/repositories/auth_repository.dart';
import 'package:rmpzd/features/auth/domain/usecases/get_current_profile_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:rmpzd/features/auth/presentation/providers/auth_provider.dart';
import 'package:rmpzd/features/history/presentation/providers/history_provider.dart';
import 'package:rmpzd/features/triage/data/datasources/assessment_local_datasource.dart';
import 'package:rmpzd/features/triage/data/datasources/assessment_remote_datasource.dart';
import 'package:rmpzd/features/triage/data/repositories/assessment_repository_impl.dart';
import 'package:rmpzd/features/triage/domain/entities/assessment_record.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';
import 'package:rmpzd/features/triage/domain/repositories/assessment_repository.dart';
import 'package:rmpzd/features/triage/domain/usecases/get_assessment_history_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/get_unsynced_count_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('sync completion reloads history and updates record status', (
    tester,
  ) async {
    final fixture = await _createFixture();
    addTearDown(fixture.database.close);
    await fixture.repository.saveAssessment(
      _patient,
      _result,
      ownerId: 'doctor-1',
    );
    final historyProvider = _TrackingHistoryProvider(
      getAssessmentHistory: GetAssessmentHistoryUseCase(fixture.repository),
      getUnsyncedCount: GetUnsyncedCountUseCase(fixture.repository),
      currentOwnerId: () => 'doctor-1',
    );
    final authProvider = _authProvider();
    final syncProvider = SyncProvider(
      syncService: fixture.syncService,
      connectivityService: _FakeConnectivityService(),
      authProvider: authProvider,
      getUnsyncedCount: GetUnsyncedCountUseCase(fixture.repository),
      onSyncComplete: historyProvider.loadHistory,
    );
    addTearDown(authProvider.dispose);
    addTearDown(syncProvider.dispose);
    addTearDown(historyProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HistoryProvider>.value(value: historyProvider),
          ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      ),
    );

    await authProvider.signIn('doctor@example.test', 'password');
    await tester.runAsync(() async {
      await historyProvider.loadCompleted.future.timeout(
        const Duration(seconds: 2),
      );
    });

    expect(historyProvider.loadCalls, greaterThan(0));
    expect(historyProvider.history, hasLength(1));
    expect(historyProvider.history.single.syncStatus, SyncStatus.synced);
    expect(historyProvider.unsyncedCount, 0);
    expect(syncProvider.pendingCount, 0);
  });

  test('syncNow contains an onSyncComplete exception', () async {
    final fixture = await _createFixture();
    addTearDown(fixture.database.close);
    final authProvider = _authProvider();
    await authProvider.signIn('doctor@example.test', 'password');
    final callbackCalled = Completer<void>();
    final syncProvider = SyncProvider(
      syncService: fixture.syncService,
      connectivityService: _FakeConnectivityService(),
      authProvider: authProvider,
      getUnsyncedCount: GetUnsyncedCountUseCase(fixture.repository),
      onSyncComplete: () async {
        if (!callbackCalled.isCompleted) callbackCalled.complete();
        throw StateError('history refresh failed');
      },
    );
    addTearDown(authProvider.dispose);
    addTearDown(syncProvider.dispose);

    await callbackCalled.future.timeout(const Duration(seconds: 2));
    await expectLater(syncProvider.syncNow(), completes);
  });

  testWidgets(
    'createAppProviders resolves all providers in declaration order',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final foundProviders = Completer<void>();

      await tester.pumpWidget(
        MultiProvider(
          providers: createAppProviders(
            supabaseClient: null,
            sharedPreferences: preferences,
          ),
          child: Builder(
            builder: (context) {
              context.read<ConnectivityService>();
              context.read<AuthProvider>();
              context.read<DatabaseHelper>();
              context.read<AssessmentLocalDataSource>();
              context.read<AssessmentRemoteDataSource>();
              context.read<AssessmentRepository>();
              context.read<GetAssessmentHistoryUseCase>();
              context.read<GetUnsyncedCountUseCase>();
              context.read<SyncService>();
              context.read<HistoryProvider>();
              context.read<SyncProvider>();
              if (!foundProviders.isCompleted) foundProviders.complete();
              return const SizedBox();
            },
          ),
        ),
      );

      await foundProviders.future;
    },
  );
}

final _patient = PatientAssessment(
  patientId: 'MP-SYNC',
  municipio: 'Valledupar',
  departamento: 'Cesar',
  etnia: 'No Indígena',
  zona: 'Urbana',
  edadMaterna: 24,
  semanasGestacion: 28,
  numeroControles: 3,
  distanciaKm: 18.5,
  tiempoTrasladoHoras: 1.8,
  hemoglobina: 11.2,
  presionSistolica: 120,
  presionDiastolica: 75,
  imc: 25.4,
  antecedentePreeclampsia: false,
  antecedenteDiabetes: false,
  partoInstitucionalPrevio: true,
  afiliacionSgsss: 'Subsidiado',
  fechaEvaluacion: DateTime.utc(2026, 11, 11),
);

const _result = TriageResult(
  riskLevel: RiskLevel.bajo,
  probAlto: 0.1,
  probMedio: 0.2,
  probBajo: 0.7,
  riesgoDesenlaceAdverso: false,
  probDesenlaceAdverso: 0.1,
  clinicalAlerts: [],
  hasImmediateEmergency: false,
);

Future<_Fixture> _createFixture() async {
  final database = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, version) => DatabaseHelper.createV2Schema(db),
    ),
  );
  final local = AssessmentLocalDataSource(
    dbHelper: DatabaseHelper.forDatabase(database),
  );
  final repository = AssessmentRepositoryImpl(localDataSource: local);
  final syncService = SyncService(
    localDataSource: local,
    remoteDataSource: _AcceptingRemoteDataSource(),
    hasInternet: () async => true,
    currentOwnerId: () => 'doctor-1',
    hasSession: () => true,
  );
  return _Fixture(database, repository, syncService);
}

AuthProvider _authProvider() {
  final repository = _FakeAuthRepository();
  return AuthProvider(
    signInUseCase: SignInUseCase(repository),
    signOutUseCase: SignOutUseCase(repository),
    getCurrentProfileUseCase: GetCurrentProfileUseCase(repository),
    repository: repository,
  );
}

class _Fixture {
  final Database database;
  final AssessmentRepositoryImpl repository;
  final SyncService syncService;

  const _Fixture(this.database, this.repository, this.syncService);
}

class _TrackingHistoryProvider extends HistoryProvider {
  int loadCalls = 0;
  final Completer<void> loadCompleted = Completer<void>();

  _TrackingHistoryProvider({
    required super.getAssessmentHistory,
    required super.getUnsyncedCount,
    required super.currentOwnerId,
  });

  @override
  Future<void> loadHistory() async {
    loadCalls++;
    await super.loadHistory();
    if (!loadCompleted.isCompleted) loadCompleted.complete();
  }
}

class _FakeConnectivityService implements ConnectivityService {
  @override
  Connectivity get connectivity => throw UnimplementedError();

  @override
  SupabaseClient? get client => null;

  @override
  Duration get timeout => const Duration(seconds: 3);

  @override
  Stream<bool> get connectionChanges => const Stream.empty();

  @override
  Future<bool> hasInternet() async => true;
}

class _AcceptingRemoteDataSource implements AssessmentRemoteDataSource {
  @override
  Future<void> upsertBatch(List<Map<String, dynamic>> payload) async {}

  @override
  bool isClientFailure(Object error) => false;

  @override
  bool isNetworkFailure(Object error) => false;
}

class _FakeAuthRepository implements AuthRepository {
  static const _profile = UserProfile(
    id: 'doctor-1',
    email: 'doctor@example.test',
    fullName: 'Doctor Test',
    role: UserRole.doctor,
    active: true,
  );

  @override
  Future<UserProfile?> getCurrentProfile() async => null;

  @override
  Stream<UserProfile?> get sessionChanges => const Stream.empty();

  @override
  Future<UserProfile> signIn(String email, String password) async => _profile;

  @override
  Future<void> signOut() async {}
}
