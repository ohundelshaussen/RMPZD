import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/consultation_code_generator.dart';

class ConsultationCodeBadge extends StatelessWidget {
  final String code;

  const ConsultationCodeBadge({required this.code, super.key});

  @override
  Widget build(BuildContext context) {
    final formatted = ConsultationCodeGenerator.format(code);

    return Tooltip(
      message: 'Copiar código de consulta',
      child: Material(
        color: AppColors.surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: formatted));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Código $formatted copiado.')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cód. $formatted',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.4,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.copy_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
