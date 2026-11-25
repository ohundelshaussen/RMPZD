import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/features/triage/presentation/widgets/patient_identity_section.dart';

void main() {
  testWidgets('validates identity fields only when consent is enabled', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(_sectionApp(formKey: formKey));

    expect(formKey.currentState!.validate(), isTrue);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Ingrese al menos 2 caracteres.'), findsOneWidget);
    expect(find.text('La dirección es obligatoria.'), findsOneWidget);

    final nameField = find.widgetWithText(
      TextFormField,
      'Nombre completo de la paciente',
    );
    final addressField = find.widgetWithText(
      TextFormField,
      'Dirección o descripción de la vivienda (vereda, corregimiento, barrio, referencias)',
    );
    await tester.enterText(nameField, 'A');
    await tester.enterText(addressField, 'Vereda Central');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Teléfono de contacto de la paciente'),
      '3001234567',
    );
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Ingrese al menos 2 caracteres.'), findsOneWidget);

    await tester.enterText(nameField, '12');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      find.text('Ingrese un nombre válido, no solo números.'),
      findsOneWidget,
    );

    await tester.enterText(nameField, 'A' * 201);
    await tester.enterText(addressField, 'V' * 301);
    expect(
      tester.widget<TextFormField>(nameField).controller!.text,
      hasLength(200),
    );
    expect(
      tester.widget<TextFormField>(addressField).controller!.text,
      hasLength(300),
    );
    await tester.enterText(nameField, 'Ana María');
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('captures current location and warns when accuracy is low', (
    tester,
  ) async {
    final service = _FakeLocationService(
      onCapture: () async => const CapturedLocation(
        latitude: 10.4631,
        longitude: -73.2532,
        accuracyMeters: 125,
      ),
    );
    PatientIdentityData? latest;
    await tester.pumpWidget(
      _sectionApp(locationService: service, onChanged: (data) => latest = data),
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capturar ubicación actual'));
    await tester.pumpAndSettle();

    expect(
      find.text('Latitud: 10.46310 · Longitud: -73.25320'),
      findsOneWidget,
    );
    expect(find.text('Precisión: 125.0 m'), findsOneWidget);
    expect(find.text('Precisión baja, intente al aire libre'), findsOneWidget);
    expect(latest?.latitud, 10.4631);
    expect(latest?.longitud, -73.2532);
    expect(latest?.ubicacionCapturadaAt?.isUtc, isTrue);
  });

  testWidgets('shows denied-forever permission and opens app settings', (
    tester,
  ) async {
    final service = _FakeLocationService(
      onCapture: () async => throw const LocationCaptureException(
        LocationCaptureFailure.permissionDeniedForever,
      ),
    );
    await tester.pumpWidget(_sectionApp(locationService: service));

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capturar ubicación actual'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Permiso denegado permanentemente. Abra los ajustes para permitirlo.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Abrir ajustes de la aplicación'));
    await tester.pumpAndSettle();
    expect(service.appSettingsCalls, 1);
  });

  testWidgets('shows a retryable message for a denied location permission', (
    tester,
  ) async {
    final service = _FakeLocationService(
      onCapture: () async => throw const LocationCaptureException(
        LocationCaptureFailure.permissionDenied,
      ),
    );
    await tester.pumpWidget(_sectionApp(locationService: service));

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capturar ubicación actual'));
    await tester.pumpAndSettle();

    expect(
      find.text('Permiso de ubicación denegado. Puede volver a intentarlo.'),
      findsOneWidget,
    );
    expect(find.text('Abrir ajustes de la aplicación'), findsNothing);
  });

  testWidgets('reports a location capture timeout after twenty seconds', (
    tester,
  ) async {
    final service = _FakeLocationService(
      onCapture: () => Completer<CapturedLocation>().future,
    );
    await tester.pumpWidget(_sectionApp(locationService: service));

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capturar ubicación actual'));
    await tester.pump();
    expect(find.text('Capturando ubicación...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(
      find.text('Tiempo agotado. Intente capturar de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('confirms and clears identity when consent is turned off', (
    tester,
  ) async {
    PatientIdentityData? latest;
    await tester.pumpWidget(_sectionApp(onChanged: (data) => latest = data));

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo de la paciente'),
      'Ana María',
    );
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Dirección o descripción de la vivienda (vereda, corregimiento, barrio, referencias)',
      ),
      'Vereda Central',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Teléfono de contacto de la paciente'),
      '3001234567',
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('Retirar consentimiento'), findsOneWidget);
    await tester.tap(find.text('Borrar datos'));
    await tester.pumpAndSettle();

    expect(latest?.consentimientoDatos, isFalse);
    expect(latest?.nombrePaciente, isNull);
    expect(latest?.direccionPaciente, isNull);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(
              TextFormField,
              'Nombre completo de la paciente',
            ),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(
              TextFormField,
              'Teléfono de contacto de la paciente',
            ),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('validates contact phone length and accepted formatting', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    PatientIdentityData? latest;
    await tester.pumpWidget(
      _sectionApp(formKey: formKey, onChanged: (data) => latest = data),
    );

    final phoneField = find.widgetWithText(
      TextFormField,
      'Teléfono de contacto de la paciente',
    );
    final phoneWidget = tester.widget<TextFormField>(phoneField);
    expect(phoneWidget.enabled, isFalse);
    final phoneTextField = tester.widget<TextField>(
      find.descendant(of: phoneField, matching: find.byType(TextField)),
    );
    expect(phoneTextField.keyboardType, TextInputType.phone);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo de la paciente'),
      'Ana María',
    );
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Dirección o descripción de la vivienda (vereda, corregimiento, barrio, referencias)',
      ),
      'Vereda Central',
    );
    expect(tester.widget<TextFormField>(phoneField).enabled, isTrue);

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      find.text('El teléfono de contacto es obligatorio.'),
      findsOneWidget,
    );

    await tester.enterText(phoneField, '123-456');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Ingrese entre 7 y 15 dígitos.'), findsOneWidget);

    await tester.enterText(phoneField, '1234567890123456');
    expect(formKey.currentState!.validate(), isFalse);

    await tester.enterText(phoneField, '123 4567');
    expect(formKey.currentState!.validate(), isTrue);
    await tester.enterText(phoneField, '123456789012345');
    expect(formKey.currentState!.validate(), isTrue);
    await tester.enterText(phoneField, '+57 (300) 123-4567');
    expect(formKey.currentState!.validate(), isTrue);
    expect(latest?.telefonoPaciente, '+57 (300) 123-4567');
  });
}

Widget _sectionApp({
  GlobalKey<FormState>? formKey,
  LocationCaptureService? locationService,
  ValueChanged<PatientIdentityData>? onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            children: [
              PatientIdentitySection(
                locationService: locationService,
                onChanged: onChanged ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FakeLocationService implements LocationCaptureService {
  final Future<CapturedLocation> Function() onCapture;
  int appSettingsCalls = 0;
  int locationSettingsCalls = 0;

  _FakeLocationService({required this.onCapture});

  @override
  Future<CapturedLocation> captureCurrentLocation() => onCapture();

  @override
  Future<bool> openAppSettings() async {
    appSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsCalls++;
    return true;
  }
}
