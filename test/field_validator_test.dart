import 'package:event_hub/event_hub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FieldValidator', () {
    const validator = FieldValidator();

    test('validates required field when enforced', () {
      final field = SchemaField(
        key: 'name',
        label: 'Name',
        type: FieldType.text,
        required: true,
      );
      expect(
        validator.validate(field, null, true).isValid,
        isFalse,
      );
      expect(
        validator.validate(field, '', true).isValid,
        isFalse,
      );
      expect(
        validator.validate(field, 'John', true).isValid,
        isTrue,
      );
    });

    test('skips required when not enforced', () {
      final field = SchemaField(
        key: 'name',
        label: 'Name',
        type: FieldType.text,
        required: true,
      );
      expect(
        validator.validate(field, null, false).isValid,
        isTrue,
      );
    });

    test('validates email format', () {
      final field = SchemaField(
        key: 'email',
        label: 'Email',
        type: FieldType.email,
      );
      expect(
        validator.validate(field, 'invalid', true).isValid,
        isFalse,
      );
      expect(
        validator.validate(field, 'user@example.com', true).isValid,
        isTrue,
      );
    });

    test('validates number type', () {
      final field = SchemaField(
        key: 'age',
        label: 'Age',
        type: FieldType.number,
      );
      expect(
        validator.validate(field, '42', true).isValid,
        isTrue,
      );
      expect(
        validator.validate(field, 'not-a-number', true).isValid,
        isFalse,
      );
    });

    test('validates select options', () {
      final field = SchemaField(
        key: 'role',
        label: 'Role',
        type: FieldType.select,
        options: ['admin', 'staff'],
      );
      expect(
        validator.validate(field, 'admin', true).isValid,
        isTrue,
      );
      expect(
        validator.validate(field, 'invalid', true).isValid,
        isFalse,
      );
    });
  });
}
