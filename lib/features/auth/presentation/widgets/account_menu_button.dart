import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/sync/sync_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../triage/domain/usecases/get_unsynced_count_usecase.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/auth_provider.dart';

class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key});

  Future<void> _signOut(BuildContext context) async {
    final syncProvider = context.read<SyncProvider?>();
    if (syncProvider != null && syncProvider.isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Espera a que termine la sincronización para cerrar sesión.',
          ),
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider?>();
    final profile = authProvider?.profile;
    if (authProvider == null || profile == null) return;

    int pendingCount = 0;
    final getUnsyncedCount = context.read<GetUnsyncedCountUseCase?>();
    final historyProvider = context.read<HistoryProvider?>();
    try {
      if (getUnsyncedCount != null) {
        pendingCount = await getUnsyncedCount.execute(ownerId: profile.id);
      } else if (historyProvider != null) {
        pendingCount = historyProvider.unsyncedCount;
      } else if (syncProvider != null) {
        pendingCount = syncProvider.pendingCount;
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron consultar los registros pendientes: $error',
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;

    if (pendingCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Registros pendientes'),
          content: Text(
            'Hay $pendingCount registros pendientes. Se sincronizarán cuando '
            'este usuario vuelva a iniciar sesión con internet. La base local '
            'se conservará en este dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    try {
      await authProvider.signOut();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar sesión: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider?>()?.profile;
    if (profile == null) return const SizedBox.shrink();

    return PopupMenuButton<_AccountAction>(
      tooltip: 'Cuenta de usuario',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (action) {
        if (action == _AccountAction.signOut) _signOut(context);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            '${profile.displayName}\n${profile.role.label}',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountAction.signOut,
          child: Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

enum _AccountAction { signOut }
