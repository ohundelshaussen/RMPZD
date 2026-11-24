import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/triage_result.dart';

class AiProbabilityCard extends StatelessWidget {
  final TriageResult result;

  const AiProbabilityCard({required this.result, super.key});

  @override
  Widget build(BuildContext context) {
    final highlightHigh =
        result.riskLevel == RiskLevel.alto || result.probAlto >= 0.25;
    final highlightMedium = result.riskLevel == RiskLevel.medio;
    final highlightLow =
        result.riskLevel == RiskLevel.bajo && !highlightHigh;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: AppColors.textSecondary,
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
            const SizedBox(height: 14),
            _buildProbBar(
              'Alto Riesgo',
              result.probAlto,
              accentColor: AppColors.riskHigh,
              highlighted: highlightHigh,
              threshold: 0.25,
            ),
            const SizedBox(height: 11),
            _buildProbBar(
              'Riesgo Moderado',
              result.probMedio,
              accentColor: AppColors.riskMedium,
              highlighted: highlightMedium,
            ),
            const SizedBox(height: 11),
            _buildProbBar(
              'Bajo Riesgo',
              result.probBajo,
              accentColor: AppColors.riskLow,
              highlighted: highlightLow,
            ),
            const Divider(height: 24, color: AppColors.border),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: result.riesgoDesenlaceAdverso
                      ? AppColors.riskHigh.withValues(alpha: 0.28)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Desenlace Gestacional Estimado:',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          result.riesgoDesenlaceAdverso
                              ? 'Posible Complicación Obstétrica (${(result.probDesenlaceAdverso * 100).toStringAsFixed(1)}%)'
                              : 'Desenlace Normal / Estable (${(result.probDesenlaceAdverso * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: result.riesgoDesenlaceAdverso
                                ? AppColors.riskHigh
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbBar(
    String label,
    double probability, {
    required Color accentColor,
    required bool highlighted,
    double? threshold,
  }) {
    final percentage = (probability * 100).toStringAsFixed(1);
    final barColor = highlighted ? accentColor : const Color(0xFFCBD5E1);
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
                style: TextStyle(
                  fontSize: 12.5,
                  color: highlighted
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
                color: highlighted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: probability.clamp(0.0, 1.0),
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
