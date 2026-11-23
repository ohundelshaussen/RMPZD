import 'package:flutter/material.dart';

import '../../domain/entities/health_facility.dart';
import '../services/facility_link_launcher.dart';

class FacilityActionButtons extends StatelessWidget {
  final HealthFacility facility;
  final FacilityLinkLauncher launcher;

  const FacilityActionButtons({
    required this.facility,
    required this.launcher,
    super.key,
  });

  Uri get _directionsUri => Uri(
    scheme: 'geo',
    path: '${facility.latitude},${facility.longitude}',
    queryParameters: {'q': '${facility.latitude},${facility.longitude}'},
  );

  Uri get _openStreetMapUri {
    final latitude = facility.latitude!;
    final longitude = facility.longitude!;
    return Uri.https('www.openstreetmap.org', '/', {
      'mlat': '$latitude',
      'mlon': '$longitude',
    }).replace(fragment: 'map=17/$latitude/$longitude');
  }

  Future<void> _call(BuildContext context) async {
    final phone = facility.phone;
    if (phone == null || phone.trim().isEmpty) return;
    final launched = await launcher.launch(
      Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+'), '')),
    );
    if (!launched && context.mounted) {
      _showLaunchError(context);
    }
  }

  Future<void> _directions(BuildContext context) async {
    if (facility.latitude == null || facility.longitude == null) return;
    var launched = await launcher.launch(_directionsUri);
    if (!launched) {
      launched = await launcher.launch(_openStreetMapUri);
    }
    if (!launched && context.mounted) {
      _showLaunchError(context);
    }
  }

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No fue posible abrir la aplicación.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCall = facility.phone?.trim().isNotEmpty == true;
    final canNavigate = facility.latitude != null && facility.longitude != null;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canCall ? () => _call(context) : null,
            icon: const Icon(Icons.call_outlined, size: 16),
            label: const Text('Llamar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canNavigate ? () => _directions(context) : null,
            icon: const Icon(Icons.directions_outlined, size: 16),
            label: const Text('Cómo llegar'),
          ),
        ),
      ],
    );
  }
}
