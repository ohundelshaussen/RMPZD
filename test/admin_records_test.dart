import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/core/network/connectivity_service.dart';
import 'package:rmpzd/features/admin_records/data/datasources/admin_records_remote_datasource.dart';
import 'package:rmpzd/features/admin_records/data/repositories/admin_records_repository_impl.dart';
import 'package:rmpzd/features/admin_records/domain/entities/remote_assessment.dart';
import 'package:rmpzd/features/admin_records/domain/repositories/admin_records_repository.dart';
import 'package:rmpzd/features/admin_records/domain/usecases/delete_admin_assessment_usecase.dart';
import 'package:rmpzd/features/admin_records/domain/usecases/get_admin_assessments_usecase.dart';
import 'package:rmpzd/features/admin_records/domain/usecases/update_admin_assessment_usecase.dart';
import 'package:rmpzd/features/admin_records/presentation/pages/admin_records_page.dart';
import 'package:rmpzd/features/admin_records/presentation/providers/admin_records_provider.dart';
import 'package:rmpzd/features/triage/data/datasources/assessment_remote_datasource.dart';
import 'package:rmpzd/features/triage/domain/entities/assessment_record.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';
import 'package:rmpzd/features/triage/domain/repositories/assessment_repository.dart';
import 'package:rmpzd/features/triage/domain/usecases/regenerate_consultation_code_usecase.dart';

void main() {
  group('AdminRecordsProvider', () {
    test('paginates by 30 and sends all selected filters including search', () async {
      final source = _FakeDataSource(
        onFetch: (offset, limit, filters) => List.generate(
          offset == 0 ? limit : 1,
          (index) => _assessment(offset + index),
        ),
      );
      final provider = _provider(source);
      final selected = AdminAssessmentFilters(
        doctorId: 'doctor-1',
        riskLevel: 'Alto Riesgo',
        department: 'Cesar',
        fromDate: DateTime(2026, 1, 2),
        toDate: DateTime(2026, 1, 8),
        searchQuery: 'PAC-12',
      );

      await provider.setFilters(selected);
      expect(provider.records, hasLength(30));
      expect(provider.hasMore, isTrue);
      expect(source.calls.single.offset, 0);
      expect(source.calls.single.limit, 30);
      expect(source.calls.single.filters.doctorId, 'doctor-1');
      expect(source.calls.single.filters.riskLevel, 'Alto Riesgo');
      expect(source.calls.single.filters.department, 'Cesar');
      expect(source.calls.single.filters.fromDate, DateTime(2026, 1, 2));
      expect(source.calls.single.filters.toDate, DateTime(2026, 1, 8));
      expect(source.calls.single.filters.searchQuery, 'PAC-12');

      await provider.loadMore();
      expect(provider.records, hasLength(31));
      expect(source.calls.last.offset, 30);
      expect(provider.hasMore, isFalse);
    });

    test('reports offline and supports retry', () async {
      final source = _FakeDataSource();
      final connectivity = _FakeConnectivity(false);
      final provider = _provider(source, connectivity: connectivity);

      await provider.loadInitial();
      expect(provider.isOffline, isTrue);
      expect(provider.errorMessage, contains('Sin conexión'));
      expect(source.calls, isEmpty);

      connectivity.online = true;
      await provider.retry();
      expect(provider.errorMessage, isNull);
      expect(provider.records, hasLength(1));
    });

    test('shows a clear offline message after a network error', () async {
      final source = _FakeDataSource(error: const SocketException('offline'));
      final provider = _provider(source);

      await provider.loadInitial();

      expect(provider.errorMessage, contains('Sin conexión'));
      expect(provider.isOffline, isTrue);
    });

    test('uses the physician email when the name is null', () {
      final assessment = RemoteAssessment.fromJson({
        ..._assessment(1),
        'profiles': {'full_name': null, 'email': 'medico@example.org'},
      });

      expect(assessment.doctorName, 'medico@example.org');
      expect(assessment.doctorEmail, 'medico@example.org');
    });

    test('builds search filter including consultation code without hyphens and handles hash flags', () {
      expect(
        SupabaseAdminRecordsRemoteDataSource.buildSearchOrFilter('PAC-10'),
        'patient_id.ilike.%PAC-10%,nombre_paciente.ilike.%PAC-10%,codigo_consulta.ilike.%PAC10%',
      );
      expect(
        SupabaseAdminRecordsRemoteDataSource.buildSearchOrFilter('ABCD-2345'),
        contains('codigo_consulta.ilike.%ABCD2345%'),
      );
      expect(
        SupabaseAdminRecordsRemoteDataSource.buildSearchOrFilter('---'),
        isNot(contains('codigo_consulta.ilike')),
      );
      expect(
        SupabaseAdminRecordsRemoteDataSource.buildSearchOrFilter(
          '550e8400-e29b-41d4-a716-446655440000',
        ),
        contains('created_by.eq.550e8400-e29b-41d4-a716-446655440000'),
      );
      expect(
        SupabaseAdminRecordsRemoteDataSource.buildSearchOrFilter('   '),
        isNull,
      );

      final withCode = RemoteAssessment.fromJson({
        ..._assessment(1),
        'codigo_consulta': 'ABCD2345',
      });
      expect(withCode.formattedConsultationCode, 'ABCD-2345');
      expect(withCode.hasConsultationCodeHash, isFalse);

      final withHashOnly = RemoteAssessment.fromJson({
        ..._assessment(2),
        'codigo_consulta': null,
        'codigo_consulta_hash': 'sha256_abc',
      });
      expect(withHashOnly.formattedConsultationCode, isNull);
      expect(withHashOnly.hasConsultationCodeHash, isTrue);
    });

    test(
      'preserves base and previously discovered filter catalogs when filtered results are empty',
      () async {
        var returnEmpty = false;
        final source = _FakeDataSource(
          onFetch: (offset, limit, filters) =>
              returnEmpty ? const [] : [_assessment(1)],
        );
        final provider = _provider(source);

        await provider.loadInitial();
        expect(provider.doctors, containsPair('doctor-1', 'Dra. Test'));
        expect(provider.departments, containsAll(['La Guajira', 'Cesar']));
        expect(
          provider.riskLevels,
          containsAll([
            'Bajo Riesgo',
            'Riesgo Moderado',
            'Alto Riesgo Obstétrico',
            'Alto Riesgo',
          ]),
        );

        returnEmpty = true;
        await provider.setFilters(
          const AdminAssessmentFilters(
            doctorId: 'doctor-1',
            department: 'La Guajira',
            riskLevel: 'Bajo Riesgo',
          ),
        );

        expect(provider.records, isEmpty);
        expect(provider.doctors, containsPair('doctor-1', 'Dra. Test'));
        expect(provider.departments, containsAll(['La Guajira', 'Cesar']));
        expect(
          provider.riskLevels,
          containsAll([
            'Bajo Riesgo',
            'Riesgo Moderado',
            'Alto Riesgo Obstétrico',
            'Alto Riesgo',
          ]),
        );
      },
    );

    test('edits and deletes remote assessments and reports RLS rejections', () async {
      final source = _FakeDataSource(
        onFetch: (offset, limit, filters) => [_assessment(1)],
      );
      final provider = _provider(source);
      await provider.loadInitial();

      final editOk = await provider.editAssessment('1', {'municipio': 'Maicao'});
      expect(editOk.success, isTrue);
      expect(provider.records.single.municipality, 'Maicao');

      source.permissionDenied = true;
      final editDenied = await provider.editAssessment('1', {'municipio': 'Uribia'});
      expect(editDenied.success, isFalse);
      expect(editDenied.message, contains('RLS'));

      final deleteDenied = await provider.removeAssessment('1');
      expect(deleteDenied.success, isFalse);
      expect(provider.records, hasLength(1));

      source.permissionDenied = false;
      final deleteOk = await provider.removeAssessment('1');
      expect(deleteOk.success, isTrue);
      expect(provider.records, isEmpty);
    });

    testWidgets(
      'AdminRecordsPage renders search bar, filter pills and omits non-alert noise',
      (tester) async {
        final source = _FakeDataSource(
          onFetch: (offset, limit, filters) => [
            {
              ..._assessment(10),
              'nombre_paciente': 'María Pérez',
              'alerta_clinica_inmediata': false,
            },
          ],
        );
        final provider = _provider(source);

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminRecordsProvider>.value(
            value: provider,
            child: const MaterialApp(home: AdminRecordsPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(TextField),
          findsOneWidget,
        );
        expect(find.text('María Pérez'), findsOneWidget);
        expect(find.text('ID: PAC-10'), findsOneWidget);
        expect(find.text('Sin alerta clínica inmediata'), findsNothing);

        await tester.enterText(find.byType(TextField), 'PAC-10');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        expect(source.calls.last.filters.searchQuery, 'PAC-10');
      },
    );

    testWidgets(
      'AdminRecordsPage displays formatted consultation code on cards and hash notice in detail sheet',
      (tester) async {
        final source = _FakeDataSource(
          onFetch: (offset, limit, filters) => [
            {
              ..._assessment(10),
              'nombre_paciente': 'María Pérez',
              'codigo_consulta': 'ABCD2345',
            },
            {
              ..._assessment(11),
              'nombre_paciente': 'Elena Ruiz',
              'codigo_consulta': null,
              'codigo_consulta_hash': 'hash-xyz',
            },
          ],
        );
        final provider = _provider(source);

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminRecordsProvider>.value(
            value: provider,
            child: const MaterialApp(home: AdminRecordsPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cód. ABCD-2345'), findsOneWidget);

        await tester.tap(find.text('Elena Ruiz'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Protegido en servidor (solo hash)'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Protegido en servidor (solo hash)'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminRecordsPage renders regenerate consultation code action in detail sheet',
      (tester) async {
        final source = _FakeDataSource(
          onFetch: (offset, limit, filters) => [
            {
              ..._assessment(12),
              'nombre_paciente': 'Camila Soto',
              'codigo_consulta': null,
              'codigo_consulta_hash': 'hash-123',
            },
          ],
        );
        final provider = _provider(source);
        final regenerateUseCase = RegenerateConsultationCodeUseCase(
          repository: _DummyAssessmentRepository(),
          remoteDataSource: _DummyAssessmentRemoteDataSource(),
          hasInternet: () async => true,
          hasSession: () => true,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AdminRecordsProvider>.value(value: provider),
              Provider<RegenerateConsultationCodeUseCase>.value(
                value: regenerateUseCase,
              ),
              Provider<ConnectivityService>.value(value: _FakeConnectivity(true)),
            ],
            child: const MaterialApp(home: AdminRecordsPage()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Camila Soto'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Generar nuevo código'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Generar nuevo código'), findsOneWidget);
      },
    );
  });
}

AdminRecordsProvider _provider(
  _FakeDataSource source, {
  _FakeConnectivity? connectivity,
}) {
  final repository = AdminRecordsRepositoryImpl(source);
  return AdminRecordsProvider(
    getAssessments: GetAdminAssessmentsUseCase(repository),
    updateAssessment: UpdateAdminAssessmentUseCase(repository),
    deleteAssessment: DeleteAdminAssessmentUseCase(repository),
    connectivityService: connectivity ?? _FakeConnectivity(true),
  );
}

Map<String, dynamic> _assessment(int id) => {
  'id': '$id',
  'created_by': 'doctor-1',
  'patient_id': 'PAC-$id',
  'municipio': 'Valledupar',
  'departamento': 'Cesar',
  'nivel_riesgo_predicho': 'Alto Riesgo',
  'alerta_clinica_inmediata': false,
  'fecha_evaluacion': '2026-01-03T10:00:00Z',
  'probabilidad_riesgo_alto': 0.75,
  'probabilidad_desenlace_adverso': 0.2,
  'profiles': {'full_name': 'Dra. Test', 'email': 'medico@example.org'},
};

class _FakeDataSource implements AdminRecordsRemoteDataSource {
  final List<_FetchCall> calls = [];
  final List<Map<String, dynamic>> Function(
    int offset,
    int limit,
    AdminAssessmentFilters filters,
  )?
  onFetch;
  final Object? error;
  bool permissionDenied = false;

  _FakeDataSource({this.onFetch, this.error});

  @override
  Future<List<Map<String, dynamic>>> fetchAssessments({
    required int offset,
    required int limit,
    required AdminAssessmentFilters filters,
  }) async {
    calls.add(_FetchCall(offset, limit, filters));
    if (error != null) throw error!;
    return onFetch?.call(offset, limit, filters) ?? [_assessment(1)];
  }

  @override
  Future<Map<String, dynamic>> updateAssessment({
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    if (permissionDenied) {
      throw const AdminPermissionException('Bloqueado por RLS.');
    }
    return {..._assessment(int.tryParse(id) ?? 1), ...updates};
  }

  @override
  Future<void> deleteAssessment({required String id}) async {
    if (permissionDenied) {
      throw const AdminPermissionException('Bloqueado por RLS.');
    }
  }
}

class _FetchCall {
  final int offset;
  final int limit;
  final AdminAssessmentFilters filters;

  const _FetchCall(this.offset, this.limit, this.filters);
}

class _FakeConnectivity extends ConnectivityService {
  bool online;

  _FakeConnectivity(this.online)
    : super(connectivity: Connectivity(), client: null);

  @override
  Future<bool> hasInternet() async => online;
}

class _DummyAssessmentRepository implements AssessmentRepository {
  @override
  Future<void> deleteAssessment({required String uuid}) async {}

  @override
  Future<List<AssessmentRecord>> getHistory({required String ownerId}) async =>
      const [];

  @override
  Future<int> getUnsyncedCount({required String ownerId}) async => 0;

  @override
  Future<int> pullOwnAssessments({required String ownerId}) async => 0;

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

  @override
  Future<void> updateConsultationCode({
    required String uuid,
    required String code,
  }) async {}
}

class _DummyAssessmentRemoteDataSource implements AssessmentRemoteDataSource {
  @override
  Future<bool> deleteAssessment(String uuid) async => true;

  @override
  Future<List<Map<String, dynamic>>> fetchOwnAssessments(
    String ownerId, {
    String? updatedAfter,
    int offset = 0,
    int limit = 200,
  }) async => const [];

  @override
  bool isClientFailure(Object error) => false;

  @override
  bool isNetworkFailure(Object error) => false;

  @override
  Future<Map<String, dynamic>> regenerateConsultationCode(String uuid) async =>
      {'ok': true, 'codigo': 'ZXCV5678'};

  @override
  Future<bool> updateAssessment(
    String uuid,
    Map<String, dynamic> payload,
  ) async => true;

  @override
  Future<void> upsertBatch(List<Map<String, dynamic>> payload) async {}
}
