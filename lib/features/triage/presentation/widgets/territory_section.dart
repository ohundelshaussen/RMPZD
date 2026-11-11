import 'package:flutter/material.dart';
import '../../../../core/constants/colombia_locations.dart';
import '../../../../core/constants/form_options.dart';
import 'form_section_header.dart';

class TerritorySection extends StatelessWidget {
  final TextEditingController patientIdController;
  final String department;
  final String municipality;
  final String ethnicity;
  final String zone;
  final String affiliation;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onMunicipalityChanged;
  final ValueChanged<String> onEthnicityChanged;
  final ValueChanged<String> onZoneChanged;
  final ValueChanged<String> onAffiliationChanged;

  const TerritorySection({
    required this.patientIdController,
    required this.department,
    required this.municipality,
    required this.ethnicity,
    required this.zone,
    required this.affiliation,
    required this.onDepartmentChanged,
    required this.onMunicipalityChanged,
    required this.onEthnicityChanged,
    required this.onZoneChanged,
    required this.onAffiliationChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionHeader('Territorio y Enfoque Diferencial'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: patientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Identificador / ID de Gestante',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                  validator: (value) => value!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('depto_$department'),
                        initialValue: department,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Departamento',
                        ),
                        items: colombiaDepartments
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) onDepartmentChanged(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('muni_$municipality'),
                        initialValue: municipality,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Municipio',
                        ),
                        items: municipalitiesByDepartment[department]!
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) onMunicipalityChanged(value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('etnia_$ethnicity'),
                        initialValue: ethnicity,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Etnia'),
                        items: ethnicities
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) onEthnicityChanged(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('zona_$zone'),
                        initialValue: zone,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Zona'),
                        items: residentialZones
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) onZoneChanged(value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('afiliacion_$affiliation'),
                  initialValue: affiliation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Régimen de Salud (SGSSS)',
                  ),
                  items: healthAffiliations
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onAffiliationChanged(value);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
