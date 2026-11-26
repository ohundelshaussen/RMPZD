import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/monitoring_case.dart';
import '../providers/monitoring_provider.dart';

class MonitoringCaseDetailPage extends StatefulWidget {
  final String caseId;

  const MonitoringCaseDetailPage({required this.caseId, super.key});

  @override
  State<MonitoringCaseDetailPage> createState() =>
      _MonitoringCaseDetailPageState();
}

class _MonitoringCaseDetailPageState extends State<MonitoringCaseDetailPage> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCase());
  }

  Future<void> _loadCase() async {
    final provider = context.read<MonitoringProvider?>();
    if (provider == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar el detalle del caso.';
      });
      return;
    }
    try {
      final item = await provider.refreshCase(widget.caseId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (item == null) _errorMessage = 'No se encontró el caso.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar el detalle del caso.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle del caso')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
        ? Center(child: Text(_errorMessage!))
        : Consumer<MonitoringProvider>(
            builder: (context, provider, _) {
              final item = provider.caseById(widget.caseId);
              if (item == null) {
                return const Center(child: Text('No se encontró el caso.'));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(switch (item.priority) {
                    MonitoringPriority.critica => 'Prioridad crítica',
                    MonitoringPriority.alta => 'Alto riesgo',
                    MonitoringPriority.media => 'Remitido por el doctor',
                  }, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Estado', value: item.status.value),
                  _DetailRow(
                    label: 'Ubicación',
                    value: [
                      item.municipality ?? 'Municipio no disponible',
                      item.department ?? 'Departamento no disponible',
                    ].join(', '),
                  ),
                  _DetailRow(
                    label: 'Origen',
                    value: item.origin == 'remision_doctor'
                        ? 'Remisión del doctor'
                        : 'Alerta automática',
                  ),
                  if (item.referredByName != null)
                    _DetailRow(
                      label: 'Doctor que remitió',
                      value: item.referredByName!,
                    ),
                  if (item.referralReason != null)
                    _DetailRow(
                      label: 'Motivo de remisión',
                      value: item.referralReason!,
                    ),
                  if (item.result != null)
                    _DetailRow(label: 'Resultado', value: item.result!),
                ],
              );
            },
          ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
