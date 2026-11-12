enum UserRole { admin, doctor }

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final UserRole role;
  final bool active;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.active,
  });

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email.split('@').first;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'];
    if (roleName is! String ||
        roleName != UserRole.admin.name && roleName != UserRole.doctor.name) {
      throw FormatException('Rol de usuario no válido: $roleName');
    }

    final activeValue = json['active'] ?? true;
    if (activeValue is! bool) {
      throw const FormatException('El estado activo del perfil no es válido.');
    }

    final rawFullName = json['full_name'] ?? json['fullName'];
    return UserProfile(
      id: _requiredString(json, 'id'),
      email: _requiredString(json, 'email'),
      fullName: rawFullName is String ? rawFullName : null,
      role: UserRole.values.byName(roleName),
      active: activeValue,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) =>
      UserProfile.fromJson(map);

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role.name,
    'active': active,
  };

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('El campo "$key" del perfil no es válido.');
    }
    return value;
  }
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Administrador',
    UserRole.doctor => 'Doctor',
  };
}
