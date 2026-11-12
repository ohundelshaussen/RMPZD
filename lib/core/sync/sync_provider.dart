import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/triage/domain/usecases/get_unsynced_count_usecase.dart';
import '../network/connectivity_service.dart';
import 'sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService? syncService;
  final ConnectivityService? connectivityService;
  final AuthProvider? authProvider;
  final GetUnsyncedCountUseCase? getUnsyncedCount;
  final Future<void> Function()? onSyncComplete;

  StreamSubscription<bool>? _connectivitySubscription;
  final bool _disabled;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _hasError = false;
  bool get hasError => _hasError;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  DateTime? _lastSuccessfulSync;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;

  String? _lastMessage;
  String? get lastMessage => _lastMessage;

  SyncProvider({
    required this.syncService,
    required this.connectivityService,
    required this.authProvider,
    required this.getUnsyncedCount,
    this.onSyncComplete,
  }) : _disabled = false {
    final auth = authProvider!;
    auth.addListener(_onAuthChanged);
    _connectivitySubscription = connectivityService!.connectionChanges.listen((
      connected,
    ) {
      if (connected && auth.profile != null) {
        unawaited(syncNow());
      }
    });
    if (auth.profile != null) unawaited(syncNow());
  }

  SyncProvider.disabled()
    : syncService = null,
      connectivityService = null,
      authProvider = null,
      getUnsyncedCount = null,
      onSyncComplete = null,
      _disabled = true;

  Future<void> syncNow() async {
    if (_disabled) return;
    if (_isSyncing) return;
    final profile = authProvider!.profile;
    if (profile == null) {
      _pendingCount = 0;
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();
    try {
      final result = await syncService!.syncPending();
      _pendingCount = result.pendientes;
      _hasError =
          result.fallidos > 0 ||
          result.mensaje != null &&
              result.mensaje != 'Sin conexión a internet.';
      _lastMessage = result.mensaje;
      if (!_hasError && result.pendientes == 0) {
        _lastSuccessfulSync = DateTime.now();
      }
    } catch (error) {
      _hasError = true;
      _lastMessage = 'Error al sincronizar: $error';
      try {
        _pendingCount = await getUnsyncedCount!.execute(ownerId: profile.id);
      } catch (countError) {
        _lastMessage = 'Error al consultar pendientes: $countError';
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    final syncComplete = onSyncComplete;
    if (syncComplete != null) await syncComplete();
  }

  void _onAuthChanged() {
    if (authProvider!.profile == null) {
      _pendingCount = 0;
      _hasError = false;
      _lastMessage = null;
      notifyListeners();
      return;
    }
    unawaited(_refreshPendingAndSync());
  }

  Future<void> _refreshPendingAndSync() async {
    final ownerId = authProvider!.profile?.id;
    if (ownerId == null) return;
    try {
      _pendingCount = await getUnsyncedCount!.execute(ownerId: ownerId);
      notifyListeners();
      await syncNow();
    } catch (error) {
      _hasError = true;
      _lastMessage = 'Error al consultar pendientes: $error';
      notifyListeners();
    }
  }

  Future<void> refreshPendingCount() async {
    if (_disabled) return;
    final ownerId = authProvider!.profile?.id;
    _pendingCount = ownerId == null
        ? 0
        : await getUnsyncedCount!.execute(ownerId: ownerId);
    notifyListeners();
  }

  @override
  void dispose() {
    authProvider?.removeListener(_onAuthChanged);
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
