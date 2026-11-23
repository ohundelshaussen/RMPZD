import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../datasources/admin_users_remote_datasource.dart';

class AdminUsersRepositoryImpl implements AdminUsersRepository {
  final AdminUsersRemoteDataSource _remoteDataSource;

  const AdminUsersRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<UserProfile>> getUsers({String? searchQuery}) async {
    final rows = await _remoteDataSource.fetchUsers(searchQuery: searchQuery);
    return rows.map(UserProfile.fromJson).toList();
  }

  @override
  Future<UserProfile> updateUser({
    required String id,
    required String? fullName,
    required UserRole role,
    required bool active,
  }) async {
    final row = await _remoteDataSource.updateUser(
      id: id,
      fullName: fullName,
      role: role,
      active: active,
    );
    return UserProfile.fromJson(row);
  }

  @override
  Future<void> deleteUserProfile({required String id}) {
    return _remoteDataSource.deleteUserProfile(id: id);
  }
}
