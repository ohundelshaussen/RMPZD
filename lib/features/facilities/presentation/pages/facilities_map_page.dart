import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

  const FacilitiesMapPage({
    required this.facilities,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    required this.catalogAvailable,
    required this.launcher,
    super.key,
  });

  @override
  State<FacilitiesMapPage> createState() => _FacilitiesMapPageState();
}

class _FacilitiesMapPageState extends State<FacilitiesMapPage> {
  bool _tilesFailed = false;
  HealthFacility? _selectedFacility;

  List<HealthFacility> get _locatedFacilities => widget.facilities
      .where(
        (facility) => facility.latitude != null && facility.longitude != null,
      )
      .toList();

  List<LatLng> get _mapPoints => [
    if (widget.latitude != null && widget.longitude != null)
      LatLng(widget.latitude!, widget.longitude!),
    for (final facility in _locatedFacilities)
      LatLng(facility.latitude!, facility.longitude!),
  ];

  LatLng get _initialCenter {
    final points = _mapPoints;
    if (points.isNotEmpty) return points.first;
    return const LatLng(4.5709, -74.2973);
  }

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (!mounted || _tilesFailed) return;
    setState(() => _tilesFailed = true);
  }

  Widget _buildListFallback({required bool showMapMessage}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showMapMessage)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(facilitiesMapInternetMessage),
          ),
        FacilityResultsContent(
          facilities: widget.facilities,
          launcher: widget.launcher,
          catalogAvailable: widget.catalogAvailable,
          hasAssessmentLocation:
              widget.latitude != null && widget.longitude != null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline || _tilesFailed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Centros de salud cercanos')),
        body: _buildListFallback(showMapMessage: true),
      );
    }

    final points = _mapPoints;
    return Scaffold(
      appBar: AppBar(title: const Text('Centros de salud cercanos')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFFFF7E6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  facilityTransferSafetyMessage,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(facilityDistanceExplanation),
                if (widget.latitude == null || widget.longitude == null) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Sin ubicación GPS: se muestran los centros del municipio',
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 12,
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
                    MarkerLayer(
                      markers: [
                        if (widget.latitude != null && widget.longitude != null)
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
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _selectedFacility =
                                      widget.facilities[index],
                                ),
                                child: CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
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
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                const Positioned(
                  bottom: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      child: Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                if (_selectedFacility case final facility?)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: HealthFacilityListItem(
                          facility: facility,
                          launcher: widget.launcher,
                          showDistance:
                              widget.latitude != null &&
                              widget.longitude != null,
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
