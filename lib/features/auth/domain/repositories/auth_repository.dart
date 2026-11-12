import '../entities/user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile> signIn(String email, String password);
  Future<void> signOut();
  Future<UserProfile?> getCurrentProfile();
  Stream<UserProfile?> get sessionChanges;
}

class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}
