import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/features/patient_portal/domain/entities/patient_record_view.dart';
import 'package:rmpzd/features/patient_portal/domain/usecases/lookup_patient_records_usecase.dart';
import 'package:rmpzd/features/patient_portal/presentation/pages/patient_lookup_page.dart';
import 'package:rmpzd/features/patient_portal/presentation/pages/patient_record_detail_page.dart';
import 'package:rmpzd/features/patient_portal/presentation/providers/patient_portal_provider.dart';

void main() {
  group('PatientRecordView parsing', () {
    test('parses all fields and converts integer numerics to doubles', () {
      final record = PatientRecordView.fromJson(_completeJson());

      expect(record.folio, 'FOLIO-2026-01');
      expect(record.fechaEvaluacion, DateTime.parse('2026-11-16T14:30:00Z'));
      expect(record.nivelRiesgoPredicho, 'Riesgo Moderado');
      expect(record.alertaClinicaInmediata, isTrue);
      expect(record.descripcionAlerta, 'Alerta prioritaria');
      expect(record.municipio, 'Valledupar');
      expect(record.departamento, 'Cesar');
      expect(record.etnia, 'Wayuu');
      expect(record.zona, 'Rural');
      expect(record.edadMaterna, 29);
      expect(record.semanasGestacion, 28);
      expect(record.numeroControles, 4);
      expect(record.distanciaKm, 12.0);
      expect(record.tiempoTrasladoHoras, 1.5);
      expect(record.hemoglobina, 11.2);
      expect(record.presionSistolica, 120.0);
      expect(record.presionDiastolica, 80.0);
      expect(record.imc, 25.4);
      expect(record.antecedentePreeclampsia, isFalse);
      expect(record.antecedenteDiabetes, isTrue);
      expect(record.partoInstitucionalPrevio, isTrue);
      expect(record.afiliacionSgsss, 'Subsidiado');
      expect(record.probabilidadRiesgoAlto, 0.375);
      expect(record.probabilidadDesenlaceAdverso, 0.5);
    });

    test('tolerates null optional values and unexpected value types', () {
      final record = PatientRecordView.fromJson({
        'folio': 24,
        'fecha_evaluacion': 'invalid date',
        'nivel_riesgo_predicho': null,
        'alerta_clinica_inmediata': 'true',
        'descripcion_alerta': null,
        'edad_materna': '29',
        'hemoglobina': null,
        'antecedente_diabetes': null,
      });

      expect(record.folio, '24');
      expect(record.fechaEvaluacion, isNull);
      expect(record.nivelRiesgoPredicho, isNull);
      expect(record.alertaClinicaInmediata, isNull);
      expect(record.descripcionAlerta, isNull);
      expect(record.edadMaterna, isNull);
      expect(record.hemoglobina, isNull);
      expect(record.antecedenteDiabetes, isNull);
      expect(record.municipio, isNull);
      expect(record.probabilidadRiesgoAlto, isNull);
    });
  });

  group('LookupPatientRecordsUseCase and PatientPortalProvider', () {
    final outcomes = <LookupPatientRecordsResult>[
      PatientRecordFound(_record()),
      const PatientRecordsNotFound(),
      const PatientLookupBlocked(),
      const PatientLookupIncomplete(),
      const PatientLookupNoConnection(),
    ];

    for (final outcome in outcomes) {
      test(
        'returns ${outcome.runtimeType} and clear removes its state',
        () async {
          final source = _FakeLookup(outcome);
          final provider = PatientPortalProvider(
            lookupPatientRecords: LookupPatientRecordsUseCase(source),
          );
          addTearDown(provider.dispose);

          await provider.lookup('document-private', 'abcd-2345');

          expect(provider.result, same(outcome));
          expect(source.lastDocument, 'document-private');
          expect(source.lastCode, 'ABCD2345');
          provider.clear();
          expect(provider.result, isNull);
          expect(provider.isLoading, isFalse);
        },
      );
    }

    test('expires the record after three minutes without activity', () {
      fakeAsync((async) {
        final provider = PatientPortalProvider(
          lookupPatientRecords: LookupPatientRecordsUseCase(
            _FakeLookup(PatientRecordFound(_record())),
          ),
        );
        var lookupCompleted = false;
        provider
            .lookup('document-private', 'ABCD2345')
            .then((_) => lookupCompleted = true);
        async.flushMicrotasks();
        expect(lookupCompleted, isTrue);
        expect(provider.result, isA<PatientRecordFound>());

        async.elapse(const Duration(minutes: 2));
        provider.recordActivity();
        async.elapse(const Duration(minutes: 2, seconds: 59));
        expect(provider.result, isA<PatientRecordFound>());
        async.elapse(const Duration(seconds: 1));

        expect(provider.result, isNull);
        expect(provider.inactivityExpired, isTrue);
        expect(provider.consumeInactivityExpiration(), isTrue);
        expect(provider.consumeInactivityExpiration(), isFalse);
        provider.dispose();
      });
    });
  });

  testWidgets('keeps errors in the form and does not render a result inline', (
    tester,
  ) async {
    final source = _FakeLookup(const PatientRecordsNotFound());
    final provider = _portalApp(source);
    await tester.pumpWidget(provider.$1);

    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingrese su número de documento / ID.'), findsOneWidget);
    expect(source.calls, 0);

    await _submitLookup(tester);

    expect(
      find.text(
        'No encontramos un registro con esos datos. Verifique su ID y el '
        'código que le entregó su médico.',
      ),
      findsOneWidget,
    );
    expect(find.byType(PatientRecordDetailPage), findsNothing);
    expect(find.text('Datos de la gestante'), findsNothing);
  });

  testWidgets('uppercases the ID and accepts one optional code hyphen', (
    tester,
  ) async {
    final source = _FakeLookup(const PatientRecordsNotFound());
    await tester.pumpWidget(_portalApp(source).$1);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Número de documento / ID'),
      'cc12345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código de consulta'),
      'abcd-2345',
    );
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();

    expect(source.lastDocument, 'CC12345678');
    expect(source.lastCode, 'ABCD2345');
    expect(find.text('Ingrese el código de 8 caracteres.'), findsNothing);
  });

  testWidgets('opens a responsive detail page with every data section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = _FakeLookup(PatientRecordFound(_record()));
    await tester.pumpWidget(_portalApp(source).$1);
    await _submitLookup(tester);

    expect(find.byType(PatientRecordDetailPage), findsOneWidget);
    for (final section in [
      'Datos de la evaluación',
      'Datos de la gestante',
      'Acceso a servicios',
      'Signos y laboratorio',
      'Antecedentes',
      'Estimación del modelo',
    ]) {
      expect(find.text(section), findsOneWidget);
    }
    for (final value in [
      'FOLIO-2026-01',
      'Valledupar / Cesar',
      'Rural',
      'Subsidiado',
      '29 años',
      'Wayuu',
      '28 semanas',
      '4',
      '25.4 kg/m²',
      '12.0 km',
      '1.5 horas',
      'Sí',
      '120/80 mmHg',
      '11.2 g/dL',
      'No',
      '37.5 %',
      '50.0 %',
      'Es una estimación estadística y no un diagnóstico',
      'Este resultado es una orientación y no reemplaza la valoración de su médico.',
    ]) {
      expect(find.text(value), findsWidgets, reason: 'Missing $value');
    }
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PatientRecordDetailPage), findsNothing);
    expect(find.text('Riesgo Moderado'), findsNothing);
  });

  for (final testCase in <(String, String)>[
    (
      'Bajo Riesgo',
      'Su evaluación no mostró señales de alarma. Continúe sus controles prenatales.',
    ),
    (
      'Riesgo Moderado',
      'Se recomienda una valoración y seguimiento cercano en su centro de salud.',
    ),
    ('Alto Riesgo Obstétrico', 'Acuda lo antes posible a su centro de salud.'),
  ]) {
    testWidgets('shows ${testCase.$1} guidance on the detail page', (
      tester,
    ) async {
      await tester.pumpWidget(
        _portalApp(_FakeLookup(PatientRecordFound(_record(testCase.$1)))).$1,
      );
      await _submitLookup(tester);
      expect(find.text(testCase.$1), findsOneWidget);
      expect(find.text(testCase.$2), findsOneWidget);
      expect(find.text('Alerta prioritaria'), findsOneWidget);
    });
  }

  for (final testCase in <(LookupPatientRecordsResult, String)>[
    (
      PatientLookupBlocked(),
      'Demasiados intentos. Intente de nuevo en 15 minutos.',
    ),
    (
      PatientLookupNoConnection(),
      'Necesita conexión a internet para consultar.',
    ),
  ]) {
    testWidgets('shows the correct message for ${testCase.$1.runtimeType}', (
      tester,
    ) async {
      await tester.pumpWidget(_portalApp(_FakeLookup(testCase.$1)).$1);
      await _submitLookup(tester);
      expect(find.text(testCase.$2), findsOneWidget);
    });
  }
}

PatientRecordView _record([String risk = 'Riesgo Moderado']) =>
    PatientRecordView.fromJson(
      _completeJson()..['nivel_riesgo_predicho'] = risk,
    );

Map<String, dynamic> _completeJson() => {
  'folio': 'FOLIO-2026-01',
  'fecha_evaluacion': '2026-11-16T14:30:00Z',
  'nivel_riesgo_predicho': 'Riesgo Moderado',
  'alerta_clinica_inmediata': true,
  'descripcion_alerta': 'Alerta prioritaria',
  'municipio': 'Valledupar',
  'departamento': 'Cesar',
  'etnia': 'Wayuu',
  'zona': 'Rural',
  'edad_materna': 29,
  'semanas_gestacion': 28,
  'numero_controles': 4,
  'distancia_km': 12,
  'tiempo_traslado_horas': 1.5,
  'hemoglobina': 11.2,
  'presion_sistolica': 120,
  'presion_diastolica': 80,
  'imc': 25.4,
  'antecedente_preeclampsia': false,
  'antecedente_diabetes': true,
  'parto_institucional_previo': true,
  'afiliacion_sgsss': 'Subsidiado',
  'probabilidad_riesgo_alto': 0.375,
  'probabilidad_desenlace_adverso': 0.5,
};

(Widget, PatientPortalProvider) _portalApp(_FakeLookup source) {
  final provider = PatientPortalProvider(
    lookupPatientRecords: LookupPatientRecordsUseCase(source),
  );
  return (
    ChangeNotifierProvider<PatientPortalProvider>.value(
      value: provider,
      child: const MaterialApp(home: PatientLookupPage()),
    ),
    provider,
  );
}

Future<void> _submitLookup(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Número de documento / ID'),
    'ID-12345678',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Código de consulta'),
    'ABCD-2345',
  );
  await tester.tap(find.text('Consultar'));
  await tester.pumpAndSettle();
}

class _FakeLookup implements PatientRecordsLookup {
  final LookupPatientRecordsResult response;
  String? lastDocument;
  String? lastCode;
  int calls = 0;

  _FakeLookup(this.response);

  @override
  Future<LookupPatientRecordsResult> lookup({
    required String document,
    required String code,
  }) async {
    calls++;
    lastDocument = document;
    lastCode = code;
    return response;
  }
}
