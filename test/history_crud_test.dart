import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/core/database/database_helper.dart';
import 'package:rmpzd/core/sync/sync_provider.dart';
import 'package:rmpzd/core/utils/consultation_code_generator.dart';
import 'package:rmpzd/features/history/presentation/pages/history_page.dart';
import 'package:rmpzd/features/history/presentation/providers/history_provider.dart';
import 'package:rmpzd/features/triage/data/datasources/assessment_local_datasource.dart';
import 'package:rmpzd/features/triage/data/datasources/assessment_remote_datasource.dart';
import 'package:rmpzd/features/triage/data/repositories/assessment_repository_impl.dart';
import 'package:rmpzd/features/triage/domain/entities/assessment_record.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';
import 'package:rmpzd/features/triage/domain/repositories/assessment_repository.dart';
import 'package:rmpzd/features/triage/domain/services/risk_classifier.dart';
import 'package:rmpzd/features/triage/domain/usecases/delete_assessment_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/evaluate_maternal_risk_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/get_assessment_history_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/get_unsynced_count_usecase.dart';
import 'package:rmpzd/features/triage/domain/usecases/update_assessment_usecase.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('HistoryProvider filters by query, risk level and pending status', () async {
    final (db, local, repo, provider, remote) = await _createFixture();
    addTearDown(db.close);
    addTearDown(provider.dispose);

    await repo.saveAssessment(
      _patient('PAC-ALTO', nombrePaciente: 'Ana Gómez', municipio: 'Maicao'),
      const TriageResult(
        riskLevel: RiskLevel.alto,
        probAlto: 0.85,
        probMedio: 0.10,
        probBajo: 0.05,
        riesgoDesenlaceAdverso: true,
        probDesenlaceAdverso: 0.6,
        clinicalAlerts: [],
        hasImmediateEmergency: false,
      ),
      ownerId: 'doc-1',
    );
    final lowSaved = await repo.saveAssessment(
      _patient('PAC-BAJO', nombrePaciente: 'Luz Díaz', municipio: 'Riohacha'),
      const TriageResult(
        riskLevel: RiskLevel.bajo,
        probAlto: 0.1,
        probMedio: 0.2,
        probBajo: 0.7,
        riesgoDesenlaceAdverso: false,
        probDesenlaceAdverso: 0.1,
        clinicalAlerts: [],
        hasImmediateEmergency: false,
      ),
      ownerId: 'doc-1',
    );
    await local.markSynced([lowSaved.uuid]);
    await provider.loadHistory();

    expect(provider.filteredHistory, hasLength(2));

    provider.setSearchQuery('Ana');
    expect(provider.filteredHistory.single.patient.patientId, 'PAC-ALTO');

    provider.setSearchQuery('PAC-BAJO');
    expect(provider.filteredHistory.single.patient.patientId, 'PAC-BAJO');

    provider.clearFilters();
    provider.setRiskFilter('Alto');
    expect(provider.filteredHistory.single.patient.patientId, 'PAC-ALTO');

    provider.setRiskFilter(null);
    provider.setOnlyPending(true);
    expect(provider.filteredHistory.single.patient.patientId, 'PAC-ALTO');

    provider.clearFilters();
    final altoCode = provider.history
        .singleWhere((record) => record.patient.patientId == 'PAC-ALTO')
        .consultationCode!;
    final formattedAltoCode = ConsultationCodeGenerator.format(altoCode);

    provider.setSearchQuery(altoCode);
    expect(provider.filteredHistory.single.patient.patientId, 'PAC-ALTO');

    provider.setSearchQuery(formattedAltoCode);
    expect(provider.filteredHistory.single.patient.patientId, 'PAC-ALTO');

    provider.setSearchQuery(formattedAltoCode.substring(2).toLowerCase());
    expect(provider.filteredHistory.single.patient.patientId, 'PAC-ALTO');

    provider.setSearchQuery('---');
    expect(provider.filteredHistory, isEmpty);

    expect(remote.updateCalls, 0);
  });

  testWidgets('HistoryPage renders consultation code badge on saved card', (
    tester,
  ) async {
    const code = 'WXYZ5678';
    final repo = _InMemoryHistoryRepository([
      AssessmentRecord(
        patient: _patient('PAC-BADGE', nombrePaciente: 'Rosa Mejía'),
        result: const TriageResult(
          riskLevel: RiskLevel.bajo,
          probAlto: 0.1,
          probMedio: 0.2,
          probBajo: 0.7,
          riesgoDesenlaceAdverso: false,
          probDesenlaceAdverso: 0.1,
          clinicalAlerts: [],
          hasImmediateEmergency: false,
        ),
        uuid: 'uuid-badge-1',
        ownerId: 'doc-1',
        consultationCode: code,
        fechaGuardado: DateTime.utc(2026, 11, 20),
      ),
    ]);
    final historyProvider = HistoryProvider(
      getAssessmentHistory: GetAssessmentHistoryUseCase(repo),
      getUnsyncedCount: GetUnsyncedCountUseCase(repo),
      currentOwnerId: () => 'doc-1',
    );
    final syncProvider = SyncProvider.disabled();
    addTearDown(historyProvider.dispose);
    addTearDown(syncProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HistoryProvider>.value(value: historyProvider),
          ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
        ],
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Cód. ${ConsultationCodeGenerator.format(code)}'),
      findsOneWidget,
    );
  });

  test(
    'HistoryProvider edits pending record and enforces remote guard on synced delete/edit',
    () async {
      final (db, local, repo, provider, remote) = await _createFixture();
      addTearDown(db.close);
      addTearDown(provider.dispose);

      final saved = await repo.saveAssessment(
        _patient('PAC-1'),
        const TriageResult(
          riskLevel: RiskLevel.bajo,
          probAlto: 0.1,
          probMedio: 0.2,
          probBajo: 0.7,
          riesgoDesenlaceAdverso: false,
          probDesenlaceAdverso: 0.1,
          clinicalAlerts: [],
          hasImmediateEmergency: false,
        ),
        ownerId: 'doc-1',
      );
      await provider.loadHistory();

      final editPending = await provider.editRecord(
        provider.history.single,
        _patient('PAC-1-EDIT', hemoglobin: 6.5),
      );
      expect(editPending.success, isTrue);
      expect(provider.history.single.patient.patientId, 'PAC-1-EDIT');
      expect(provider.history.single.result.riskLevel, RiskLevel.alto);

      await local.markSynced([saved.uuid]);
      await provider.loadHistory();

      remote.allowMutations = false;
      final blockedSyncEdit = await provider.editRecord(
        provider.history.single,
        _patient('PAC-BLOCKED'),
      );
      expect(blockedSyncEdit.success, isFalse);
      expect(provider.history.single.patient.patientId, 'PAC-1-EDIT');

      final blockedSyncDelete = await provider.removeRecord(
        provider.history.single,
        deleteFromCloud: true,
      );
      expect(blockedSyncDelete.success, isFalse);
      expect(provider.history, hasLength(1));

      remote.allowMutations = true;
      final localOnlyDelete = await provider.removeRecord(
        provider.history.single,
        deleteFromCloud: false,
      );
      expect(localOnlyDelete.success, isTrue);
      expect(remote.deleteCalls, 1);
      expect(provider.history, isEmpty);
    },
  );
}

PatientAssessment _patient(
  String patientId, {
  String? nombrePaciente,
  String municipio = 'Valledupar',
  double hemoglobin = 11.5,
}) => PatientAssessment(
  patientId: patientId,
  municipio: municipio,
  departamento: 'Cesar',
  etnia: 'Wayuu',
  zona: 'Urbana',
  edadMaterna: 25,
  semanasGestacion: 28,
  numeroControles: 4,
  distanciaKm: 10,
  tiempoTrasladoHoras: 1,
  hemoglobina: hemoglobin,
  presionSistolica: 115,
  presionDiastolica: 75,
  imc: 24,
  antecedentePreeclampsia: false,
  antecedenteDiabetes: false,
  partoInstitucionalPrevio: true,
  afiliacionSgsss: 'Subsidiado',
  fechaEvaluacion: DateTime.utc(2026, 11, 20),
  consentimientoDatos: nombrePaciente != null,
  nombrePaciente: nombrePaciente,
  direccionPaciente: nombrePaciente != null ? 'Centro' : null,
);

Future<
  (
    Database,
    AssessmentLocalDataSource,
    AssessmentRepositoryImpl,
    HistoryProvider,
    _FakeRemoteDataSource,
  )
>
_createFixture() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 6,
      onCreate: (db, version) => DatabaseHelper.createV6Schema(db),
    ),
  );
  final local = AssessmentLocalDataSource(
    dbHelper: DatabaseHelper.forDatabase(db),
  );
  final repo = AssessmentRepositoryImpl(localDataSource: local);
  final remote = _FakeRemoteDataSource();
  final provider = HistoryProvider(
    getAssessmentHistory: GetAssessmentHistoryUseCase(repo),
    getUnsyncedCount: GetUnsyncedCountUseCase(repo),
    currentOwnerId: () => 'doc-1',
    evaluateMaternalRisk: EvaluateMaternalRiskUseCase(_FakeRiskClassifier()),
    updateAssessment: UpdateAssessmentUseCase(repo),
    deleteAssessment: DeleteAssessmentUseCase(repo),
    remoteDataSource: remote,
  );
  return (db, local, repo, provider, remote);
}

class _FakeRiskClassifier implements RiskClassifier {
  @override
  Future<TriageResult> classify(PatientAssessment patient) async {
    final isSevere = patient.hemoglobina < 7.0;
    return TriageResult(
      riskLevel: isSevere ? RiskLevel.alto : RiskLevel.bajo,
      probAlto: isSevere ? 0.9 : 0.1,
      probMedio: 0.2,
      probBajo: isSevere ? 0.05 : 0.7,
      riesgoDesenlaceAdverso: isSevere,
      probDesenlaceAdverso: isSevere ? 0.8 : 0.1,
      clinicalAlerts: const [],
      hasImmediateEmergency: isSevere,
    );
  }
}

class _FakeRemoteDataSource implements AssessmentRemoteDataSource {
  bool allowMutations = true;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<bool> updateAssessment(
    String uuid,
    Map<String, dynamic> payload,
  ) async {
    updateCalls++;
    return allowMutations;
  }

  @override
  Future<bool> deleteAssessment(String uuid) async {
    deleteCalls++;
    return allowMutations;
  }

  @override
  Future<void> upsertBatch(List<Map<String, dynamic>> payload) async {}

  @override
  bool isClientFailure(Object error) => false;

  @override
  bool isNetworkFailure(Object error) => false;
}

class _InMemoryHistoryRepository implements AssessmentRepository {
  final List<AssessmentRecord> _records;

  _InMemoryHistoryRepository(this._records);

  @override
  Future<void> deleteAssessment({required String uuid}) async {}

  @override
  Future<List<AssessmentRecord>> getHistory({required String ownerId}) async =>
      _records;

  @override
  Future<int> getUnsyncedCount({required String ownerId}) async =>
      _records.where((record) => !record.isSynced).length;

  @override
  Future<AssessmentRecord> saveAssessment(
    PatientAssessment patient,
    TriageResult result, {
    required String ownerId,
  }) => throw UnimplementedError();

  @override
  Future<AssessmentRecord> updateAssessment(
    AssessmentRecord existingRecord,
    PatientAssessment updatedPatient,
    TriageResult updatedResult,
  ) => throw UnimplementedError();
}
