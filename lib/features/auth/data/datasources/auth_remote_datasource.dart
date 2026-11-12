import 'package:supabase_flutter/supabase_flutter.dart';
import 'network_status_datasource.dart';

class AuthSessionChange {
  final bool signedIn;

  const AuthSessionChange({required this.signedIn});
}

class AuthRemoteDataSource {
  static const _profileColumns = 'id,email,full_name,role,active';

  final SupabaseClient? client;
  final NetworkStatusDataSource networkStatus;
  final String? initializationError;

  AuthRemoteDataSource({
    required this.client,
    required this.networkStatus,
    this.initializationError,
  });

  bool get hasCurrentSession => client?.auth.currentSession != null;

  String? get currentUserId => client?.auth.currentUser?.id;

  Stream<AuthSessionChange> get sessionChanges {
    final authClient = client;
    if (authClient == null) return const Stream.empty();
    return authClient.auth.onAuthStateChange.map(
      (state) => AuthSessionChange(signedIn: state.session != null),
    );
  }

  Stream<bool> get connectionChanges => networkStatus.connectionChanges;

  Future<bool> hasNetworkConnection() => networkStatus.hasConnection();

  Future<void> signIn(String email, String password) async {
    await _requireClient().auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final authClient = _requireClient();
    final userId = authClient.auth.currentUser?.id;
    if (userId == null) return null;

    final profile = await authClient
        .from('profiles')
        .select(_profileColumns)
        .eq('id', userId)
        .maybeSingle();
    return profile;
  }

  Future<void> signOut() async {
    await _requireClient().auth.signOut();
  }

  SupabaseClient _requireClient() {
    final authClient = client;
    if (authClient == null) {
      throw StateError(
        initializationError ??
            'Supabase no está disponible. Verifica la configuración local.',
      );
    }
    return authClient;
  }
}
