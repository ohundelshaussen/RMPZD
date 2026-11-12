import 'package:flutter/foundation.dart';

import '../../features/triage/data/datasources/assessment_local_datasource.dart';
import '../../features/triage/data/datasources/assessment_remote_datasource.dart';

@immutable
class SyncResult {
  final int enviados;
  final int fallidos;
  final int pendientes;
  final String? mensaje;

  const SyncResult({
    required this.enviados,
    required this.fallidos,
    required this.pendientes,
    this.mensaje,
  });
}

class SyncService {
  final AssessmentLocalDataSource localDataSource;
  final AssessmentRemoteDataSource remoteDataSource;
  final Future<bool> Function() hasInternet;
  final String? Function() currentOwnerId;
  final bool Function() hasSession;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncService({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.hasInternet,
    required this.currentOwnerId,
    required this.hasSession,
  });

  Future<SyncResult> syncPending() async {
    final ownerId = currentOwnerId();
    if (_isSyncing || !hasSession() || ownerId == null) {
      return SyncResult(
        enviados: 0,
        fallidos: 0,
        pendientes: ownerId == null
            ? 0
            : await localDataSource.getUnsyncedCount(ownerId),
      );
    }

    _isSyncing = true;
    var sent = 0;
    var failed = 0;
    String? message;
    try {
      if (!await hasInternet()) {
        return SyncResult(
          enviados: 0,
          fallidos: 0,
          pendientes: await localDataSource.getUnsyncedCount(ownerId),
          mensaje: 'Sin conexión a internet.',
        );
      }

      final pending = await localDataSource.getPendingAssessments(ownerId);
      for (var start = 0; start < pending.length; start += 50) {
        if (!_sessionMatches(ownerId)) {
          message = 'La sesión cambió; la sincronización se detuvo.';
          break;
        }
        final batch = pending.skip(start).take(50).toList();
        try {
          await remoteDataSource.upsertBatch(
            batch.map((model) => model.toRemoteJson()).toList(),
          );
          await localDataSource.markSynced(
            batch.map((model) => model.record.uuid).toList(),
          );
          sent += batch.length;
        } catch (error) {
          if (remoteDataSource.isNetworkFailure(error)) {
            await localDataSource.markPending(
              batch.map((model) => model.record.uuid).toList(),
            );
            message = 'Error de conexión durante la sincronización.';
            break;
          }
          if (!remoteDataSource.isClientFailure(error)) {
            await localDataSource.markPending(
              batch.map((model) => model.record.uuid).toList(),
            );
            message = _shortMessage(error);
            break;
          }

          var stopAfterNetworkError = false;
          for (var index = 0; index < batch.length; index++) {
            if (!_sessionMatches(ownerId)) {
              message = 'La sesión cambió; la sincronización se detuvo.';
              stopAfterNetworkError = true;
              break;
            }
            final item = batch[index];
            try {
              await remoteDataSource.upsertBatch([item.toRemoteJson()]);
              await localDataSource.markSynced([item.record.uuid]);
              sent++;
            } catch (itemError) {
              if (remoteDataSource.isNetworkFailure(itemError)) {
                final remaining = batch
                    .skip(index)
                    .map((model) => model.record.uuid)
                    .toList();
                await localDataSource.markPending(remaining);
                message = 'Error de conexión durante la sincronización.';
                stopAfterNetworkError = true;
                break;
              }
              if (!remoteDataSource.isClientFailure(itemError)) {
                final remaining = batch
                    .skip(index)
                    .map((model) => model.record.uuid)
                    .toList();
                await localDataSource.markPending(remaining);
                message = _shortMessage(itemError);
                stopAfterNetworkError = true;
                break;
              }
              await localDataSource.markError(
                item.record.uuid,
                _shortMessage(itemError),
              );
              failed++;
              message ??= 'Uno o más registros fueron rechazados.';
            }
          }
          if (stopAfterNetworkError) break;
        }
      }
    } finally {
      _isSyncing = false;
    }

    return SyncResult(
      enviados: sent,
      fallidos: failed,
      pendientes: await localDataSource.getUnsyncedCount(ownerId),
      mensaje: message,
    );
  }

  String _shortMessage(Object error) {
    final message = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return message.length <= 180 ? message : '${message.substring(0, 177)}...';
  }

  bool _sessionMatches(String ownerId) =>
      hasSession() && currentOwnerId() == ownerId;
}
