import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rmpzd/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:rmpzd/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:rmpzd/features/auth/data/datasources/network_status_datasource.dart';
import 'package:rmpzd/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:rmpzd/features/auth/domain/entities/user_profile.dart';
import 'package:rmpzd/features/auth/domain/repositories/auth_repository.dart';
import 'package:rmpzd/features/auth/domain/usecases/get_current_profile_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:rmpzd/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:rmpzd/features/auth/presentation/providers/auth_provider.dart';

void main() {
  const activeProfile = UserProfile(
    id: 'user-1',
    email: 'doctor@example.test',
    fullName: 'Doctora Ejemplo',
    role: UserRole.doctor,
    active: true,
  );

  group('UserProfile', () {
    test('parses valid profile fields and role', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'email': 'doctor@example.test',
        'full_name': 'Doctora Ejemplo',
        'role': 'doctor',
        'active': true,
      });

      expect(profile.toJson(), {
        'id': 'user-1',
        'email': 'doctor@example.test',
        'full_name': 'Doctora Ejemplo',
        'role': 'doctor',
        'active': true,
      });
    });

    test('rejects unknown roles', () {
      expect(
        () => UserProfile.fromJson({
          'id': 'user-1',
          'email': 'doctor@example.test',
          'full_name': 'Doctora Ejemplo',
          'role': 'operator',
          'active': true,
        }),
        throwsFormatException,
      );
    });

    test('accepts a null full_name and falls back to email for display', () {
      final profile = UserProfile.fromMap({
        'id': 'user-1',
        'email': 'clinica.norte@example.test',
        'full_name': null,
        'role': 'doctor',
        'active': true,
      });

      expect(profile.fullName, isNull);
      expect(profile.displayName, 'clinica.norte');
    });

    test('uses the email prefix when full_name is empty', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'email': 'doctor@example.test',
        'full_name': '  ',
        'role': 'doctor',
        'active': true,
      });

      expect(profile.displayName, 'doctor');
    });

    test('defaults active to true when omitted', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'email': 'doctor@example.test',
        'role': 'doctor',
      });

      expect(profile.active, isTrue);
    });

    test('rejects a non-boolean active value', () {
      expect(
        () => UserProfile.fromJson({
          'id': 'user-1',
          'email': 'doctor@example.test',
          'role': 'doctor',
          'active': 'true',
        }),
        throwsFormatException,
      );
    });
  });

  group('SignInUseCase', () {
    test('returns the profile from the repository', () async {
      final repository = _FakeAuthRepository(signInProfile: activeProfile);

      final result = await SignInUseCase(
        repository,
      ).execute('doctor@example.test', 'secret');

      expect(result, activeProfile);
      expect(repository.lastEmail, 'doctor@example.test');
      expect(repository.lastPassword, 'secret');
    });
  });

  test(
    'restores cached profile offline without requesting the remote profile',
    () async {
      final remote = _FakeRemoteDataSource(
        connected: false,
        session: true,
        userId: activeProfile.id,
      );
      final local = _FakeLocalDataSource(activeProfile);
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
      );

      expect(await repository.getCurrentProfile(), activeProfile);
      expect(remote.profileRequestCount, 0);
    },
  );

  test(
    'refreshes the cached profile after a session event when online',
    () async {
      final remote = _FakeRemoteDataSource(
        connected: true,
        session: true,
        userId: activeProfile.id,
        serverProfile: {
          'id': activeProfile.id,
          'email': activeProfile.email,
          'full_name': 'Nombre actualizado',
          'role': activeProfile.role.name,
          'active': true,
        },
      );
      final local = _FakeLocalDataSource(activeProfile);
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
      );
      final refreshedProfile = Completer<UserProfile>();
      final subscription = repository.sessionChanges.listen((profile) {
        if (profile?.fullName == 'Nombre actualizado' &&
            !refreshedProfile.isCompleted) {
          refreshedProfile.complete(profile);
        }
      });

      remote.emitSignedIn();
      final result = await refreshedProfile.future.timeout(
        const Duration(seconds: 1),
      );

      expect(result.fullName, 'Nombre actualizado');
      expect(local.cachedProfile?.fullName, 'Nombre actualizado');
      expect(remote.profileRequestCount, 1);
      await subscription.cancel();
      await remote.close();
    },
  );

  group('AuthProvider', () {
    test('authenticates after successful sign in', () async {
      final repository = _FakeAuthRepository(signInProfile: activeProfile);
      final provider = _authProvider(repository);
      addTearDown(provider.dispose);

      expect(await provider.signIn('doctor@example.test', 'secret'), isTrue);
      expect(provider.status, AuthStatus.authenticated);
      expect(provider.profile, activeProfile);
      expect(provider.errorMessage, isNull);
    });

    test('exposes a sign in failure and remains unauthenticated', () async {
      final repository = _FakeAuthRepository(
        signInError: const AuthFailure(
          'El correo o la contraseña son incorrectos.',
        ),
      );
      final provider = _authProvider(repository);
      addTearDown(provider.dispose);

      expect(await provider.signIn('doctor@example.test', 'wrong'), isFalse);
      expect(provider.status, AuthStatus.unauthenticated);
      expect(
        provider.errorMessage,
        'El correo o la contraseña son incorrectos.',
      );
    });

    test(
      'restores a cached profile when the session is restored offline',
      () async {
        final repository = _FakeAuthRepository(cachedProfile: activeProfile);
        final provider = _authProvider(repository);
        addTearDown(provider.dispose);

        await provider.restoreSession();

        expect(provider.status, AuthStatus.authenticated);
        expect(provider.profile, activeProfile);
      },
    );

    test('does not authenticate a disabled cached profile', () async {
      final repository = _FakeAuthRepository(
        cachedProfile: const UserProfile(
          id: 'user-1',
          email: 'doctor@example.test',
          fullName: 'Doctora Ejemplo',
          role: UserRole.doctor,
          active: false,
        ),
      );
      final provider = _authProvider(repository);
      addTearDown(provider.dispose);

      await provider.restoreSession();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.profile, isNull);
    });
  });
}

AuthProvider _authProvider(_FakeAuthRepository repository) => AuthProvider(
  signInUseCase: SignInUseCase(repository),
  signOutUseCase: SignOutUseCase(repository),
  getCurrentProfileUseCase: GetCurrentProfileUseCase(repository),
  repository: repository,
);

class _FakeAuthRepository implements AuthRepository {
  final UserProfile? signInProfile;
  final UserProfile? cachedProfile;
  final Object? signInError;

  _FakeAuthRepository({
    this.signInProfile,
    this.cachedProfile,
    this.signInError,
  });

  String? lastEmail;
  String? lastPassword;

  @override
  Future<UserProfile?> getCurrentProfile() async => cachedProfile;

  @override
  Stream<UserProfile?> get sessionChanges => const Stream.empty();

  @override
  Future<UserProfile> signIn(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
    if (signInError case final error?) throw error;
    if (signInProfile case final profile?) return profile;
    throw StateError('No sign in profile configured.');
  }

  @override
  Future<void> signOut() async {}
}

class _FakeRemoteDataSource implements AuthRemoteDataSource {
  final bool connected;
  final bool session;
  final String? userId;
  final Map<String, dynamic>? serverProfile;
  int profileRequestCount = 0;
  final StreamController<AuthSessionChange> _sessionController =
      StreamController<AuthSessionChange>.broadcast();

  _FakeRemoteDataSource({
    required this.connected,
    required this.session,
    this.userId,
    this.serverProfile,
  });

  @override
  SupabaseClient? get client => null;

  @override
  String? get initializationError => null;

  @override
  NetworkStatusDataSource get networkStatus => throw UnimplementedError();

  @override
  bool get hasCurrentSession => session;

  @override
  String? get currentUserId => userId;

  @override
  Stream<AuthSessionChange> get sessionChanges => _sessionController.stream;

  @override
  Stream<bool> get connectionChanges => const Stream.empty();

  @override
  Future<bool> hasNetworkConnection() async => connected;

  @override
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    profileRequestCount++;
    return serverProfile;
  }

  void emitSignedIn() =>
      _sessionController.add(const AuthSessionChange(signedIn: true));

  Future<void> close() => _sessionController.close();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeLocalDataSource implements AuthLocalDataSource {
  UserProfile? cachedProfile;

  _FakeLocalDataSource(this.cachedProfile);

  @override
  SharedPreferences get preferences => throw UnimplementedError();

  @override
  Future<UserProfile?> getCachedProfile() async => cachedProfile;

  @override
  Future<void> cacheProfile(UserProfile profile) async {
    cachedProfile = profile;
  }

  @override
  Future<void> clearProfile() async {}
}
