import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DemoCaseSelector extends StatelessWidget {
  final ValueChanged<int> onSelected;

  const DemoCaseSelector({required this.onSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bolt_rounded, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                'Offline IA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<int>(
          icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
          tooltip: 'Cargar casos para demostración',
          onSelected: onSelected,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 1,
              child: Text('Caso 1: Bajo Riesgo (Urbano)'),
            ),
            const PopupMenuItem(
              value: 2,
              child: Text('Caso 2: Emergencia Hipertensiva (Wayuu)'),
            ),
            const PopupMenuItem(
              value: 3,
              child: Text('Caso 3: Riesgo Moderado (Arhuaco)'),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
