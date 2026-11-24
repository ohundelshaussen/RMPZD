import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/health_facility.dart';
import '../pages/facilities_map_page.dart';
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

  bool get _hasLocation =>
      widget.latitude != null &&
      widget.longitude != null &&
      widget.latitude!.isFinite &&
      widget.longitude!.isFinite &&
      widget.latitude! >= -90 &&
      widget.latitude! <= 90 &&
      widget.longitude! >= -180 &&
      widget.longitude! <= 180;

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
      if (_isExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadFacilities();
        });
      }
    }
  }

  Future<void> _loadFacilities() {
    return context.read<NearestFacilitiesProvider>().load(
      latitude: widget.latitude,
      longitude: widget.longitude,
      department: _hasLocation ? null : widget.department,
      municipality: _hasLocation ? null : widget.municipality,
      soloObstetricasOUrgencias: _onlyObstetricOrEmergency,
      limit: 5,
    );
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
          latitude: widget.latitude,
          longitude: widget.longitude,
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
      elevation: widget.highRisk ? 4 : 2,
      color: widget.highRisk
          ? const Color(0xFFFFF8E8)
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: widget.highRisk
            ? const BorderSide(color: Color(0xFFF2C66D))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.local_hospital_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Centros de salud cercanos',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_isExpanded)
                  IconButton(
                    tooltip: 'Contraer centros cercanos',
                    onPressed: () => setState(() => _isExpanded = false),
                    icon: const Icon(Icons.expand_less),
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
            if (_isExpanded)
              Consumer<NearestFacilitiesProvider>(
                builder: (context, provider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.highRisk)
                        FilterChip(
                          label: const Text('Obstétrica o urgencias'),
                          selected: _onlyObstetricOrEmergency,
                          onSelected: (selected) {
                            setState(
                              () => _onlyObstetricOrEmergency = selected,
                            );
                            _loadFacilities();
                          },
                        ),
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
                        ),
                      if (provider.catalogAvailable) ...[
                        const SizedBox(height: 4),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _openMap(context, provider, launcher),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Ver mapa'),
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
