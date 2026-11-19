import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/consultation_code_generator.dart';

class ConsultationCodeCard extends StatelessWidget {
  final String code;

  const ConsultationCodeCard({required this.code, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE0F2F1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Código de consulta de la paciente',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    ConsultationCodeGenerator.format(code),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar código',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: ConsultationCodeGenerator.format(code),
                      ),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Entregue a la paciente su número de ID y este código para que '
              'consulte su resultado en la app. Anótelo ahora: por seguridad '
              'el servidor no puede mostrarlo de nuevo.',
            ),
          ],
        ),
      ),
    );
  }
}
