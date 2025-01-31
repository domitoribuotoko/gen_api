enum SchemasType {
  field,
  model;

  bool get isModel => this == model;

  bool get isField => this == field;
}

enum SchemeDeclaration {
  unknown,
  ref,
  properties,
  allOf,
  oneOf;

  bool get isProp => this == properties;

  bool get isAll => this == allOf;

  bool get isOne => this == oneOf;

  bool get isRef => this == ref;
}
