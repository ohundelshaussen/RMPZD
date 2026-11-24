import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/health_facility.dart';
import '../pages/facilities_map_page.dart';
import '../pages/location_picker_page.dart';
import '../providers/nearest_facilities_provider.dart';
import '../services/facility_link_launcher.dart';
import 'facility_results_content.dart';

class NearestFacilitiesSection extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? department;
  final String? municipality;
  final bool highRisk;
  final bool initiallyExpanded;

  const NearestFacilitiesSection({
    required this.latitude,
    required this.longitude,
    required this.department,
    required this.municipality,
    this.highRisk = false,
    this.initiallyExpanded = true,
    super.key,
  });

  @override
  State<NearestFacilitiesSection> createState() =>
      _NearestFacilitiesSectionState();
}

class _NearestFacilitiesSectionState extends State<NearestFacilitiesSection> {
  late bool _isExpanded;
  late bool _onlyObstetricOrEmergency;
  double? _overrideLatitude;
  double? _overrideLongitude;

  static bool _isValidCoordinatePair(double? lat, double? lng) =>
      lat != null &&
      lng != null &&
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;

  double? get _effectiveLatitude =>
      _isValidCoordinatePair(widget.latitude, widget.longitude)
      ? widget.latitude
      : _overrideLatitude;

  double? get _effectiveLongitude =>
      _isValidCoordinatePair(widget.latitude, widget.longitude)
      ? widget.longitude
      : _overrideLongitude;

  bool get _hasLocation =>
      _isValidCoordinatePair(_effectiveLatitude, _effectiveLongitude);

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _onlyObstetricOrEmergency = widget.highRisk;
    if (_isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadFacilities();
      });
    }
  }

  @override
  void didUpdateWidget(covariant NearestFacilitiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highRisk != widget.highRisk ||
        oldWidget.initiallyExpanded != widget.initiallyExpanded ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.department != widget.department ||
        oldWidget.municipality != widget.municipality) {
      _isExpanded = widget.initiallyExpanded;
      _onlyObstetricOrEmergency = widget.highRisk;
      _overrideLatitude = null;
      _overrideLongitude = null;
      if (_isExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadFacilities();
        });
      }
    }
  }

  Future<void> _loadFacilities() {
    return context.read<NearestFacilitiesProvider>().load(
      latitude: _effectiveLatitude,
      longitude: _effectiveLongitude,
      department: _hasLocation ? null : widget.department,
      municipality: _hasLocation ? null : widget.municipality,
      soloObstetricasOUrgencias: _onlyObstetricOrEmergency,
      limit: 5,
    );
  }

  Future<void> _pickReferenceLocation() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLatitude: _effectiveLatitude,
          initialLongitude: _effectiveLongitude,
          initialMunicipality: widget.municipality,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _overrideLatitude = picked.latitude;
      _overrideLongitude = picked.longitude;
    });
    await _loadFacilities();
  }

  Future<void> _openMap(
    BuildContext context,
    NearestFacilitiesProvider provider,
    FacilityLinkLauncher launcher,
  ) async {
    final facilities = List<HealthFacility>.of(provider.facilities);
    final isOnline = await provider.refreshConnectivity();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FacilitiesMapPage(
          facilities: facilities,
          latitude: _effectiveLatitude,
          longitude: _effectiveLongitude,
          isOnline: isOnline,
          catalogAvailable: provider.catalogAvailable,
          launcher: launcher,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final launcher = context.read<FacilityLinkLauncher>();
    return Card(
      elevation: 0,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.highRisk
              ? AppColors.secondary.withValues(alpha: 0.45)
              : AppColors.border,
          width: widget.highRisk ? 1.2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_hospital_outlined,
                  size: 19,
                  color: widget.highRisk
                      ? AppColors.secondary
                      : AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Centros de salud cercanos',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_isExpanded)
                  IconButton(
                    tooltip: 'Contraer centros cercanos',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _isExpanded = false),
                    icon: const Icon(
                      Icons.expand_less,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  TextButton(
                    onPressed: () {
                      setState(() => _isExpanded = true);
                      _loadFacilities();
                    },
                    child: const Text('Ver centros cercanos'),
                  ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 10),
              Consumer<NearestFacilitiesProvider>(
                builder: (context, provider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.highRisk) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilterChip(
                            label: const Text('Obstétrica o urgencias'),
                            selected: _onlyObstetricOrEmergency,
                            onSelected: (selected) {
                              setState(
                                () => _onlyObstetricOrEmergency = selected,
                              );
                              _loadFacilities();
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (provider.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        FacilityResultsContent(
                          facilities: provider.facilities,
                          launcher: launcher,
                          catalogAvailable: provider.catalogAvailable,
                          errorMessage: provider.errorMessage,
                          hasAssessmentLocation: _hasLocation,
                          assessmentLatitude: _effectiveLatitude,
                          assessmentLongitude: _effectiveLongitude,
                        ),
                      if (provider.catalogAvailable && !_hasLocation) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _pickReferenceLocation,
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: const Text('Ubicar en mapa'),
                        ),
                      ],
                      if (provider.catalogAvailable) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.10,
                            ),
                            foregroundColor: AppColors.primaryDark,
                            elevation: 0,
                          ),
                          onPressed: () =>
                              _openMap(context, provider, launcher),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Ver mapa'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
