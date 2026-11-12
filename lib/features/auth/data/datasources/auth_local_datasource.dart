import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_profile.dart';

class AuthLocalDataSource {
  static const _profileKey = 'cached_auth_profile';

  final SharedPreferences preferences;

  AuthLocalDataSource({required this.preferences});

  Future<UserProfile?> getCachedProfile() async {
    final jsonValue = preferences.getString(_profileKey);
    if (jsonValue == null) return null;

    final decoded = jsonDecode(jsonValue);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El perfil guardado localmente no es válido.');
    }
    return UserProfile.fromJson(decoded);
  }

  Future<void> cacheProfile(UserProfile profile) async {
    await preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<void> clearProfile() async {
    await preferences.remove(_profileKey);
  }
}
