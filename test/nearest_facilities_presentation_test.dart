import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/features/facilities/domain/entities/facility_catalog_status.dart';
import 'package:rmpzd/features/facilities/domain/entities/health_facility.dart';
import 'package:rmpzd/features/facilities/domain/repositories/facility_repository.dart';
import 'package:rmpzd/features/facilities/domain/usecases/get_facility_catalog_status_usecase.dart';
import 'package:rmpzd/features/facilities/domain/usecases/get_nearest_facilities_usecase.dart';
import 'package:rmpzd/features/facilities/presentation/providers/nearest_facilities_provider.dart';
import 'package:rmpzd/features/facilities/presentation/services/facility_link_launcher.dart';
import 'package:rmpzd/features/facilities/presentation/widgets/health_facility_list_item.dart';
import 'package:rmpzd/features/facilities/presentation/widgets/nearest_facilities_section.dart';
import 'package:rmpzd/features/facilities/presentation/widgets/risk_facilities_recommendations.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';

void main() {
  testWidgets('risk levels expand high, collapse moderate, and omit low', (
    tester,
  ) async {
    final repository = _FakeFacilityRepository();
    final provider = _provider(repository);
    await tester.pumpWidget(
      _app(
        provider,
        const RiskFacilitiesRecommendations(
          riskLevel: RiskLevel.alto,
          latitude: 11,
          longitude: -72,
          department: 'La Guajira',
          municipality: 'Riohacha',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Centros de salud cercanos'), findsOneWidget);
    expect(find.text('Obstétrica o urgencias'), findsOneWidget);
    expect(find.text('Ver mapa'), findsOneWidget);
    expect(repository.lastCombinedFilter, isTrue);

    await tester.pumpWidget(
      _app(
        provider,
        const RiskFacilitiesRecommendations(
          riskLevel: RiskLevel.medio,
          latitude: 11,
          longitude: -72,
          department: 'La Guajira',
          municipality: 'Riohacha',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ver centros cercanos'), findsOneWidget);
    expect(find.text('Obstétrica o urgencias'), findsNothing);

    await tester.pumpWidget(
      _app(
        provider,
        const RiskFacilitiesRecommendations(
          riskLevel: RiskLevel.bajo,
          latitude: 11,
          longitude: -72,
          department: 'La Guajira',
          municipality: 'Riohacha',
        ),
      ),
    );
    expect(find.text('Centros de salud cercanos'), findsNothing);
  });

  testWidgets('without GPS it shows the municipality list without distances', (
    tester,
  ) async {
    final repository = _FakeFacilityRepository(
      facilities: [_facility(distanceKm: null)],
    );
    final provider = _provider(repository);
    await tester.pumpWidget(
      _app(
        provider,
        const NearestFacilitiesSection(
          latitude: null,
          longitude: null,
          department: 'La Guajira',
          municipality: 'Riohacha',
          initiallyExpanded: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Sin ubicación GPS: se muestran los centros del municipio'),
      findsOneWidget,
    );
    expect(find.textContaining('≈'), findsNothing);
    expect(repository.lastLatitude, isNull);
    expect(repository.lastLongitude, isNull);
    expect(repository.lastDepartment, 'La Guajira');
    expect(repository.lastMunicipality, 'Riohacha');
  });

  testWidgets('GPS shows the nearest label on the first facility', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeFacilityRepository(
      facilities: [
        _facility(distanceKm: 2.4),
        _facility(id: 'facility-2', distanceKm: 8.1),
      ],
    );
    final provider = _provider(repository);
    await tester.pumpWidget(
      _app(
        provider,
        const NearestFacilitiesSection(
          latitude: 11,
          longitude: -72,
          department: 'La Guajira',
          municipality: 'Riohacha',
          initiallyExpanded: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Más cercano'), findsOneWidget);
    expect(find.textContaining('≈ 2,4 km en línea recta'), findsOneWidget);
    expect(repository.lastDepartment, isNull);
    expect(repository.lastMunicipality, isNull);
  });

  testWidgets('empty catalog shows the connection message', (tester) async {
    final provider = _provider(
      _FakeFacilityRepository(availableCount: 0, facilities: const []),
    );
    await tester.pumpWidget(
      _app(
        provider,
        const NearestFacilitiesSection(
          latitude: 11,
          longitude: -72,
          department: 'Cesar',
          municipality: 'Valledupar',
          initiallyExpanded: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Catálogo de centros no disponible; conéctese a internet para descargarlo',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offline map shows the list and does not create a map', (
    tester,
  ) async {
    final provider = _provider(
      _FakeFacilityRepository(facilities: [_facility(distanceKm: 2.4)]),
      isOnline: false,
    );
    await tester.pumpWidget(
      _app(
        provider,
        const NearestFacilitiesSection(
          latitude: 11,
          longitude: -72,
          department: 'La Guajira',
          municipality: 'Riohacha',
          initiallyExpanded: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver mapa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('El mapa necesita internet'), findsOneWidget);
    expect(find.text('Hospital de prueba'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets(
    'unverified services are shown as unknown and directions fallback',
    (tester) async {
      final launcher = _FakeFacilityLinkLauncher(results: [false, true]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HealthFacilityListItem(
              facility: _facility(
                verified: false,
                obstetricCare: false,
                emergency24h: false,
                distanceKm: 2.4,
              ),
              launcher: launcher,
            ),
          ),
        ),
      );

      expect(find.text('Servicios sin confirmar'), findsOneWidget);
      expect(find.text('Dato no verificado'), findsOneWidget);
      expect(find.text('Urgencias 24 h'), findsNothing);
      expect(find.text('Atención obstétrica'), findsNothing);

      await tester.tap(find.text('Cómo llegar'));
      await tester.pumpAndSettle();
      expect(launcher.calls, hasLength(2));
      expect(launcher.calls.first.scheme, 'geo');
      expect(launcher.calls.first.path, '11.5,-72.9');
      expect(launcher.calls.first.queryParameters['q'], '11.5,-72.9');
      expect(launcher.calls.last.scheme, 'https');
      expect(launcher.calls.last.host, 'www.openstreetmap.org');
      expect(launcher.calls.last.fragment, 'map=17/11.5/-72.9');
    },
  );

  testWidgets('call button opens the center phone number', (tester) async {
    final launcher = _FakeFacilityLinkLauncher();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthFacilityListItem(
            facility: _facility(),
            launcher: launcher,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Llamar'));
    await tester.pumpAndSettle();
    expect(launcher.calls.single.scheme, 'tel');
    expect(launcher.calls.single.path, '6051234567');
  });

  testWidgets('facility cards fit a 360 px screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              HealthFacilityListItem(
                facility: _facility(),
                launcher: const _UnusedFacilityLinkLauncher(),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Cómo llegar'), findsOneWidget);
  });
}

Widget _app(NearestFacilitiesProvider provider, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NearestFacilitiesProvider>.value(value: provider),
      Provider<FacilityLinkLauncher>.value(
        value: const _UnusedFacilityLinkLauncher(),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

NearestFacilitiesProvider _provider(
  _FakeFacilityRepository repository, {
  bool isOnline = true,
}) {
  return NearestFacilitiesProvider(
    getNearestFacilities: GetNearestFacilitiesUseCase(repository),
    getCatalogStatus: GetFacilityCatalogStatusUseCase(repository),
    checkInternet: () async => isOnline,
  );
}

HealthFacility _facility({
  String id = 'facility-1',
  bool? verified = true,
  bool? obstetricCare = true,
  bool? emergency24h = true,
  double? distanceKm = 2.4,
}) {
  return HealthFacility(
    id: id,
    name: 'Hospital de prueba',
    type: 'Hospital',
    careLevel: 2,
    municipality: 'Riohacha',
    department: 'La Guajira',
    phone: '6051234567',
    latitude: 11.5,
    longitude: -72.9,
    obstetricCare: obstetricCare,
    emergency24h: emergency24h,
    deliveryCare: false,
    adultIcu: false,
    verified: verified,
    active: true,
    distanceKm: distanceKm,
  );
}

class _FakeFacilityRepository implements FacilityRepository {
  final int availableCount;
  final List<HealthFacility> facilities;

  double? lastLatitude;
  double? lastLongitude;
  String? lastDepartment;
  String? lastMunicipality;
  bool? lastCombinedFilter;

  _FakeFacilityRepository({
    this.availableCount = 1,
    this.facilities = const [],
  });

  @override
  Future<int> syncFacilities() async => 0;

  @override
  Future<FacilityCatalogStatus> getCatalogStatus() async =>
      FacilityCatalogStatus(
        availableCount: availableCount,
        lastUpdatedAt: DateTime.utc(2026, 1, 1),
      );

  @override
  Future<List<HealthFacility>> getNearestFacilities(
    double? latitude,
    double? longitude, {
    int limit = 5,
    bool soloObstetricas = false,
    bool soloUrgencias = false,
    bool soloObstetricasOUrgencias = false,
    String? departamento,
    String? municipio,
  }) async {
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastDepartment = departamento;
    lastMunicipality = municipio;
    lastCombinedFilter = soloObstetricasOUrgencias;
    return facilities.take(limit).toList();
  }
}

class _FakeFacilityLinkLauncher implements FacilityLinkLauncher {
  final List<bool> results;
  final List<Uri> calls = [];

  _FakeFacilityLinkLauncher({this.results = const [true]});

  @override
  Future<bool> launch(Uri uri) async {
    calls.add(uri);
    return results[calls.length - 1];
  }
}

class _UnusedFacilityLinkLauncher implements FacilityLinkLauncher {
  const _UnusedFacilityLinkLauncher();

  @override
  Future<bool> launch(Uri uri) async => true;
}
