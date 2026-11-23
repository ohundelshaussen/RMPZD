import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/network/connectivity_service.dart';
import '../../../admin_records/domain/repositories/admin_records_repository.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/repositories/admin_users_repository.dart';

enum AdminUsersFilter { all, doctors, admins, inactive }

class AdminUsersProvider extends ChangeNotifier {
  final AdminUsersRepository repository;
  final ConnectivityService connectivityService;
  final String? Function() currentUserId;

  AdminUsersProvider({
    required this.repository,
    required this.connectivityService,
    required this.currentUserId,
  });

  final List<UserProfile> _users = [];
  List<UserProfile> get users => List.unmodifiable(_users);

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  AdminUsersFilter _filter = AdminUsersFilter.all;
  AdminUsersFilter get filter => _filter;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isMutating = false;
  bool get isMutating => _isMutating;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<UserProfile> get filteredUsers {
    return _users.where((user) {
      return switch (_filter) {
        AdminUsersFilter.all => true,
        AdminUsersFilter.doctors => user.role == UserRole.doctor,
        AdminUsersFilter.admins => user.role == UserRole.admin,
        AdminUsersFilter.inactive => !user.active,
      };
    }).toList(growable: false);
  }

  Future<void> loadUsers({String? searchQuery}) async {
    if (searchQuery != null) {
      _searchQuery = searchQuery;
    }
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    _isOffline = false;
    notifyListeners();

    try {
      if (!await connectivityService.hasInternet()) {
        _isOffline = true;
        _errorMessage =
            'Sin conexión a internet. Conéctate y vuelve a intentar.';
        return;
      }
      final fetched = await repository.getUsers(searchQuery: _searchQuery);
      _users
        ..clear()
        ..addAll(fetched);
      _errorMessage = null;
      _isOffline = false;
    } catch (error) {
      _isOffline = error is SocketException || error is TimeoutException;
      _errorMessage = _isOffline
          ? 'Sin conexión a internet. Conéctate y vuelve a intentar.'
          : 'No se pudieron cargar los usuarios: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(AdminUsersFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  Future<({bool success, String message})> updateUser({
    required UserProfile user,
    required String? fullName,
    required UserRole role,
    required bool active,
  }) async {
    final activeAdminId = currentUserId();
    if (activeAdminId != null && user.id == activeAdminId) {
      if (!active) {
        return (
          success: false,
          message: 'No puedes desactivar tu propia cuenta activa.',
        );
      }
      if (role != user.role) {
        return (
          success: false,
          message: 'No puedes cambiar tu propio rol mientras estás conectado.',
        );
      }
    }

    _isMutating = true;
    notifyListeners();
    try {
      if (!await connectivityService.hasInternet()) {
        return (
          success: false,
          message: 'Sin conexión a internet. Conéctate e intenta de nuevo.',
        );
      }
      final updated = await repository.updateUser(
        id: user.id,
        fullName: fullName,
        role: role,
        active: active,
      );
      final index = _users.indexWhere((item) => item.id == user.id);
      if (index != -1) {
        _users[index] = updated;
      }
      return (success: true, message: 'Perfil actualizado correctamente.');
    } on AdminPermissionException catch (error) {
      return (success: false, message: error.message);
    } catch (error) {
      if (error is SocketException || error is TimeoutException) {
        return (
          success: false,
          message: 'Sin conexión a internet. Conéctate e intenta de nuevo.',
        );
      }
      return (
        success: false,
        message: 'No se pudo actualizar el usuario: $error',
      );
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<({bool success, String message})> deleteUser(UserProfile user) async {
    final activeAdminId = currentUserId();
    if (activeAdminId != null && user.id == activeAdminId) {
      return (
        success: false,
        message: 'No puedes eliminar tu propia cuenta mientras tienes sesión iniciada.',
      );
    }

    _isMutating = true;
    notifyListeners();
    try {
      if (!await connectivityService.hasInternet()) {
        return (
          success: false,
          message: 'Sin conexión a internet. Conéctate e intenta de nuevo.',
        );
      }
      await repository.deleteUserProfile(id: user.id);
      _users.removeWhere((item) => item.id == user.id);
      return (success: true, message: 'Perfil eliminado correctamente.');
    } on AdminPermissionException catch (error) {
      return (success: false, message: error.message);
    } catch (error) {
      if (error is SocketException || error is TimeoutException) {
        return (
          success: false,
          message: 'Sin conexión a internet. Conéctate e intenta de nuevo.',
        );
      }
      return (
        success: false,
        message: 'No se pudo eliminar el perfil: $error',
      );
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }
}
