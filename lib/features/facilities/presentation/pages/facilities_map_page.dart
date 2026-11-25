import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/health_facility.dart';
import '../services/facility_link_launcher.dart';
import '../widgets/facility_results_content.dart';
import '../widgets/health_facility_list_item.dart';

const openStreetMapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const appUserAgentPackageName = 'com.unicesar.rmpzd.rmpzd';

class FacilitiesMapPage extends StatefulWidget {
  final List<HealthFacility> facilities;
  final double? latitude;
  final double? longitude;
  final bool isOnline;
  final bool catalogAvailable;
  final FacilityLinkLauncher launcher;
  final ValueChanged<HealthFacility>? onRefer;

  const FacilitiesMapPage({
    required this.facilities,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    required this.catalogAvailable,
    required this.launcher,
    this.onRefer,
    super.key,
  });

  @override
  State<FacilitiesMapPage> createState() => _FacilitiesMapPageState();
}

class _FacilitiesMapPageState extends State<FacilitiesMapPage> {
  static const _tileWarningThreshold = 4;

  final MapController _mapController = MapController();
  int _tileErrorCount = 0;
  int _mapGeneration = 0;
  bool _forceListView = false;
  HealthFacility? _selectedFacility;

  bool get _hasAssessmentLocation =>
      widget.latitude != null &&
      widget.longitude != null &&
      widget.latitude!.isFinite &&
      widget.longitude!.isFinite &&
      widget.latitude! >= -90 &&
      widget.latitude! <= 90 &&
      widget.longitude! >= -180 &&
      widget.longitude! <= 180;

  List<HealthFacility> get _locatedFacilities => widget.facilities
      .where(
        (facility) =>
            facility.latitude != null &&
            facility.longitude != null &&
            facility.latitude!.isFinite &&
            facility.longitude!.isFinite,
      )
      .toList();

  List<LatLng> get _mapPoints => [
    if (_hasAssessmentLocation) LatLng(widget.latitude!, widget.longitude!),
    for (final facility in _locatedFacilities)
      LatLng(facility.latitude!, facility.longitude!),
  ];

  LatLng get _initialCenter {
    final points = _mapPoints;
    if (points.isNotEmpty) return points.first;
    return const LatLng(10.4693, -73.2545);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    if (_tileErrorCount <= _tileWarningThreshold) {
      setState(() => _tileErrorCount++);
    }
  }

  void _retryMap() {
    setState(() {
      _tileErrorCount = 0;
      _forceListView = false;
      _mapGeneration++;
    });
  }

  void _zoomBy(double delta) {
    try {
      final camera = _mapController.camera;
      final targetZoom = (camera.zoom + delta).clamp(4.0, 18.0);
      _mapController.move(camera.center, targetZoom);
    } on Object {
      // MapController may not yet have attached state in early frame ticks.
    }
  }

  void _fitAll() {
    final points = _mapPoints;
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _mapController.move(points.first, 14);
      } else {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(48),
          ),
        );
      }
    } on Object {
      // MapController may not yet have attached state.
    }
  }

  void _selectFacility(HealthFacility facility) {
    setState(() => _selectedFacility = facility);
    if (facility.latitude != null && facility.longitude != null) {
      try {
        _mapController.move(
          LatLng(facility.latitude!, facility.longitude!),
          14,
        );
      } on Object {
        // Ignore if map not laid out yet.
      }
    }
  }

  Widget _buildListFallback({required bool showMapMessage}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showMapMessage)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Expanded(child: Text(facilitiesMapInternetMessage)),
                if (widget.isOnline)
                  TextButton(
                    onPressed: _retryMap,
                    child: const Text('Reintentar mapa'),
                  ),
              ],
            ),
          ),
        FacilityResultsContent(
          facilities: widget.facilities,
          launcher: widget.launcher,
          catalogAvailable: widget.catalogAvailable,
          hasAssessmentLocation: _hasAssessmentLocation,
          assessmentLatitude: widget.latitude,
          assessmentLongitude: widget.longitude,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline || _forceListView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Centros de salud cercanos')),
        body: _buildListFallback(showMapMessage: true),
      );
    }

    final points = _mapPoints;
    final selected = _selectedFacility;
    final located = _locatedFacilities;
    final selectedIndex = selected == null ? -1 : located.indexOf(selected);

    return Scaffold(
      appBar: AppBar(title: const Text('Centros de salud cercanos')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              border: Border(bottom: BorderSide(color: Color(0xFFFDE68A))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  facilityTransferSafetyMessage,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 3),
                const Text(
                  facilityDistanceExplanation,
                  style: TextStyle(fontSize: 12),
                ),
                if (!_hasAssessmentLocation) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'Sin ubicación GPS: se muestran los centros del municipio',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_hasAssessmentLocation) ...[
                      const _LegendDot(
                        color: Colors.red,
                        label: 'Tu ubicación',
                      ),
                      _LegendDot(
                        color: Colors.orange.shade700,
                        label: 'Más cercano',
                      ),
                    ],
                    _LegendDot(
                      color: Theme.of(context).colorScheme.primary,
                      label: 'Centro de salud',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  key: ValueKey(_mapGeneration),
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: points.length == 1 ? 14 : 12,
                    onTap: (_, _) {
                      if (_selectedFacility != null) {
                        setState(() => _selectedFacility = null);
                      }
                    },
                    initialCameraFit: points.length > 1
                        ? CameraFit.coordinates(
                            coordinates: points,
                            padding: const EdgeInsets.all(48),
                          )
                        : null,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: openStreetMapTileUrl,
                      userAgentPackageName: appUserAgentPackageName,
                      errorTileCallback: _onTileError,
                    ),
                    if (_hasAssessmentLocation &&
                        selected != null &&
                        selected.latitude != null &&
                        selected.longitude != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(widget.latitude!, widget.longitude!),
                              LatLng(selected.latitude!, selected.longitude!),
                            ],
                            strokeWidth: 3.5,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (_hasAssessmentLocation)
                          Marker(
                            point: LatLng(widget.latitude!, widget.longitude!),
                            width: 44,
                            height: 52,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 44,
                            ),
                          ),
                        for (
                          var index = 0;
                          index < widget.facilities.length;
                          index++
                        )
                          if (widget.facilities[index].latitude != null &&
                              widget.facilities[index].longitude != null)
                            Marker(
                              point: LatLng(
                                widget.facilities[index].latitude!,
                                widget.facilities[index].longitude!,
                              ),
                              width: (_hasAssessmentLocation && index == 0)
                                  ? 52
                                  : 44,
                              height: (_hasAssessmentLocation && index == 0)
                                  ? 52
                                  : 44,
                              child: GestureDetector(
                                onTap: () =>
                                    _selectFacility(widget.facilities[index]),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        selected?.id ==
                                            widget.facilities[index].id
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 2.5,
                                          )
                                        : null,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor:
                                        (_hasAssessmentLocation && index == 0)
                                        ? Colors.orange.shade700
                                        : Theme.of(context).colorScheme.primary,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                if (_tileErrorCount >= _tileWarningThreshold)
                  Positioned(
                    left: 12,
                    top: 12,
                    right: 68,
                    child: Material(
                      elevation: 2,
                      color: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 16,
                              color: AppColors.riskHigh,
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Problemas al cargar el mapa',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _retryMap,
                              child: const Text('Reintentar'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _forceListView = true),
                              child: const Text('Ver lista'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'facilities-zoom-in',
                        tooltip: 'Acercar',
                        onPressed: () => _zoomBy(1),
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 6),
                      FloatingActionButton.small(
                        heroTag: 'facilities-zoom-out',
                        tooltip: 'Alejar',
                        onPressed: () => _zoomBy(-1),
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 6),
                      FloatingActionButton.small(
                        heroTag: 'facilities-fit-all',
                        tooltip: 'Ajustar vista',
                        onPressed: _fitAll,
                        child: const Icon(Icons.fit_screen_outlined),
                      ),
                    ],
                  ),
                ),
                if (selected != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: HealthFacilityListItem(
                          facility: selected,
                          launcher: widget.launcher,
                          number: selectedIndex >= 0 ? selectedIndex + 1 : null,
                          showDistance: _hasAssessmentLocation,
                          originLatitude: widget.latitude,
                          originLongitude: widget.longitude,
                          onClose: () =>
                              setState(() => _selectedFacility = null),
                          onRefer: widget.onRefer == null
                              ? null
                              : () => widget.onRefer!(selected),
                        ),
                      ),
                    ),
                  )
                else if (located.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: SizedBox(
                        height: 52,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          scrollDirection: Axis.horizontal,
                          itemCount: located.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final facility = located[index];
                            final markerNumber =
                                widget.facilities.indexOf(facility) + 1;
                            final name =
                                facility.name?.trim().isNotEmpty == true
                                ? facility.name!
                                : 'Centro de salud';
                            final distanceLabel =
                                _hasAssessmentLocation &&
                                    facility.distanceKm != null
                                ? ' (${facility.distanceKm!.toStringAsFixed(1)} km)'
                                : '';
                            return ActionChip(
                              avatar: CircleAvatar(
                                backgroundColor:
                                    (_hasAssessmentLocation && index == 0)
                                    ? Colors.orange.shade700
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                child: const Icon(
                                  Icons.local_hospital_outlined,
                                  size: 14,
                                ),
                              ),
                              label: Text('$markerNumber. $name$distanceLabel'),
                              onPressed: () => _selectFacility(facility),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
