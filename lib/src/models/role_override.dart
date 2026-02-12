/// Role-based validation overrides.
enum UserRole { admin, staff, user }

extension UserRoleX on UserRole {
  static UserRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'STAFF':
        return UserRole.staff;
      default:
        return UserRole.user;
    }
  }

  String get name {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.staff:
        return 'STAFF';
      case UserRole.user:
        return 'USER';
    }
  }
}

/// Role override configuration for schema validation.
class RoleOverrides {
  const RoleOverrides({
    this.adminAllowMissingRequired = true,
    this.staffAllowMissingRequired = false,
  });

  final bool adminAllowMissingRequired;
  final bool staffAllowMissingRequired;

  bool allowMissingRequired(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminAllowMissingRequired;
      case UserRole.staff:
        return staffAllowMissingRequired;
      case UserRole.user:
        return false;
    }
  }

  Map<String, dynamic> toJson() => {
    'ADMIN': {'allowMissingRequired': adminAllowMissingRequired},
    'STAFF': {'allowMissingRequired': staffAllowMissingRequired},
  };

  factory RoleOverrides.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RoleOverrides();
    return RoleOverrides(
      adminAllowMissingRequired:
          (json['ADMIN'] as Map<String, dynamic>?)?['allowMissingRequired']
              as bool? ??
          true,
      staffAllowMissingRequired:
          (json['STAFF'] as Map<String, dynamic>?)?['allowMissingRequired']
              as bool? ??
          false,
    );
  }
}
