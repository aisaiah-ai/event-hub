import 'package:event_hub/event_hub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvParser', () {
    const parser = CsvParser();

    test('parseCsv returns list of row maps', () {
      const csv = 'name,email\nJohn,john@x.com\nJane,jane@x.com';
      final rows = parser.parseCsv(csv);
      expect(rows.length, 2);
      expect(rows.first['name'], 'John');
      expect(rows.first['email'], 'john@x.com');
      expect(rows[1]['name'], 'Jane');
    });

    test('autoMapHeaders matches schema keys', () {
      final schema = RegistrationSchema(
        version: 0,
        updatedAt: DateTime.now(),
        fields: [
          SchemaField(
            key: 'fullName',
            label: 'Full Name',
            type: FieldType.text,
          ),
          SchemaField(key: 'email', label: 'Email', type: FieldType.email),
        ],
      );
      final headers = ['Full Name', 'Email'];
      final mapping = parser.autoMapHeaders(headers, schema);
      expect(mapping['Full Name'], 'fullName');
      expect(mapping['Email'], 'email');
    });

    test('deterministicId produces stable hash', () {
      final values = {'email': 'a@b.com', 'name': 'John'};
      final id1 = parser.deterministicId(values, ['email', 'name']);
      final id2 = parser.deterministicId(values, ['email', 'name']);
      expect(id1, id2);
      expect(id1.length, 20);
    });
  });
}
