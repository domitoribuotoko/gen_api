enum SchemasType {
  field,
  array,
  model;

  bool get isModel => this == model;

  bool get isField => this == field;

  bool get isArray => this == array;
}

enum SchemeDeclaration {
  unknown,
  ref,
  allOf,
  here,
  oneOf;

  // bool get isProp => this == properties;

  bool get isAll => this == allOf;

  bool get isOne => this == oneOf;

  bool get isRef => this == ref;

  // bool get isTypeFiled => this == typeField;

  bool get isAnyReference => this != here;
}
