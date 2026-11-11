import 'package:flutter/material.dart';
import 'form_section_header.dart';

class GestationAccessSection extends StatelessWidget {
  final TextEditingController ageController;
  final TextEditingController weeksController;
  final TextEditingController visitsController;
  final TextEditingController distanceController;
  final TextEditingController travelTimeController;

  const GestationAccessSection({
    required this.ageController,
    required this.weeksController,
    required this.visitsController,
    required this.distanceController,
    required this.travelTimeController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionHeader('Gestación y Acceso al Servicio'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        controller: ageController,
                        label: 'Edad Materna',
                        suffix: 'años',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: weeksController,
                        label: 'Semanas Gest.',
                        suffix: 'sem',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        controller: visitsController,
                        label: 'Controles Realizados',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: distanceController,
                        label: 'Distancia Centro',
                        suffix: 'km',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _numberField(
                  controller: travelTimeController,
                  label: 'Tiempo Estimado de Traslado',
                  suffix: 'horas',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) => value!.isEmpty ? 'Requerido' : null,
    );
  }
}
