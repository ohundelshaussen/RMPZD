import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AcademicDashboardPage extends StatelessWidget {
  const AcademicDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría y Métricas IA (Fase 2)'),
      ),
      body: const AcademicDashboardBody(),
    );
  }
}

class AcademicDashboardBody extends StatelessWidget {
  const AcademicDashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Proyecto de Aula • Inteligencia Artificial',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Evaluación Cuantitativa y Auditoría Étnica',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Métricas obtenidas sobre el conjunto de prueba independiente (n = 227) con ajuste de umbrales para clases desbalanceadas.',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tarjetas de Métricas Clave
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Dataset Clínico',
                    '1.508',
                    'Registros (17 predictoras)',
                    Icons.dataset_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    'Recall Alto (MLP)',
                    '60,87%',
                    'Umbral ajustado a 0.25',
                    Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'F1-macro MLP',
                    '0,5230',
                    'Mejor modelo multiclase',
                    Icons.auto_graph_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    'Sensibilidad Adv.',
                    '100%',
                    'Reg. Logística (umbral 0.30)',
                    Icons.health_and_safety_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tabla Comparativa de Modelos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comparación de Modelos de Nivel de Riesgo (Test)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Table(
                      border: TableBorder.all(color: AppColors.border),
                      columnWidths: const {
                        0: FlexColumnWidth(2.0),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                      },
                      children: [
                        _buildTableHeader(['Modelo', 'Accuracy', 'F1-macro', 'Recall Alto']),
                        _buildTableRow(['Dummy (ref)', '67,84%', '0,2695', '0,0%']),
                        _buildTableRow(['Reg. Logística', '60,35%', '0,4760', '56,52%']),
                        _buildTableRow(['SVM RBF', '60,35%', '0,4600', '30,43%']),
                        _buildTableRow(['Red MLP (0.25)', '60,79%', '0,4678', '60,87%'], isHighlight: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '* Nota: Aunque el Dummy obtiene mayor accuracy (67,84%) por predecir siempre "Bajo", falla en el 100% de los casos de riesgo Alto. El F1-macro y Recall son las métricas representativas.',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Auditoría Étnica y Territorial
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auditoría por Subgrupos (Enfoque Étnico)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    _buildSubgroupBar('Comunidad No Indígena (Recall)', 0.6154, '8/13 detectados (61,54%)'),
                    const SizedBox(height: 8),
                    _buildSubgroupBar('Población Indígena Wayuu (Recall)', 0.3750, '3/8 detectados (37,50%)'),
                    const SizedBox(height: 10),
                    const Text(
                      'Diferencia descriptiva asociada a tamaño muestral sintético reducido (n=8 Wayuu en test). Justifica la incorporación del motor de reglas obstétricas inflexibles para evitar sesgos.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
        ],
      ),
    );
  }

  static TableRow _buildTableHeader(List<String> titles) {
    return TableRow(
      decoration: const BoxDecoration(color: AppColors.surfaceVariant),
      children: titles
          .map((t) => Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  t,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ))
          .toList(),
    );
  }

  static TableRow _buildTableRow(List<String> values, {bool isHighlight = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
      ),
      children: values
          .map((v) => Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  v,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                    color: isHighlight ? AppColors.primaryDark : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Icon(icon, size: 16, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSubgroupBar(String label, double ratio, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
            Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              ratio >= 0.5 ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
