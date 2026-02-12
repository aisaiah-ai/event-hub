import 'package:event_hub/event_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DynamicFormWidget renders schema fields', (tester) async {
    final schema = RegistrationSchema(
      version: 0,
      updatedAt: DateTime.now(),
      fields: [
        SchemaField(key: 'name', label: 'Name', type: FieldType.text),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicFormWidget(
              schema: schema,
              initialValues: {},
              role: UserRole.user,
              onSubmit: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
