import 'dart:async';
import 'dart:io';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<UserProfile> signIn(String email, String password) async {
    if (!await remoteDataSource.hasNetworkConnection()) {
      throw const AuthFailure(
        'Se necesita conexión a internet para iniciar sesión por primera vez.',
      );
    }

    try {
      await remoteDataSource.signIn(email, password);
      final profileMap = await remoteDataSource.getCurrentProfile();
      if (profileMap == null) {
        await remoteDataSource.signOut();
        throw const AuthFailure(
          'No se encontró un perfil asociado a esta cuenta.',
        );
      }

      final profile = UserProfile.fromJson(profileMap);
      if (!profile.active) {
        await remoteDataSource.signOut();
        await localDataSource.clearProfile();
        throw const AuthFailure('Esta cuenta está desactivada.');
      }

      await localDataSource.cacheProfile(profile);
      return profile;
    } catch (error) {
      if (error is AuthFailure) rethrow;
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await remoteDataSource.signOut();
      await localDataSource.clearProfile();
    } catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<UserProfile?> getCurrentProfile() async {
    if (!remoteDataSource.hasCurrentSession) return null;

    final cachedProfile = await localDataSource.getCachedProfile();
    if (cachedProfile == null ||
        cachedProfile.id != remoteDataSource.currentUserId) {
      return null;
    }

    return cachedProfile;
  }

  @override
  Stream<UserProfile?> get sessionChanges {
    return Stream<UserProfile?>.multi((controller) {
      Future<void> publishProfile() async {
        try {
          final cachedProfile = await getCurrentProfile();
          controller.add(cachedProfile);
          if (cachedProfile == null ||
              !await remoteDataSource.hasNetworkConnection()) {
            return;
          }

          try {
            final profileMap = await remoteDataSource.getCurrentProfile();
            if (profileMap == null) {
              await _clearSession();
              controller.add(null);
              return;
            }

            final profile = UserProfile.fromJson(profileMap);
            if (!profile.active) {
              await _clearSession();
              controller.add(null);
              return;
            }

            await localDataSource.cacheProfile(profile);
            controller.add(profile);
          } catch (error, stackTrace) {
            if (!_isNetworkFailure(error)) {
              controller.addError(_mapFailure(error), stackTrace);
            }
          }
        } catch (error, stackTrace) {
          controller.addError(_mapFailure(error), stackTrace);
        }
      }

      Future<void> publishSignedOut() async {
        try {
          await localDataSource.clearProfile();
          controller.add(null);
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }
      }

      final authSubscription = remoteDataSource.sessionChanges.listen((change) {
        if (change.signedIn) {
          unawaited(publishProfile());
        } else {
          unawaited(publishSignedOut());
        }
      }, onError: controller.addError);
      final connectionSubscription = remoteDataSource.connectionChanges.listen((
        connected,
      ) {
        if (connected && remoteDataSource.hasCurrentSession) {
          unawaited(publishProfile());
        }
      }, onError: controller.addError);

      controller.onCancel = () async {
        await authSubscription.cancel();
        await connectionSubscription.cancel();
      };
    });
  }

  Future<void> _clearSession() async {
    await remoteDataSource.signOut();
    await localDataSource.clearProfile();
  }

  AuthFailure _mapFailure(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('invalid_credentials') ||
        message.contains('invalid login credentials') ||
        message.contains('invalid_grant')) {
      return const AuthFailure('El correo o la contraseña son incorrectos.');
    }
    if (_isNetworkFailure(error)) {
      return const AuthFailure(
        'No hay conexión a internet. Inténtalo cuando tengas conexión.',
      );
    }
    if (message.contains('desactivada')) {
      return const AuthFailure('Esta cuenta está desactivada.');
    }
    return AuthFailure('No se pudo completar la autenticación: $error');
  }

  bool _isNetworkFailure(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('timed out') ||
        message.contains('clientexception');
  }
}
