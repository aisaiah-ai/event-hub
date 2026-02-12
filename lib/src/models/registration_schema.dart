import 'package:cloud_firestore/cloud_firestore.dart';

import 'role_override.dart';
import 'schema_field.dart';

/// Registration schema document stored at events/{eventId}/schemas/registration
class RegistrationSchema {
  const RegistrationSchema({
    required this.version,
    required this.updatedAt,
    this.fields = const [],
    this.roleOverrides = const RoleOverrides(),
  });

  final int version;
  final DateTime updatedAt;
  final List<SchemaField> fields;
  final RoleOverrides roleOverrides;

  RegistrationSchema copyWith({
    int? version,
    DateTime? updatedAt,
    List<SchemaField>? fields,
    RoleOverrides? roleOverrides,
  }) {
    return RegistrationSchema(
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      fields: fields ?? List.from(this.fields),
      roleOverrides: roleOverrides ?? this.roleOverrides,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'updatedAt': Timestamp.fromDate(updatedAt),
    'fields': fields.map((f) => f.toJson()).toList(),
    'roleOverrides': roleOverrides.toJson(),
  };

  factory RegistrationSchema.fromJson(Map<String, dynamic> json) {
    final updatedAt = json['updatedAt'];
    return RegistrationSchema(
      version: json['version'] as int? ?? 0,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : DateTime.now(),
      fields:
          (json['fields'] as List<dynamic>?)
              ?.map((e) => SchemaField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      roleOverrides: RoleOverrides.fromJson(
        json['roleOverrides'] as Map<String, dynamic>?,
      ),
    );
  }

  SchemaField? getFieldByKey(String key) {
    try {
      return fields.firstWhere((f) => f.key == key);
    } catch (_) {
      return null;
    }
  }
}
