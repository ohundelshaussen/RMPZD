import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'form_section_header.dart';

class ClinicalHistorySection extends StatelessWidget {
  final bool preeclampsia;
  final bool diabetes;
  final bool institutionalBirth;
  final ValueChanged<bool> onPreeclampsiaChanged;
  final ValueChanged<bool> onDiabetesChanged;
  final ValueChanged<bool> onInstitutionalBirthChanged;

  const ClinicalHistorySection({
    required this.preeclampsia,
    required this.diabetes,
    required this.institutionalBirth,
    required this.onPreeclampsiaChanged,
    required this.onDiabetesChanged,
    required this.onInstitutionalBirthChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionHeader('Antecedentes Clínicos'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildSwitchRow(
                  title: 'Antecedente de Preeclampsia',
                  value: preeclampsia,
                  onChanged: onPreeclampsiaChanged,
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildSwitchRow(
                  title: 'Antecedente de Diabetes Gestacional',
                  value: diabetes,
                  onChanged: onDiabetesChanged,
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildSwitchRow(
                  title: 'Parto Institucional Previo',
                  value: institutionalBirth,
                  onChanged: onInstitutionalBirthChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
