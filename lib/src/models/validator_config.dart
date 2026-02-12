/// Validator configuration for schema fields.
enum ValidatorType {
  regex,
  minLength,
  maxLength,
  email,
  custom,
}

extension ValidatorTypeX on ValidatorType {
  static ValidatorType? fromString(String value) {
    return ValidatorType.values.cast<ValidatorType?>().firstWhere(
          (e) => e?.name == value,
          orElse: () => null,
        );
  }
}

class ValidatorConfig {
  const ValidatorConfig({
    required this.type,
    this.value,
  });

  final ValidatorType type;
  final String? value;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (value != null) 'value': value,
      };

  factory ValidatorConfig.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    return ValidatorConfig(
      type: ValidatorTypeX.fromString(typeStr ?? '') ?? ValidatorType.custom,
      value: json['value'] as String?,
    );
  }
}
