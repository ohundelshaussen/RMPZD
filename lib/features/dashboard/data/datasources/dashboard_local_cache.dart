import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/dashboard_filter.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/repositories/dashboard_repository.dart';

class DashboardLocalCache {
  final SharedPreferences preferences;

  const DashboardLocalCache({required this.preferences});

  Future<DashboardCacheEntry?> read(DashboardFilter filter) async {
    final stored = preferences.getString(_key(filter));
    if (stored == null) return null;

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) {
        throw const FormatException('El caché del dashboard no es válido.');
      }
      final map = Map<String, dynamic>.from(decoded);
      final rawStats = map['stats'];
      final rawCachedAt = map['cached_at'];
      if (rawStats is! Map || rawCachedAt is! String) {
        throw const FormatException('El caché del dashboard está incompleto.');
      }
      final cachedAt = DateTime.tryParse(rawCachedAt);
      if (cachedAt == null) {
        throw const FormatException('La fecha del caché no es válida.');
      }
      return DashboardCacheEntry(
        stats: DashboardStats.fromJson(Map<String, dynamic>.from(rawStats)),
        cachedAt: cachedAt,
      );
    } on FormatException {
      await preferences.remove(_key(filter));
      rethrow;
    }
  }

  Future<void> write(
    DashboardFilter filter,
    DashboardStats stats,
    DateTime cachedAt,
  ) async {
    final stored = jsonEncode({
      'cached_at': cachedAt.toIso8601String(),
      'stats': stats.toJson(),
    });
    final saved = await preferences.setString(_key(filter), stored);
    if (!saved) {
      throw StateError('No se pudo guardar el caché del dashboard.');
    }
  }

  String _key(DashboardFilter filter) =>
      'dashboard_stats_${filter.cacheKey()}';
}
