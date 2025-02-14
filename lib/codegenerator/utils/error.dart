import 'package:gen_yaml/codegenerator/api_gen.dart';

typedef e = Errors;
typedef ex = Exception;

class Errors {
  static ex refOnRef(Object schema) => _e.refOnRef(schema.toString());

  static ex nullBody(Object? apiPath) => _e.nullBody(apiPath.toString());

  static ex modelsIsFiled(Object? content) =>
      _e.modelIsField(content.toString());

  static ex unknownModel(MapEntry map) => _e.unknownModel(map, 'Model');

  static ex unknownField(MapEntry map) => _e.unknownModel(map, 'Field');

  static ex noSchemaRef(String reference) => _e.noSchema(reference);

  static ex arrayInArray(Object array) => _e.arrayInArray(array.toString());

  static ex oneOfField(Object field) => _e.oneOfField(field.toString());

  static ex nullList(Object schema) => _e.nullSchemaList(schema.toString());

  static ex allOfLength(int length) => _e.allOfLength(length.toString());

  static ex nullProp(Object schema) => _e.nullProp(schema.toString());

  static ex responseIsArray(String path) => _e.responseIsArray(path);
}

class _e {
  static ex responseIsArray(String apiPath){
    throw ex(r('response is array for path ${y(apiPath)}'));
  }
  static ex refOnRef(String schema) {
    throw ex(r('Schema is reference on other reference\nschema:\n$schema'));
  }

  static ex nullBody(String apiPath) {
    throw ex(r('path has null body\napiPath:\n$apiPath'));
  }

  static nullProp(String schema) {
    throw ex(r('null prop for:$schema'));
  }

  static ex modelIsField(String content) {
    throw ex(r('model is field for some reason for:\n$content'));
  }

  static ex unknownModel(MapEntry map, String type) {
    throw ex(
        r('unknown${type}Declaration schema:\n${map.value}\nname:${map.key}'));
  }

  static ex noSchema(String reference) {
    throw ex(r('schema declaration not found through reference: $reference'));
  }

  static ex arrayInArray(String array) {
    throw ex(r('array inside array schema:\n$array'));
  }

  static ex oneOfField(String field) {
    throw ex(r('try generate field from oneOf:\n$field'));
  }

  static nullSchemaList(String schema) {
    throw ex(r('schema list null in\n$schema'));
  }

  static allOfLength(String length) {
    throw ex(r('case allOf not covered length: $length'));
  }
}
