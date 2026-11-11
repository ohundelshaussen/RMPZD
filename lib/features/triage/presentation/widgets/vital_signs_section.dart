import 'package:flutter/material.dart';
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: diastolicController,
                        label: 'PA Diastólica',
                        suffix: 'mmHg',
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: bmiController,
                        label: 'IMC',
                        suffix: 'kg/m²',
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) => value!.isEmpty ? 'Requerido' : null,
    );
  }
}
