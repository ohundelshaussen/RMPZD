import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/features/monitoring/data/datasources/doctor_monitoring_remote_data_source.dart';
import 'package:rmpzd/features/monitoring/domain/entities/doctor_monitoring_case.dart';
import 'package:rmpzd/features/monitoring/domain/usecases/get_doctor_monitoring_cases_usecase.dart';
import 'package:rmpzd/features/monitoring/domain/usecases/refer_assessment_to_monitor_usecase.dart';
import 'package:rmpzd/features/monitoring/presentation/providers/doctor_referral_provider.dart';
import 'package:rmpzd/features/monitoring/presentation/widgets/doctor_referral_panel.dart';
import 'package:rmpzd/features/triage/domain/entities/assessment_record.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';

void main() {
  group('DoctorReferralProvider', () {
    test(
      'submits a referral and maps success, reopen, duplicate, and denial',
      () async {
        final fixture = _createFixture();
        addTearDown(fixture.dispose);
        await fixture.provider.refreshInternetStatus();

        fixture.remote.referralResult = const DoctorReferralResult(ok: true);
        final submitted = await fixture.provider.submitReferral(
          assessmentId: 'assessment-1',
          motive: 'Consulta prioritaria',
        );
        expect(submitted.ok, isTrue);
        expect(
          DoctorReferralProvider.messageFor(submitted),
          'Paciente remitida al monitor',
        );
        expect(fixture.remote.referrals.single, (
          assessmentId: 'assessment-1',
          motive: 'Consulta prioritaria',
        ));

        fixture.remote.referralResult = const DoctorReferralResult(
          ok: true,
          reopened: true,
        );
        final reopened = await fixture.provider.submitReferral(
          assessmentId: 'assessment-2',
          motive: '',
        );
        expect(
          DoctorReferralProvider.messageFor(reopened),
          'El caso estaba cerrado y se reabrió',
        );

        fixture.remote.referralResult = const DoctorReferralResult(
          ok: false,
          motive: 'ya_remitido',
          state: 'en_gestion',
        );
        final alreadyReferred = await fixture.provider.submitReferral(
          assessmentId: 'assessment-3',
          motive: '',
        );
        expect(
          DoctorReferralProvider.messageFor(alreadyReferred),
          'Ya está remitida y en gestión por un monitor',
        );

        fixture.remote.referralResult = const DoctorReferralResult(
          ok: false,
          motive: 'no_autorizado',
        );
        final denied = await fixture.provider.submitReferral(
          assessmentId: 'assessment-4',
          motive: '',
        );
        expect(
          DoctorReferralProvider.messageFor(denied),
          'No tiene permiso para remitir esta evaluación',
        );
      },
    );

    test('loads case status only for supplied assessment UUIDs', () async {
      final fixture = _createFixture();
      addTearDown(fixture.dispose);
      fixture.remote.statuses['assessment-1'] = const DoctorMonitoringCase(
        state: 'nuevo',
      );

      await fixture.provider.loadStatuses(['assessment-1', 'assessment-2']);

      expect(fixture.remote.statusRequests, [
        ['assessment-1', 'assessment-2'],
      ]);
      expect(fixture.provider.caseFor('assessment-1')?.state, 'nuevo');
      expect(fixture.provider.hasCheckedStatus('assessment-2'), isTrue);
    });
  });

  group('DoctorReferralPanel availability', () {
    testWidgets('disables the action without internet', (tester) async {
      final fixture = _createFixture(isOnline: false);
      addTearDown(fixture.dispose);
      await fixture.provider.refreshInternetStatus();

      await tester.pumpWidget(_panelApp(fixture.provider, _record()));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Requiere conexión a internet'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('disables the action until a record is synchronized', (
      tester,
    ) async {
      final fixture = _createFixture();
      addTearDown(fixture.dispose);
      await fixture.provider.refreshInternetStatus();

      await tester.pumpWidget(
        _panelApp(fixture.provider, _record(syncStatus: SyncStatus.pending)),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sincronice primero'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows an open case status instead of a referral button', (
      tester,
    ) async {
      final fixture = _createFixture();
      addTearDown(fixture.dispose);
      await fixture.provider.refreshInternetStatus();
      fixture.remote.statuses['assessment-1'] = const DoctorMonitoringCase(
        state: 'en_gestion',
      );
      await fixture.provider.loadStatuses(['assessment-1']);

      await tester.pumpWidget(_panelApp(fixture.provider, _record()));
      await tester.pumpAndSettle();

      expect(find.text('Remitida · en gestión'), findsOneWidget);
      expect(find.text('Remitir al monitor'), findsNothing);
    });

    testWidgets('shows the closed result and permits a new referral', (
      tester,
    ) async {
      final fixture = _createFixture();
      addTearDown(fixture.dispose);
      await fixture.provider.refreshInternetStatus();
      fixture.remote.statuses['assessment-1'] = const DoctorMonitoringCase(
        state: 'cerrado',
        result: 'atendida',
      );
      await fixture.provider.loadStatuses(['assessment-1']);

      await tester.pumpWidget(_panelApp(fixture.provider, _record()));
      await tester.pumpAndSettle();

      expect(find.text('Cerrada: atendida'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Volver a remitir'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('confirms the optional motive and sends the referral', (
      tester,
    ) async {
      final fixture = _createFixture();
      addTearDown(fixture.dispose);
      await fixture.provider.refreshInternetStatus();

      await tester.pumpWidget(_panelApp(fixture.provider, _record()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remitir al monitor'));
      await tester.pumpAndSettle();

      expect(find.text('Motivo (opcional)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Consulta prioritaria');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(fixture.remote.referrals.single, (
        assessmentId: 'assessment-1',
        motive: 'Consulta prioritaria',
      ));
      expect(find.text('Paciente remitida al monitor'), findsOneWidget);
    });

    testWidgets('automatic high risk alert displays the case state', (
      tester,
    ) async {
      final fixture = _createFixture();
      addTearDown(fixture.dispose);
      await fixture.provider.refreshInternetStatus();
      fixture.remote.statuses['assessment-1'] = const DoctorMonitoringCase(
        state: 'nuevo',
      );
      await fixture.provider.loadStatuses(['assessment-1']);

      await tester.pumpWidget(
        _panelApp(
          fixture.provider,
          _record(riskLevel: RiskLevel.alto),
          automaticAlert: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alerta enviada al monitor'), findsOneWidget);
      expect(find.text('En espera de un monitor'), findsOneWidget);
      expect(find.text('Remitir al monitor'), findsNothing);
    });
  });
}

Widget _panelApp(
  DoctorReferralProvider provider,
  AssessmentRecord record, {
  bool automaticAlert = false,
}) => ChangeNotifierProvider<DoctorReferralProvider>.value(
  value: provider,
  child: MaterialApp(
    home: Scaffold(
      body: DoctorReferralPanel(record: record, automaticAlert: automaticAlert),
    ),
  ),
);

_DoctorReferralFixture _createFixture({bool isOnline = true}) {
  final remote = _FakeDoctorMonitoringRemoteDataSource();
  final connectionChanges = StreamController<bool>.broadcast();
  final provider = DoctorReferralProvider(
    getMonitoringCases: GetDoctorMonitoringCasesUseCase(remote),
    referAssessment: ReferAssessmentToMonitorUseCase(remote),
    checkInternet: () async => isOnline,
    connectionChanges: connectionChanges.stream,
  );
  return _DoctorReferralFixture(remote, connectionChanges, provider);
}

AssessmentRecord _record({
  SyncStatus syncStatus = SyncStatus.synced,
  RiskLevel riskLevel = RiskLevel.medio,
}) => AssessmentRecord(
  patient: PatientAssessment(
    patientId: 'TEST-1',
    municipio: 'Valledupar',
    departamento: 'Cesar',
    etnia: 'No aplica',
    zona: 'Urbana',
    edadMaterna: 25,
    semanasGestacion: 28,
    numeroControles: 4,
    distanciaKm: 5,
    tiempoTrasladoHoras: 1,
    hemoglobina: 12,
    presionSistolica: 110,
    presionDiastolica: 70,
    imc: 24,
    antecedentePreeclampsia: false,
    antecedenteDiabetes: false,
    partoInstitucionalPrevio: true,
    afiliacionSgsss: 'Contributivo',
    fechaEvaluacion: DateTime.utc(2026, 11, 26),
  ),
  result: TriageResult(
    riskLevel: riskLevel,
    probAlto: 0.2,
    probMedio: 0.6,
    probBajo: 0.2,
    riesgoDesenlaceAdverso: false,
    probDesenlaceAdverso: 0.1,
    clinicalAlerts: [],
    hasImmediateEmergency: false,
  ),
  uuid: 'assessment-1',
  ownerId: 'doctor-1',
  syncStatus: syncStatus,
  fechaGuardado: DateTime.utc(2026, 11, 26),
);

class _FakeDoctorMonitoringRemoteDataSource
    implements DoctorMonitoringRemoteDataSource {
  final Map<String, DoctorMonitoringCase> statuses = {};
  final List<List<String>> statusRequests = [];
  final List<({String assessmentId, String motive})> referrals = [];
  DoctorReferralResult referralResult = const DoctorReferralResult(ok: true);

  @override
  Future<Map<String, DoctorMonitoringCase>> fetchCaseStatuses(
    List<String> assessmentIds,
  ) async {
    statusRequests.add(List.of(assessmentIds));
    final result = <String, DoctorMonitoringCase>{};
    for (final id in assessmentIds) {
      final status = statuses[id];
      if (status != null) result[id] = status;
    }
    return result;
  }

  @override
  Future<DoctorReferralResult> referAssessment(
    String assessmentId,
    String motive,
  ) async {
    referrals.add((assessmentId: assessmentId, motive: motive));
    return referralResult;
  }
}

class _DoctorReferralFixture {
  final _FakeDoctorMonitoringRemoteDataSource remote;
  final StreamController<bool> connectionChanges;
  final DoctorReferralProvider provider;

  const _DoctorReferralFixture(
    this.remote,
    this.connectionChanges,
    this.provider,
  );

  Future<void> dispose() async {
    provider.dispose();
    await connectionChanges.close();
  }
}
