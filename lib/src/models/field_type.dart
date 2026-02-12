/// Supported field types for dynamic registration schema.
enum FieldType {
  text,
  email,
  phone,
  select,
  multiselect,
  date,
  number,
  textarea,
  checkbox,
}

extension FieldTypeX on FieldType {
  static FieldType? fromString(String value) {
    return FieldType.values.cast<FieldType?>().firstWhere(
      (e) => e?.name == value,
      orElse: () => null,
    );
  }

  String get displayName {
    switch (this) {
      case FieldType.text:
        return 'Text';
      case FieldType.email:
        return 'Email';
      case FieldType.phone:
        return 'Phone';
      case FieldType.select:
        return 'Select';
      case FieldType.multiselect:
        return 'Multi-select';
      case FieldType.date:
        return 'Date';
      case FieldType.number:
        return 'Number';
      case FieldType.textarea:
        return 'Text Area';
      case FieldType.checkbox:
        return 'Checkbox';
    }
  }
}
