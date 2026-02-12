import 'field_type.dart';
import 'validator_config.dart';

/// Formation tags configuration for a schema field.
class FormationTags {
  const FormationTags({this.tags = const []});

  final List<String> tags;

  Map<String, dynamic> toJson() => {'tags': tags};

  factory FormationTags.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FormationTags();
    final tags = json['tags'];
    if (tags is List) {
      return FormationTags(tags: tags.map((e) => e.toString()).toList());
    }
    return const FormationTags();
  }
}

/// A single field definition in the registration schema.
class SchemaField {
  const SchemaField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
    this.validators = const [],
    this.systemField,
    this.locked = false,
    this.formationTags = const FormationTags(),
  });

  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final List<String> options;
  final List<ValidatorConfig> validators;
  final String? systemField;
  final bool locked;
  final FormationTags formationTags;

  SchemaField copyWith({
    String? key,
    String? label,
    FieldType? type,
    bool? required,
    List<String>? options,
    List<ValidatorConfig>? validators,
    String? systemField,
    bool? locked,
    FormationTags? formationTags,
  }) {
    return SchemaField(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      options: options ?? List.from(this.options),
      validators: validators ?? List.from(this.validators),
      systemField: systemField ?? this.systemField,
      locked: locked ?? this.locked,
      formationTags: formationTags ?? this.formationTags,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type.name,
        'required': required,
        if (options.isNotEmpty) 'options': options,
        if (validators.isNotEmpty)
          'validators': validators.map((v) => v.toJson()).toList(),
        if (systemField != null) 'systemField': systemField,
        if (locked) 'locked': locked,
        if (formationTags.tags.isNotEmpty)
          'formation': formationTags.toJson(),
      };

  factory SchemaField.fromJson(Map<String, dynamic> json) {
    final formation = json['formation'];
    return SchemaField(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: FieldTypeX.fromString(json['type'] as String? ?? '') ??
          FieldType.text,
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      validators: (json['validators'] as List<dynamic>?)
              ?.map((e) => ValidatorConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      systemField: json['systemField'] as String?,
      locked: json['locked'] as bool? ?? false,
      formationTags: FormationTags.fromJson(
        formation is Map<String, dynamic> ? formation : null,
      ),
    );
  }
}
