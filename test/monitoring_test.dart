import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/features/auth/domain/entities/user_profile.dart';
import 'package:rmpzd/features/auth/domain/repositories/auth_repository.dart';
import 'package:rmpzd/features/auth/domain/usecases/get_current_profile_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:rmpzd/features/auth/presentation/providers/auth_provider.dart';
import 'package:rmpzd/features/monitoring/data/datasources/case_remote_data_source.dart';
import 'package:rmpzd/features/monitoring/data/services/monitoring_notification_service.dart';
import 'package:rmpzd/features/monitoring/domain/entities/monitoring_case.dart';
import 'package:rmpzd/features/monitoring/presentation/pages/monitor_home_page.dart';
import 'package:rmpzd/features/monitoring/presentation/providers/monitoring_provider.dart';

void main() {
  group('MonitoringCase', () {
    test('parses case fields and an embedded assessment tolerantly', () {
      final item = MonitoringCase.fromJson({
        'id': 'case-1',
        'assessment_id': 'assessment-1',
        'estado': 'en_gestion',
        'prioridad': 'critica',
        'asignado_a': 'monitor-1',
        'creado_en': '2026-11-25T10:00:00Z',
        'municipio': 'Valledupar',
        'departamento': 'Cesar',
        'nivel_riesgo': 'alto',
        'descripcion_alerta': 'Alerta clínica inmediata',
        'assessments': [
          {
            'patient_id': 'PAT-1',
            'nombre_paciente': 'Paciente Ejemplo',
            'semanas_gestacion': 28.8,
            'edad_materna': '24',
          },
        ],
        'cerrado_en': 'invalid date',
      });

      expect(item.id, 'case-1');
      expect(item.status, MonitoringCaseStatus.enGestion);
      expect(item.priority, MonitoringPriority.critica);
      expect(item.patientId, 'PAT-1');
      expect(item.patientName, 'Paciente Ejemplo');
      expect(item.gestationWeeks, 28);
      expect(item.maternalAge, 24);
      expect(item.closedAt, isNull);
    });

    test('uses safe defaults for missing or unknown optional values', () {
      final item = MonitoringCase.fromJson({
        'id': 'case-2',
        'assessments': null,
        'estado': 'unexpected',
        'prioridad': null,
      });

      expect(item.status, MonitoringCaseStatus.nuevo);
      expect(item.priority, MonitoringPriority.alta);
      expect(item.patientName, isNull);
      expect(item.gestationWeeks, isNull);
      expect(item.createdAt.millisecondsSinceEpoch, 0);
    });
  });

  group('MonitoringProvider', () {
    test('orders critical first, then oldest, with deduplicated ids', () async {
      final fixture = await _startMonitoring([
        _case('high-old', priority: MonitoringPriority.alta),
        _case(
          'critical-new',
          priority: MonitoringPriority.critica,
          createdAt: DateTime.utc(2026, 11, 25, 12),
        ),
        _case(
          'critical-old',
          priority: MonitoringPriority.critica,
          createdAt: DateTime.utc(2026, 11, 25, 9),
        ),
        _case('high-old'),
      ]);
      addTearDown(fixture.dispose);

      expect(fixture.provider.newCases.map((item) => item.id), [
        'critical-old',
        'critical-new',
        'high-old',
      ]);
    });

    test('INSERT updates the list and notifies once per case', () async {
      final fixture = await _startMonitoring([_case('existing')]);
      addTearDown(fixture.dispose);
      final alerts = <MonitoringAlert>[];
      final subscription = fixture.provider.alerts.listen(alerts.add);
      addTearDown(subscription.cancel);
      final addedCase = _case(
        'new-alert',
        priority: MonitoringPriority.critica,
        patientName: 'No debe notificarse este nombre',
        patientId: 'NO-DEBE-NOTIFICARSE',
      );

      fixture.source.upsert(addedCase);
      final change = MonitoringCaseChange(
        type: MonitoringChangeType.insert,
        caseId: addedCase.id,
        current: addedCase,
      );
      fixture.source.emit(change);
      fixture.source.emit(change);
      await _waitUntil(
        () =>
            fixture.provider.newCasesCount == 2 &&
            fixture.notifications.shown.length == 1 &&
            alerts.length == 1,
      );

      expect(
        fixture.provider.newCases.map((item) => item.id),
        contains('new-alert'),
      );
      expect(
        alerts.single.notificationText,
        'Alerta crítica · Valledupar, Cesar',
      );
      expect(alerts.single.notificationText, isNot(contains('NO-DEBE')));
      expect(fixture.notifications.shown, hasLength(1));
    });

    test(
      'UPDATE moves a case away from New when another monitor takes it',
      () async {
        final fixture = await _startMonitoring([_case('case-1')]);
        addTearDown(fixture.dispose);
        final updated = _case(
          'case-1',
          status: MonitoringCaseStatus.enGestion,
          assignedTo: 'monitor-other',
        );

        fixture.source.upsert(updated);
        fixture.source.emit(
          MonitoringCaseChange(
            type: MonitoringChangeType.update,
            caseId: updated.id,
            current: updated,
          ),
        );
        await _waitUntil(
          () =>
              fixture.source.countRequests >= 2 && !fixture.provider.isLoading,
        );

        expect(fixture.provider.newCases, isEmpty);
        expect(fixture.provider.newCasesCount, 0);
        expect(fixture.provider.myCases, isEmpty);
      },
    );

    testWidgets('reconnect and app resume refresh lists; logout unsubscribes', (
      tester,
    ) async {
      final fixture = await _startMonitoring([_case('case-1')]);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final initialRequests = fixture.source.countRequests;

      fixture.source.emitConnection(false);
      fixture.source.emitConnection(true);
      await _waitUntil(
        () =>
            fixture.source.countRequests > initialRequests &&
            !fixture.provider.isLoading,
      );
      final afterReconnect = fixture.source.countRequests;

      fixture.provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(fixture.source.countRequests, greaterThan(afterReconnect));

      await fixture.authProvider.signOut();
      await tester.pump();
      expect(fixture.authProvider.profile, isNull);
      expect(fixture.provider.newCases, isEmpty);
      expect(fixture.source.stopCalls, greaterThanOrEqualTo(1));
      expect(fixture.provider.newCases, isEmpty);
      expect(fixture.notifications.permissionRequests, 1);
      expect(fixture.facilitySyncCalls, 1);
    });

    testWidgets('shows an animated alert banner and opens its case id', (
      tester,
    ) async {
      final fixture = await _startMonitoring([]);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(_providerApp(fixture, const MonitorHomePage()));
      final alert = _case('banner-case', priority: MonitoringPriority.critica);
      fixture.source.upsert(alert);
      fixture.source.emit(
        MonitoringCaseChange(
          type: MonitoringChangeType.insert,
          caseId: alert.id,
          current: alert,
        ),
      );
      await tester.pump();

      expect(find.text('Nueva alerta crítica · Ver caso'), findsOneWidget);
      await tester.tap(find.text('Nueva alerta crítica · Ver caso'));
      await tester.pumpAndSettle();
      expect(find.text('Caso: banner-case'), findsOneWidget);
    });
  });

  testWidgets('case card refreshes elapsed time and marks overdue new cases', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 25, 10);
    final item = _case(
      'old-case',
      priority: MonitoringPriority.critica,
      createdAt: now.subtract(const Duration(minutes: 9, seconds: 45)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonitoringCaseCard(
            item: item,
            isNewCase: true,
            currentTime: () => now,
          ),
        ),
      ),
    );
    expect(find.text('Hace 9 min'), findsOneWidget);
    expect(find.text('Sin atender'), findsNothing);

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('Hace 10 min'), findsOneWidget);
    expect(find.text('Sin atender'), findsOneWidget);
    expect(find.text('Prioridad crítica'), findsOneWidget);
  });
}

Widget _providerApp(_Fixture fixture, Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: fixture.authProvider),
    ChangeNotifierProvider<MonitoringProvider>.value(value: fixture.provider),
  ],
  child: MaterialApp(home: child),
);

Future<_Fixture> _startMonitoring(List<MonitoringCase> cases) async {
  final authRepository = _FakeAuthRepository(_monitor);
  final authProvider = AuthProvider(
    signInUseCase: SignInUseCase(authRepository),
    signOutUseCase: SignOutUseCase(authRepository),
    getCurrentProfileUseCase: GetCurrentProfileUseCase(authRepository),
    repository: authRepository,
  );
  await authProvider.signIn(_monitor.email, 'password');
  final source = _FakeCaseRemoteDataSource(cases);
  final notifications = _FakeMonitoringNotificationService();
  var facilitySyncCalls = 0;
  final provider = MonitoringProvider(
    caseRemoteDataSource: source,
    notificationService: notifications,
    authProvider: authProvider,
    syncFacilityCatalog: () async {
      facilitySyncCalls++;
    },
  );
  final fixture = _Fixture(
    authProvider,
    source,
    notifications,
    provider,
    () => facilitySyncCalls,
  );
  await source.started.future.timeout(const Duration(seconds: 2));
  await _waitUntil(() => source.countRequests > 0 && !provider.isLoading);
  return fixture;
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 1000; attempt++) {
    if (predicate()) return;
    await Future<void>.value();
  }
  throw TimeoutException('Condition was not reached.');
}

const _monitor = UserProfile(
  id: 'monitor-1',
  email: 'monitor@example.test',
  fullName: 'Monitor de prueba',
  role: UserRole.monitor,
  active: true,
);

MonitoringCase _case(
  String id, {
  MonitoringCaseStatus status = MonitoringCaseStatus.nuevo,
  MonitoringPriority priority = MonitoringPriority.alta,
  String? assignedTo,
  String? patientName = 'Paciente Ejemplo',
  String? patientId = 'PAT-123',
  DateTime? createdAt,
}) => MonitoringCase(
  id: id,
  assessmentId: 'assessment-$id',
  status: status,
  priority: priority,
  assignedTo: assignedTo,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 25, 10),
  municipality: 'Valledupar',
  department: 'Cesar',
  riskLevel: 'alto',
  alertDescription: 'Alerta de prueba',
  patientId: patientId,
  patientName: patientName,
  gestationWeeks: 28,
  maternalAge: 24,
);

class _Fixture {
  final AuthProvider authProvider;
  final _FakeCaseRemoteDataSource source;
  final _FakeMonitoringNotificationService notifications;
  final MonitoringProvider provider;
  final int Function() _facilitySyncCalls;

  int get facilitySyncCalls => _facilitySyncCalls();

  const _Fixture(
    this.authProvider,
    this.source,
    this.notifications,
    this.provider,
    this._facilitySyncCalls,
  );

  Future<void> dispose() async {
    provider.dispose();
    authProvider.dispose();
    await source.dispose();
    await notifications.dispose();
  }
}

class _FakeCaseRemoteDataSource implements CaseRemoteDataSource {
  final List<MonitoringCase> _cases;
  final StreamController<MonitoringCaseChange> _changes =
      StreamController<MonitoringCaseChange>.broadcast();
  final Completer<void> started = Completer<void>();
  int countRequests = 0;
  int stopCalls = 0;
  void Function(bool)? _connectionListener;

  _FakeCaseRemoteDataSource(List<MonitoringCase> cases) : _cases = [...cases];

  @override
  Stream<MonitoringCaseChange> get changes => _changes.stream;

  @override
  Future<List<MonitoringCase>> fetchCases({
    required MonitoringCaseStatus status,
    String? assignedTo,
    String? closedBy,
    required int offset,
    int limit = 50,
  }) async {
    final filtered = _cases.where((item) {
      if (item.status != status) return false;
      if (assignedTo != null && item.assignedTo != assignedTo) return false;
      if (closedBy != null && item.closedBy != closedBy) return false;
      return true;
    }).toList();
    return filtered.skip(offset).take(limit).toList();
  }

  @override
  Future<int> fetchNewCasesCount() async {
    countRequests++;
    return _cases
        .where((item) => item.status == MonitoringCaseStatus.nuevo)
        .length;
  }

  @override
  Future<void> startRealtime({
    required void Function(bool connected) onConnectionChanged,
  }) async {
    _connectionListener = onConnectionChanged;
    onConnectionChanged(true);
    if (!started.isCompleted) started.complete();
  }

  @override
  Future<void> stopRealtime() async {
    stopCalls++;
    _connectionListener = null;
  }

  void emit(MonitoringCaseChange change) => _changes.add(change);

  void emitConnection(bool connected) => _connectionListener?.call(connected);

  void upsert(MonitoringCase item) {
    final index = _cases.indexWhere((candidate) => candidate.id == item.id);
    if (index == -1) {
      _cases.add(item);
    } else {
      _cases[index] = item;
    }
  }

  Future<void> dispose() => _changes.close();
}

class _FakeMonitoringNotificationService
    implements MonitoringNotificationService {
  final StreamController<String> _openedCases =
      StreamController<String>.broadcast();
  final List<MonitoringAlert> shown = [];
  int permissionRequests = 0;

  @override
  Stream<String> get openedCaseIds => _openedCases.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }

  @override
  Future<void> show(MonitoringAlert alert) async {
    shown.add(alert);
  }

  @override
  String? takeInitialCaseId() => null;

  Future<void> dispose() => _openedCases.close();
}

class _FakeAuthRepository implements AuthRepository {
  final UserProfile profile;

  _FakeAuthRepository(this.profile);

  @override
  Future<UserProfile?> getCurrentProfile() async => null;

  @override
  Stream<UserProfile?> get sessionChanges => const Stream.empty();

  @override
  Future<UserProfile> signIn(String email, String password) async => profile;

  @override
  Future<void> signOut() async {}
}
