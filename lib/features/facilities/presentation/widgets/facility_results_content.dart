import 'package:flutter/material.dart';

import '../../domain/entities/health_facility.dart';
import '../services/facility_link_launcher.dart';
import 'health_facility_list_item.dart';

const facilityTransferSafetyMessage =
    'Confirme la disponibilidad por teléfono antes del traslado. '
    'En una emergencia llame a la línea 123 o a la central de urgencias de su red.';
const facilityDistanceExplanation =
    'La distancia es aproximada en línea recta; el camino real puede ser mayor.';
const facilitiesMapInternetMessage =
    'El mapa necesita internet; la lista de centros y las distancias funcionan sin conexión';
const facilitiesCatalogUnavailableMessage =
    'Catálogo de centros no disponible; conéctese a internet para descargarlo';

class FacilityResultsContent extends StatelessWidget {
  final List<HealthFacility> facilities;
  final FacilityLinkLauncher launcher;
  final bool catalogAvailable;
  final String? errorMessage;
  final bool hasAssessmentLocation;

  const FacilityResultsContent({
    required this.facilities,
    required this.launcher,
    required this.catalogAvailable,
    required this.hasAssessmentLocation,
    this.errorMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (!catalogAvailable) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(facilitiesCatalogUnavailableMessage),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasAssessmentLocation) ...[
          const Text(
            'Sin ubicación GPS: se muestran los centros del municipio',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD98A)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facilityTransferSafetyMessage,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 5),
              Text(facilityDistanceExplanation),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (facilities.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No se encontraron centros con estos criterios.'),
          )
        else
          for (var index = 0; index < facilities.length; index++)
            HealthFacilityListItem(
              key: ValueKey(facilities[index].id),
              facility: facilities[index],
              launcher: launcher,
              number: index + 1,
              showDistance: hasAssessmentLocation,
            ),
      ],
    );
  }
}
