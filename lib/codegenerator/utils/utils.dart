import 'package:gen_yaml/codegenerator/utils/consts.dart';
import 'package:gen_yaml/codegenerator/utils/enums.dart';
import 'package:gen_yaml/codegenerator/utils/support_classes.dart';
import 'package:recase/recase.dart';
import 'package:yaml/yaml.dart';

typedef u = Utility;

class Utility {
  static SchemasType getFieldType(YamlMap fieldValue, YamlMap schemas) {
    // print('GET FIELD TYPE $fieldValue');
    SchemeDeclaration dec = getSchemaDeclaration(fieldValue);
    if (dec.isAnyReference) {
      YamlMap schema = getSchemaFromRef(fieldValue, schemas);
      return _getSchemaType(schema);
    } else {
      return _getSchemaType(fieldValue);
    }
  }

  static YamlMap getSchemaFromRef(YamlMap fieldValue, YamlMap schemas) {
    String? flatRef = getRefFromMap(fieldValue);
    if (flatRef == null) {
      throw Exception('NO FLAT REF');
    }
    return schemas[formatReference(flatRef)];
  }

  static String? getRefFromMap(YamlMap fieldValue) {
    YamlList? list = fieldValue[c.one] ?? fieldValue[c.all];
    String? flatRef = fieldValue[c.ref] ?? list?.first[c.ref];
    // if ((list != null && flatRef == null) || flatRef == null) {
    //   throw Exception('ref is null for $fieldValue list $list');
    // }
    return flatRef;
  }

  static SchemasType _getSchemaType(YamlMap fieldValue) {
    if (fieldValue[c.type] == c.arr) {
      return SchemasType.array;
    }
    if (fieldValue[c.prop] != null || fieldValue[c.req] != null) {
      return SchemasType.model;
    }
    return SchemasType.field;
  }

  static SchemeDeclaration getSchemaDeclaration(YamlMap yamlMap) {
    if (yamlMap[c.ref] != null) {
      return SchemeDeclaration.ref;
    }
    if (yamlMap[c.all] != null) {
      return SchemeDeclaration.allOf;
    }
    if (yamlMap[c.one] != null) {
      return SchemeDeclaration.oneOf;
    }
    if (yamlMap[c.prop] != null || yamlMap[c.type] != null) {
      return SchemeDeclaration.here;
    }

    return SchemeDeclaration.unknown;
  }

  static String classNameOfField(List<String> affixes) {
    String name = '';
    for (var element in affixes) {
      name = name + _re(element).pascalCase;
    }
    String res = _re('${name}Model').pascalCase;
    // print('GEN CLASS NAME OF FIELD $res');
    return res;
  }

  static String classNameOfPath(String path) {
    String res = _re('${path.replaceAll('/', '')}Request').pascalCase;
    // print('GEN CLASS NAME OF PATH $res');
    return res;
  }

  static String apiMethodNameOfPath(String path) {
    path = path.replaceAll('/', '');
    return _re(path).camelCase;
  }

  static ReCase _re(String value) {
    return ReCase(value);
  }

  static String formatReference(String reference) {
    return reference.split('/').last;
  }

  static String newLine(Object? value) => '\n$value\n';

  static String generateType(String? type, String? format) {
    if (type == null && format == null) {
      throw Exception('PARSE FIELD TYPE ERROR');
    }
    switch (type) {
      case 'string':
        return 'String';
      case 'integer':
      case 'number':
        if (format == 'double' || format == 'float') return 'double';
        else return 'int';
      case 'boolean':
        return 'bool';
      case 'array':
      case 'object':
        throw Exception('FIELD TYPE ERROR');
      default:
        return 'dynamic';
    }
  }
}

extension FindMapExtension on Iterable<MapEntry> {
  dynamic operator [](Object? key) => where((e) => e.key == key).firstOrNull;
}

extension ApiModelList on List<ApiModel> {
  ApiModel? i(String key) => where((e) => e.name == key).firstOrNull;

  bool exist(String name) => where((e) => e.name == name).firstOrNull != null;
}

extension YamlListExtension on YamlList {
  void forEachReverse(void Function(YamlMap e, YamlMap? prevE) callBack) {
    for (int index = length - 1; index > -1; index--) {
      callBack(elementAt(index), elementAtOrNull(index + 1));
    }
  }
}
