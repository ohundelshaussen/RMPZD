import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/dashboard_filter.dart';
import '../../domain/entities/dashboard_stats.dart';

abstract interface class DashboardRemoteDataSource {
  Future<DashboardStats> fetchStats(DashboardFilter filter);
}

class SupabaseDashboardRemoteDataSource implements DashboardRemoteDataSource {
  final SupabaseClient? client;

  const SupabaseDashboardRemoteDataSource({required this.client});

  @override
  Future<DashboardStats> fetchStats(DashboardFilter filter) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }

    final response = await supabase.rpc(
      'dashboard_stats',
      params: filter.toRpcParams(),
    );
    if (response is! Map) {
      throw const FormatException(
        'La respuesta de dashboard_stats no tiene el formato esperado.',
      );
    }
    return DashboardStats.fromJson(Map<String, dynamic>.from(response));
  }
}
