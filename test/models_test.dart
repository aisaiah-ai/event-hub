import 'package:event_hub/event_hub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegistrationSchema', () {
    test('fromJson and toJson roundtrip', () {
      final schema = RegistrationSchema(
        version: 1,
        updatedAt: DateTime(2025, 1, 1),
        fields: [
          SchemaField(key: 'email', label: 'Email', type: FieldType.email),
        ],
      );
      final json = schema.toJson();
      final decoded = RegistrationSchema.fromJson(json);
      expect(decoded.version, schema.version);
      expect(decoded.fields.length, schema.fields.length);
      expect(decoded.fields.first.key, 'email');
    });

    test('getFieldByKey returns correct field', () {
      final schema = RegistrationSchema(
        version: 0,
        updatedAt: DateTime.now(),
        fields: [
          SchemaField(key: 'a', label: 'A', type: FieldType.text),
          SchemaField(key: 'b', label: 'B', type: FieldType.email),
        ],
      );
      expect(schema.getFieldByKey('b')?.label, 'B');
      expect(schema.getFieldByKey('c'), isNull);
    });
  });

  group('Registrant', () {
    test('formValues merges profile and answers', () {
      final r = Registrant(
        id: '1',
        profile: {'email': 'a@b.com'},
        answers: {'custom': 'value'},
      );
      expect(r.formValues['email'], 'a@b.com');
      expect(r.formValues['custom'], 'value');
    });
  });

  group('RoleOverrides', () {
    test('allowMissingRequired respects role', () {
      const overrides = RoleOverrides(
        adminAllowMissingRequired: true,
        staffAllowMissingRequired: false,
      );
      expect(overrides.allowMissingRequired(UserRole.admin), isTrue);
      expect(overrides.allowMissingRequired(UserRole.staff), isFalse);
      expect(overrides.allowMissingRequired(UserRole.user), isFalse);
    });
  });

  group('FieldType', () {
    test('fromString parses correctly', () {
      expect(FieldTypeX.fromString('email'), FieldType.email);
      expect(FieldTypeX.fromString('unknown'), isNull);
    });
  });
}
