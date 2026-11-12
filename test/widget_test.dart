import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/app/app.dart';
import 'package:rmpzd/core/sync/sync_provider.dart';
import 'package:rmpzd/features/auth/domain/entities/user_profile.dart';
import 'package:rmpzd/features/auth/domain/repositories/auth_repository.dart';
import 'package:rmpzd/features/auth/domain/usecases/get_current_profile_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:rmpzd/features/auth/presentation/providers/auth_provider.dart';
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
    final authRepository = _FakeAuthRepository();
    final authProvider = AuthProvider(
      signInUseCase: SignInUseCase(authRepository),
      signOutUseCase: SignOutUseCase(authRepository),
      getCurrentProfileUseCase: GetCurrentProfileUseCase(authRepository),
      repository: authRepository,
    );
    final providers = [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<SyncProvider>(
        create: (_) => SyncProvider.disabled(),
      ),
      ChangeNotifierProvider(
        create: (_) => TriageProvider(
          evaluateMaternalRisk: EvaluateMaternalRiskUseCase(
            _FakeRiskClassifier(),
          ),
          saveAssessment: SaveAssessmentUseCase(repository),
          currentOwnerId: () => 'test-user',
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => HistoryProvider(
          getAssessmentHistory: GetAssessmentHistoryUseCase(repository),
          getUnsyncedCount: GetUnsyncedCountUseCase(repository),
          currentOwnerId: () => 'test-user',
        ),
      ),
    ];

    await tester.pumpWidget(RmpzdApp(providers: providers));
    await tester.pumpAndSettle();

    expect(find.text('Triage Materno'), findsOneWidget);
    expect(find.text('EVALUAR RIESGO OBSTÉTRICO'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<UserProfile?> getCurrentProfile() async => const UserProfile(
    id: 'test-user',
    email: 'doctor@example.test',
    fullName: 'Doctora de prueba',
    role: UserRole.doctor,
    active: true,
  );

  @override
  Stream<UserProfile?> get sessionChanges => const Stream.empty();

  @override
  Future<UserProfile> signIn(String email, String password) async =>
      (await getCurrentProfile())!;

  @override
  Future<void> signOut() async {}
}

class _FakeRiskClassifier implements RiskClassifier {
  @override
  Future<TriageResult> classify(PatientAssessment patient) {
    throw UnimplementedError('The smoke test does not submit the form.');
  }
}

class _FakeAssessmentRepository implements AssessmentRepository {
  @override
  Future<List<AssessmentRecord>> getHistory({required String ownerId}) async =>
      [];

  @override
  Future<int> getUnsyncedCount({required String ownerId}) async => 0;

  @override
  Future<int> saveAssessment(
    PatientAssessment patient,
    TriageResult result, {
    required String ownerId,
  }) async => 1;
}
