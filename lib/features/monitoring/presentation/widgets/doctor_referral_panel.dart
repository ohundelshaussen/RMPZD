import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../triage/domain/entities/assessment_record.dart';
import '../../domain/entities/doctor_monitoring_case.dart';
import '../providers/doctor_referral_provider.dart';

class DoctorReferralPanel extends StatefulWidget {
  final AssessmentRecord record;
  final bool compact;
  final bool automaticAlert;

  const DoctorReferralPanel({
    required this.record,
    this.compact = false,
    this.automaticAlert = false,
    super.key,
  });

  @override
  State<DoctorReferralPanel> createState() => _DoctorReferralPanelState();
}

class _DoctorReferralPanelState extends State<DoctorReferralPanel> {
  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didUpdateWidget(covariant DoctorReferralPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.uuid != widget.record.uuid ||
        oldWidget.record.syncStatus != widget.record.syncStatus) {
      _loadStatus();
    }
  }

  void _loadStatus() {
    if (!widget.record.isSynced) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DoctorReferralProvider?>()?.loadStatuses([
          widget.record.uuid,
        ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorReferralProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final status = provider.caseFor(widget.record.uuid);
    if (widget.compact) {
      if (status == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _caseStatus(status),
      );
    }

    if (widget.automaticAlert) {
      return _automaticAlert(status);
    }

    if (status?.isOpen ?? false) {
      return _caseStatus(status!);
    }

    return _referralAction(provider, status);
  }

  Widget _automaticAlert(DoctorMonitoringCase? status) {
    final isSynced = widget.record.isSynced;
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSynced
                  ? 'Alerta enviada al monitor'
                  : 'Alerta automática al sincronizar',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (!isSynced)
              const Text('La alerta se enviará al sincronizar la evaluación.')
            else if (status != null)
              _automaticCaseStatus(status)
            else
              const Text('Consultando el estado de la alerta…'),
          ],
        ),
      ),
    );
  }

  Widget _automaticCaseStatus(DoctorMonitoringCase status) {
    final label = status.isClosed
        ? 'Cerrada: ${DoctorReferralProvider.closedResultLabel(status.result)}'
        : status.state == 'en_gestion'
        ? 'En gestión por un monitor'
        : 'En espera de un monitor';
    return Text(label);
  }

  Widget _referralAction(
    DoctorReferralProvider provider,
    DoctorMonitoringCase? status,
  ) {
    final closed = status?.isClosed ?? false;
    final isPending = !widget.record.isSynced;
    final isLoading = provider.isStatusLoading(widget.record.uuid);
    final isRemitting = provider.isRemitting(widget.record.uuid);
    final disabled =
        isPending || !provider.hasInternet || isLoading || isRemitting;
    final buttonLabel = isPending
        ? 'Sincronice primero'
        : isLoading
        ? 'Consultando estado…'
        : isRemitting
        ? 'Enviando remisión…'
        : !provider.hasInternet
        ? 'Requiere conexión a internet'
        : closed
        ? 'Volver a remitir'
        : 'Remitir al monitor';

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (closed) ...[
              _caseStatus(status!),
              const SizedBox(height: 10),
            ] else ...[
              const Text(
                '¿Desea remitir a la paciente al monitor?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              if (!provider.hasCheckedStatus(widget.record.uuid) &&
                  !isLoading &&
                  widget.record.isSynced)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text('Se consultará el estado actual del caso.'),
                ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: disabled ? null : () => _confirmReferral(provider),
              icon: isRemitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.forward_to_inbox_outlined),
              label: Text(buttonLabel),
            ),
            if (provider.statusErrorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  provider.statusErrorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _caseStatus(DoctorMonitoringCase status) {
    if (status.isClosed) {
      return Text(
        'Cerrada: ${DoctorReferralProvider.closedResultLabel(status.result)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      );
    }
    final label = status.state == 'en_gestion'
        ? 'Remitida · en gestión'
        : 'Remitida · en espera';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monitor_heart_outlined, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReferral(DoctorReferralProvider provider) async {
    final motive = await showDialog<String>(
      context: context,
      builder: (_) => const _DoctorReferralDialog(),
    );
    if (motive == null || !mounted) return;

    try {
      final result = await provider.submitReferral(
        assessmentId: widget.record.uuid,
        motive: motive,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorReferralProvider.messageFor(result))),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo remitir la evaluación. Intente de nuevo.'),
        ),
      );
    }
  }
}

class DoctorReferralPendingPanel extends StatelessWidget {
  final bool automaticAlert;

  const DoctorReferralPendingPanel({this.automaticAlert = false, super.key});

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            automaticAlert
                ? 'La alerta se enviará al monitor al sincronizar la evaluación.'
                : '¿Desea remitir a la paciente al monitor?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (!automaticAlert) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.forward_to_inbox_outlined),
              label: const Text('Sincronice primero'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _DoctorReferralDialog extends StatefulWidget {
  const _DoctorReferralDialog();

  @override
  State<_DoctorReferralDialog> createState() => _DoctorReferralDialogState();
}

class _DoctorReferralDialogState extends State<_DoctorReferralDialog> {
  final _motiveController = TextEditingController();

  @override
  void dispose() {
    _motiveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Remitir al monitor'),
    content: TextField(
      controller: _motiveController,
      maxLength: 500,
      maxLines: 3,
      inputFormatters: [LengthLimitingTextInputFormatter(500)],
      decoration: const InputDecoration(
        labelText: 'Motivo (opcional)',
        alignLabelWithHint: true,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _motiveController.text.trim()),
        child: const Text('Confirmar'),
      ),
    ],
  );
}
