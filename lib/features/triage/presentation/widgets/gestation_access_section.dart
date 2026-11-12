import 'package:flutter/material.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../core/utils/validators.dart';
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
                        validator: requiredInt(
                          InputLimits.ageMin,
                          InputLimits.ageMax,
                        ),
                        integer: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: weeksController,
                        label: 'Semanas Gest.',
                        suffix: 'sem',
                        validator: requiredInt(
                          InputLimits.gestationalWeeksMin,
                          InputLimits.gestationalWeeksMax,
                        ),
                        integer: true,
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
                        validator: requiredInt(
                          InputLimits.prenatalVisitsMin,
                          InputLimits.prenatalVisitsMax,
                        ),
                        integer: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: distanceController,
                        label: 'Distancia Centro',
                        suffix: 'km',
                        validator: requiredDouble(
                          InputLimits.distanceMin,
                          InputLimits.distanceMax,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _numberField(
                  controller: travelTimeController,
                  label: 'Tiempo Estimado de Traslado',
                  suffix: 'horas',
                  validator: requiredDouble(
                    InputLimits.travelTimeMin,
                    InputLimits.travelTimeMax,
                  ),
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
    required FormFieldValidator<String> validator,
    bool integer = false,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: integer
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: validator,
    );
  }
}
