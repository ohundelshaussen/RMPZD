import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/colombia_locations.dart';
import 'facilities_map_page.dart';

class LocationPickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialMunicipality;

  const LocationPickerPage({
    this.initialLatitude,
    this.initialLongitude,
    this.initialMunicipality,
    super.key,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  LatLng? _pickedPoint;
  double _currentZoom = 13;

  LatLng get _initialCenter {
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      return LatLng(lat, lng);
    }
    final centroid = coordinatesForMunicipality(widget.initialMunicipality);
    if (centroid != null) {
      return LatLng(centroid.lat, centroid.lng);
    }
    return const LatLng(10.4693, -73.2545);
  }

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      _pickedPoint = LatLng(lat, lng);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final targetZoom = (_currentZoom + delta).clamp(4.0, 18.0);
    setState(() => _currentZoom = targetZoom);
    _mapController.move(_pickedPoint ?? _initialCenter, targetZoom);
  }

  @override
  Widget build(BuildContext context) {
    final point = _pickedPoint;

    return Scaffold(
      appBar: AppBar(title: const Text('Elegir ubicación en mapa')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              border: Border(bottom: BorderSide(color: Color(0xFFBBF7D0))),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point == null
                        ? 'Toca el mapa para fijar la ubicación'
                        : 'Lat: ${point.latitude.toStringAsFixed(5)} · '
                              'Lng: ${point.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: _currentZoom,
                    onTap: (_, tappedPoint) {
                      setState(() => _pickedPoint = tappedPoint);
                    },
                    onPositionChanged: (camera, _) {
                      _currentZoom = camera.zoom;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: openStreetMapTileUrl,
                      userAgentPackageName: appUserAgentPackageName,
                    ),
                    if (point != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 44,
                            height: 52,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 44,
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
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'picker-zoom-in',
                        tooltip: 'Acercar',
                        onPressed: () => _zoomBy(1),
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 6),
                      FloatingActionButton.small(
                        heroTag: 'picker-zoom-out',
                        tooltip: 'Alejar',
                        onPressed: () => _zoomBy(-1),
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: point == null
                      ? null
                      : () => Navigator.of(context).pop<LatLng>(point),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Usar esta ubicación'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
