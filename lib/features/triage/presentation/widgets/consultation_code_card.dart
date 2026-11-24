import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/utils/consultation_code_generator.dart';
import '../../domain/entities/assessment_record.dart';
import '../../domain/usecases/regenerate_consultation_code_usecase.dart';

class ConsultationCodeCard extends StatefulWidget {
  final String? code;
  final String? recordUuid;
  final SyncStatus? syncStatus;
  final RegenerateConsultationCodeUseCase? regenerateUseCase;
  final bool adminMode;

  const ConsultationCodeCard({
    this.code,
    this.recordUuid,
    this.syncStatus,
    this.regenerateUseCase,
    this.adminMode = false,
    super.key,
  });

  @override
  State<ConsultationCodeCard> createState() => _ConsultationCodeCardState();
}

class _ConsultationCodeCardState extends State<ConsultationCodeCard> {
  String? _code;
  bool _isLoading = false;
  bool _isOnline = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _code = widget.code;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkConnection();
    });
  }

  Future<void> _checkConnection() async {
    try {
      final online = await context.read<ConnectivityService>().hasInternet();
      if (!mounted) return;
      setState(() => _isOnline = online);
    } catch (_) {
      if (mounted) setState(() => _isOnline = false);
    }
  }

  Future<void> _regenerate() async {
    if (widget.recordUuid == null || widget.regenerateUseCase == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generar nuevo código'),
        content: const Text(
          'El código anterior dejará de funcionar. Hágalo solo si se perdió '
          'o si cree que otra persona lo conoce. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });
    final result = await widget.regenerateUseCase!.execute(
      widget.recordUuid!,
      syncStatus: widget.syncStatus,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result is RegenerateConsultationCodeSuccess) {
      if (widget.adminMode) {
        await _showAdminCode(result.code);
      } else {
        setState(() => _code = result.code);
      }
    } else {
      setState(() => _message = _messageFor(result));
    }
  }

  Future<void> _showAdminCode(String code) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo código de consulta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              ConsultationCodeGenerator.format(code),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Entregue a la paciente su ID y este código.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: ConsultationCodeGenerator.format(code)),
              );
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(
                dialogContext,
              ).showSnackBar(const SnackBar(content: Text('Código copiado.')));
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _messageFor(RegenerateConsultationCodeResult result) {
    if (result is RegenerateConsultationCodeNotAuthorized) {
      return 'No está autorizado para generar este código.';
    }
    if (result is RegenerateConsultationCodeNotFound) {
      return 'No se encontró la evaluación.';
    }
    if (result is RegenerateConsultationCodeLimitReached) {
      return 'Alcanzó el límite de 5 cambios de código en 24 horas para este registro';
    }
    if (result is RegenerateConsultationCodeNoConnection) {
      return 'Requiere conexión a internet';
    }
    if (result is RegenerateConsultationCodeNotSynced) {
      return 'Sincronice primero';
    }
    return 'No se pudo generar un nuevo código. Intente nuevamente.';
  }

  @override
  Widget build(BuildContext context) {
    final notSynced =
        widget.syncStatus != null && widget.syncStatus != SyncStatus.synced;
    final disabled =
        _isLoading ||
        notSynced ||
        !_isOnline ||
        widget.recordUuid == null ||
        widget.regenerateUseCase == null;
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
            if (_code != null)
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      ConsultationCodeGenerator.format(_code!),
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
                          text: ConsultationCodeGenerator.format(_code!),
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
              )
            else if (!widget.adminMode)
              const Text(
                'Código no disponible en este dispositivo. Se generó en otro '
                'dispositivo o antes de reinstalar la app.',
              ),
            const SizedBox(height: 8),
            if (_code != null)
              const Text(
                'Entregue a la paciente su número de ID y este código para que '
                'consulte su resultado en la app. Anótelo ahora: por seguridad '
                'el servidor no puede mostrarlo de nuevo.',
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: disabled ? null : _regenerate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.autorenew_rounded),
              label: const Text('Generar nuevo código'),
            ),
            if (!_isOnline)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Requiere conexión a internet',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            else if (notSynced)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Sincronice primero',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            else if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _message!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
