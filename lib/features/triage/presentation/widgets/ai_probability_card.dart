import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/triage_result.dart';

class AiProbabilityCard extends StatelessWidget {
  final TriageResult result;

  const AiProbabilityCard({required this.result, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estimación de Modelos de IA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProbBar(
              'Alto Riesgo',
              result.probAlto,
              AppColors.riskHigh,
              threshold: 0.25,
            ),
            const SizedBox(height: 10),
            _buildProbBar(
              'Riesgo Moderado',
              result.probMedio,
              AppColors.riskMedium,
            ),
            const SizedBox(height: 10),
            _buildProbBar('Bajo Riesgo', result.probBajo, AppColors.riskLow),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Desenlace Gestacional Estimado:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: result.riesgoDesenlaceAdverso
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        result.riesgoDesenlaceAdverso
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: result.riesgoDesenlaceAdverso
                            ? AppColors.riskHigh
                            : AppColors.riskLow,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        result.riesgoDesenlaceAdverso
                            ? 'Posible Complicación Obstétrica (${(result.probDesenlaceAdverso * 100).toStringAsFixed(1)}%)'
                            : 'Desenlace Normal / Estable (${(result.probDesenlaceAdverso * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: result.riesgoDesenlaceAdverso
                              ? AppColors.riskHigh
                              : AppColors.riskLow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbBar(
    String label,
    double probability,
    Color color, {
    double? threshold,
  }) {
    final percentage = (probability * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                threshold != null
                    ? '$label (Umbral ${(threshold * 100).toInt()}%)'
                    : label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: probability.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
