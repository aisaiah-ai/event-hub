import '../models/field_type.dart';
import '../models/schema_field.dart';
import '../models/validator_config.dart';

/// Validation result for a single field.
class FieldValidationResult {
  const FieldValidationResult({this.error});

  final String? error;

  bool get isValid => error == null;
}

/// Validates field values against schema.
class FieldValidator {
  const FieldValidator();

  FieldValidationResult validate(
    SchemaField field,
    dynamic value,
    bool requiredEnforced,
  ) {
    final isEmpty = value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is List && value.isEmpty);

    if (field.required && requiredEnforced && isEmpty) {
      return FieldValidationResult(error: '${field.label} is required');
    }

    if (isEmpty) return const FieldValidationResult();

    for (final v in field.validators) {
      final err = _validateOne(v, value, field.label);
      if (err != null) return FieldValidationResult(error: err);
    }

    switch (field.type) {
      case FieldType.email:
        if (!_isValidEmail(value.toString())) {
          return FieldValidationResult(error: 'Invalid email format');
        }
        break;
      case FieldType.number:
        if (num.tryParse(value.toString()) == null) {
          return FieldValidationResult(error: 'Must be a number');
        }
        break;
      case FieldType.select:
        if (field.options.isNotEmpty && !field.options.contains(value.toString())) {
          return FieldValidationResult(
            error: 'Must be one of: ${field.options.join(", ")}',
          );
        }
        break;
      case FieldType.multiselect:
        if (value is List) {
          for (final item in value) {
            if (!field.options.contains(item.toString())) {
              return FieldValidationResult(
                error: 'Invalid option: $item',
              );
            }
          }
        }
        break;
      default:
        break;
    }

    return const FieldValidationResult();
  }

  String? _validateOne(ValidatorConfig v, dynamic value, String label) {
    final s = value.toString();
    switch (v.type) {
      case ValidatorType.minLength:
        final len = int.tryParse(v.value ?? '0') ?? 0;
        if (s.length < len) {
          return '$label must be at least $len characters';
        }
        break;
      case ValidatorType.maxLength:
        final len = int.tryParse(v.value ?? '0') ?? 0;
        if (s.length > len) {
          return '$label must be at most $len characters';
        }
        break;
      case ValidatorType.regex:
        if (v.value != null) {
          final re = RegExp(v.value!);
          if (!re.hasMatch(s)) {
            return '$label has invalid format';
          }
        }
        break;
      case ValidatorType.email:
        if (!_isValidEmail(s)) return 'Invalid email format';
        break;
      default:
        break;
    }
    return null;
  }

  bool _isValidEmail(String s) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(s);
  }
}
