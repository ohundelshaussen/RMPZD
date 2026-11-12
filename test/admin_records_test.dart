import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/core/network/connectivity_service.dart';
import 'package:rmpzd/features/admin_records/data/datasources/admin_records_remote_datasource.dart';
import 'package:rmpzd/features/admin_records/data/repositories/admin_records_repository_impl.dart';
import 'package:rmpzd/features/admin_records/domain/entities/remote_assessment.dart';
import 'package:rmpzd/features/admin_records/domain/repositories/admin_records_repository.dart';
import 'package:rmpzd/features/admin_records/domain/usecases/get_admin_assessments_usecase.dart';
import 'package:rmpzd/features/admin_records/presentation/providers/admin_records_provider.dart';

void main() {
  group('AdminRecordsProvider', () {
    test('paginates by 30 and sends all selected filters', () async {
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
  });
}

AdminRecordsProvider _provider(
  _FakeDataSource source, {
  _FakeConnectivity? connectivity,
}) {
  return AdminRecordsProvider(
    getAssessments: GetAdminAssessmentsUseCase(
      AdminRecordsRepositoryImpl(source),
    ),
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
