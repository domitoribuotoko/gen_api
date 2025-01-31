import 'package:gen_yaml/codegenerator/api_gen.dart';
import 'package:gen_yaml/codegenerator/utils/consts.dart';
import 'package:gen_yaml/codegenerator/utils/enums.dart';
import 'package:recase/recase.dart';
import 'package:yaml/yaml.dart';

typedef u = Utility;

class Utility {
  static SchemasType getSchemaType(YamlMap fieldValue) {
    final type = fieldValue[c.type];
    if (type == null) {
      return SchemasType.model;
    }
    return SchemasType.field;
  }

  static SchemeDeclaration getSchemaDeclaration(YamlMap yamlMap) {
    if (yamlMap[c.ref] != null) {
      return SchemeDeclaration.ref;
    }
    if (yamlMap[c.prop] != null) {
      return SchemeDeclaration.properties;
    }
    if (yamlMap[c.all] != null) {
      return SchemeDeclaration.allOf;
    }
    if (yamlMap[c.one] != null) {
      return SchemeDeclaration.oneOf;
    }
    return SchemeDeclaration.unknown;
  }

  static String modelNameOfField(String fieldName) {
    return _re('${fieldName}Model').pascalCase;
  }

  static String modelNameOfPath(String path) {
    return _re('${path.replaceAll('/', '')}Request').pascalCase;
  }

  static String apiMethodNameOf(String path) {
    path = path.replaceAll('/', '');
    return _re(path).camelCase;
  }

  static ReCase _re(String value) {
    return ReCase(value);
  }

  static String formatReference(String reference) {
    return reference.split('/').last;
  }
}

extension FindMapExtension on Iterable<MapEntry> {
  dynamic operator [](Object? key) => where((e) => e.key == key).firstOrNull;
}
