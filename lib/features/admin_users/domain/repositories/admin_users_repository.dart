import '../../../auth/domain/entities/user_profile.dart';

abstract interface class AdminUsersRepository {
  Future<List<UserProfile>> getUsers({String? searchQuery});

  Future<UserProfile> updateUser({
    required String id,
    required String? fullName,
    required UserRole role,
    required bool active,
  });

  Future<void> deleteUserProfile({required String id});
}
