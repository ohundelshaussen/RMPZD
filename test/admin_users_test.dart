import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/core/network/connectivity_service.dart';
import 'package:rmpzd/features/admin_records/domain/repositories/admin_records_repository.dart';
import 'package:rmpzd/features/admin_users/data/datasources/admin_users_remote_datasource.dart';
import 'package:rmpzd/features/admin_users/data/repositories/admin_users_repository_impl.dart';
import 'package:rmpzd/features/admin_users/presentation/pages/admin_users_page.dart';
import 'package:rmpzd/features/admin_users/presentation/providers/admin_users_provider.dart';
import 'package:rmpzd/features/auth/domain/entities/user_profile.dart';

void main() {
  group('AdminUsersProvider', () {
    test('loads, filters, updates and deletes users with self-protection', () async {
      final remote = _FakeAdminUsersRemoteDataSource([
        const UserProfile(
          id: 'admin-1',
          email: 'admin@rmpzd.test',
          fullName: 'Admin Principal',
          role: UserRole.admin,
          active: true,
        ).toJson(),
        const UserProfile(
          id: 'doc-1',
          email: 'doc1@rmpzd.test',
          fullName: 'Dra. Wayuu',
          role: UserRole.doctor,
          active: true,
        ).toJson(),
        const UserProfile(
          id: 'doc-2',
          email: 'doc2@rmpzd.test',
          fullName: 'Dr. Inactivo',
          role: UserRole.doctor,
          active: false,
        ).toJson(),
      ]);
      final provider = AdminUsersProvider(
        repository: AdminUsersRepositoryImpl(remote),
        connectivityService: _FakeConnectivity(true),
        currentUserId: () => 'admin-1',
      );

      await provider.loadUsers();
      expect(provider.filteredUsers, hasLength(3));

      provider.setFilter(AdminUsersFilter.doctors);
      expect(provider.filteredUsers.map((u) => u.id), ['doc-1', 'doc-2']);

      provider.setFilter(AdminUsersFilter.inactive);
      expect(provider.filteredUsers.map((u) => u.id), ['doc-2']);

      provider.setFilter(AdminUsersFilter.all);

      final selfDeactivate = await provider.updateUser(
        user: provider.users.first,
        fullName: 'Admin Principal',
        role: UserRole.admin,
        active: false,
      );
      expect(selfDeactivate.success, isFalse);

      final selfDelete = await provider.deleteUser(provider.users.first);
      expect(selfDelete.success, isFalse);

      final docUpdate = await provider.updateUser(
        user: provider.users[1],
        fullName: 'Dra. Actualizada',
        role: UserRole.admin,
        active: false,
      );
      expect(docUpdate.success, isTrue);
      expect(provider.users[1].fullName, 'Dra. Actualizada');
      expect(provider.users[1].role, UserRole.admin);
      expect(provider.users[1].active, isFalse);

      remote.permissionDenied = true;
      final rlsDelete = await provider.deleteUser(provider.users[2]);
      expect(rlsDelete.success, isFalse);
      expect(rlsDelete.message, contains('RLS'));

      remote.permissionDenied = false;
      final okDelete = await provider.deleteUser(provider.users[2]);
      expect(okDelete.success, isTrue);
      expect(provider.users.map((u) => u.id), ['admin-1', 'doc-1']);
    });

    testWidgets('AdminUsersPage renders users and hides delete button on self', (
      tester,
    ) async {
      final remote = _FakeAdminUsersRemoteDataSource([
        const UserProfile(
          id: 'doc-1',
          email: 'doc1@rmpzd.test',
          fullName: 'Dra. Wayuu',
          role: UserRole.doctor,
          active: true,
        ).toJson(),
      ]);
      final provider = AdminUsersProvider(
        repository: AdminUsersRepositoryImpl(remote),
        connectivityService: _FakeConnectivity(true),
        currentUserId: () => 'admin-1',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminUsersProvider>.value(
          value: provider,
          child: const MaterialApp(home: AdminUsersPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gestión de usuarios'), findsOneWidget);
      expect(find.text('Dra. Wayuu'), findsOneWidget);
      expect(find.text('ID: doc-1'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });
  });
}

class _FakeAdminUsersRemoteDataSource implements AdminUsersRemoteDataSource {
  final List<Map<String, dynamic>> rows;
  bool permissionDenied = false;

  _FakeAdminUsersRemoteDataSource(this.rows);

  @override
  Future<List<Map<String, dynamic>>> fetchUsers({String? searchQuery}) async {
    final q = searchQuery?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return List.of(rows);
    return rows
        .where(
          (row) =>
              (row['email'] as String).toLowerCase().contains(q) ||
              ((row['full_name'] as String?) ?? '').toLowerCase().contains(q) ||
              (row['id'] as String).toLowerCase() == q,
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> updateUser({
    required String id,
    required String? fullName,
    required UserRole role,
    required bool active,
  }) async {
    if (permissionDenied) {
      throw const AdminPermissionException('Bloqueado por RLS.');
    }
    final index = rows.indexWhere((r) => r['id'] == id);
    rows[index] = {
      ...rows[index],
      'full_name': fullName,
      'role': role.name,
      'active': active,
    };
    return rows[index];
  }

  @override
  Future<void> deleteUserProfile({required String id}) async {
    if (permissionDenied) {
      throw const AdminPermissionException('Bloqueado por RLS.');
    }
    rows.removeWhere((r) => r['id'] == id);
  }
}

class _FakeConnectivity extends ConnectivityService {
  bool online;

  _FakeConnectivity(this.online)
    : super(connectivity: Connectivity(), client: null);

  @override
  Future<bool> hasInternet() async => online;
}
