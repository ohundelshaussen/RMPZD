import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin_records/domain/repositories/admin_records_repository.dart';
import '../../../auth/domain/entities/user_profile.dart';

abstract interface class AdminUsersRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchUsers({String? searchQuery});

  Future<Map<String, dynamic>> updateUser({
    required String id,
    required String? fullName,
    required UserRole role,
    required bool active,
  });

  Future<void> deleteUserProfile({required String id});
}

class SupabaseAdminUsersRemoteDataSource implements AdminUsersRemoteDataSource {
  static const _columns = 'id,email,full_name,role,active';
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final SupabaseClient? client;

  const SupabaseAdminUsersRemoteDataSource({required this.client});

  @override
  Future<List<Map<String, dynamic>>> fetchUsers({String? searchQuery}) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }

    var query = supabase.from('profiles').select(_columns);
    final raw = searchQuery?.trim() ?? '';
    if (raw.isNotEmpty) {
      final sanitized = raw.replaceAll(RegExp(r'[,()*]'), ' ').trim();
      if (sanitized.isNotEmpty) {
        if (_uuidRegex.hasMatch(sanitized)) {
          query = query.or(
            'full_name.ilike.%$sanitized%,'
            'email.ilike.%$sanitized%,'
            'id.eq.$sanitized',
          );
        } else {
          query = query.or(
            'full_name.ilike.%$sanitized%,email.ilike.%$sanitized%',
          );
        }
      }
    }

    final rows = await query.order('full_name', ascending: true);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<Map<String, dynamic>> updateUser({
    required String id,
    required String? fullName,
    required UserRole role,
    required bool active,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }

    final normalizedName = fullName?.trim();
    try {
      final row = await supabase
          .from('profiles')
          .update({
            'full_name': normalizedName == null || normalizedName.isEmpty
                ? null
                : normalizedName,
            'role': role.name,
            'active': active,
          })
          .eq('id', id)
          .select(_columns)
          .maybeSingle();
      if (row == null) {
        throw const AdminPermissionException(
          'Supabase no permitió modificar este perfil (política RLS o perfil inexistente).',
        );
      }
      return Map<String, dynamic>.from(row);
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const AdminPermissionException(
          'Supabase no permite modificar perfiles desde el cliente (política RLS).',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteUserProfile({required String id}) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }

    try {
      final rows = await supabase
          .from('profiles')
          .delete()
          .eq('id', id)
          .select('id');
      if (rows.isEmpty) {
        throw const AdminPermissionException(
          'Supabase no permitió eliminar el perfil (política RLS o usuario inexistente).',
        );
      }
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw const AdminPermissionException(
          'No se puede eliminar este perfil porque tiene evaluaciones clínicas asociadas. Desactívelo en su lugar.',
        );
      }
      if (error.code == '42501') {
        throw const AdminPermissionException(
          'Supabase no permite eliminar perfiles desde el cliente (política RLS). Puede intentar desactivarlo.',
        );
      }
      rethrow;
    }
  }
}
