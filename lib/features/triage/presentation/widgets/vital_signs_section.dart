import 'package:flutter/material.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../core/utils/validators.dart';
import 'form_section_header.dart';

class VitalSignsSection extends StatelessWidget {
  final TextEditingController systolicController;
  final TextEditingController diastolicController;
  final TextEditingController hemoglobinController;
  final TextEditingController bmiController;

  const VitalSignsSection({
    required this.systolicController,
    required this.diastolicController,
    required this.hemoglobinController,
    required this.bmiController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionHeader('Signos Vitales y Laboratorio'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        controller: systolicController,
                        label: 'PA Sistólica',
                        suffix: 'mmHg',
                        validator: requiredDouble(
                          InputLimits.systolicPressureMin,
                          InputLimits.systolicPressureMax,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: diastolicController,
                        label: 'PA Diastólica',
                        suffix: 'mmHg',
                        validator: combineValidators([
                          requiredDouble(
                            InputLimits.diastolicPressureMin,
                            InputLimits.diastolicPressureMax,
                          ),
                          lessThanController(
                            systolicController,
                            message:
                                'La presión diastólica debe ser menor que la sistólica',
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        controller: hemoglobinController,
                        label: 'Hemoglobina',
                        suffix: 'g/dL',
                        validator: requiredDouble(
                          InputLimits.hemoglobinMin,
                          InputLimits.hemoglobinMax,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: bmiController,
                        label: 'IMC',
                        suffix: 'kg/m²',
                        validator: requiredDouble(
                          InputLimits.bmiMin,
                          InputLimits.bmiMax,
                        ),
                      ),
                    ),
                  ],
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
    required String suffix,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: validator,
    );
  }
}
