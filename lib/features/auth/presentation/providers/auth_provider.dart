import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_profile_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';

enum AuthStatus { loading, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  final SignInUseCase signInUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentProfileUseCase getCurrentProfileUseCase;
  final AuthRepository repository;

  AuthProvider({
    required this.signInUseCase,
    required this.signOutUseCase,
    required this.getCurrentProfileUseCase,
    required this.repository,
  }) {
    _sessionSubscription = repository.sessionChanges.listen(
      _setProfile,
      onError: (Object error) {
        _errorMessage = _messageFor(error);
        notifyListeners();
      },
    );
  }

  late final StreamSubscription<UserProfile?> _sessionSubscription;
  AuthStatus _status = AuthStatus.loading;
  AuthStatus get status => _status;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> restoreSession() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _setProfile(await getCurrentProfileUseCase.execute());
    } catch (error) {
      _profile = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = _messageFor(error);
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _setProfile(await signInUseCase.execute(email.trim(), password));
      return true;
    } catch (error) {
      _profile = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signInOffline({bool asAdmin = false}) async {
    final demoProfile = UserProfile(
      id: asAdmin ? 'admin-offline' : 'doctor-offline',
      email: asAdmin ? 'admin@rmpzd.local' : 'medico@rmpzd.local',
      fullName: asAdmin
          ? 'Administrador Obstétrico (Demo)'
          : 'Médico / Promotor de Salud (Offline)',
      role: asAdmin ? UserRole.admin : UserRole.doctor,
      active: true,
    );
    _setProfile(demoProfile);
  }

  Future<void> signOut() async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await signOutUseCase.execute();
      _setProfile(null);
    } catch (error) {
      _errorMessage = _messageFor(error);
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _setProfile(UserProfile? profile) {
    _profile = profile != null && profile.active ? profile : null;
    _status = _profile == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
    _errorMessage = null;
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is AuthFailure) return error.message;
    return 'Ocurrió un error de autenticación: $error';
  }

  @override
  void dispose() {
    _sessionSubscription.cancel();
    super.dispose();
  }
}
