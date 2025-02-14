import 'dart:io';
import 'package:gen_yaml/codegenerator/utils/consts.dart';
import 'package:gen_yaml/codegenerator/utils/enums.dart';
import 'package:gen_yaml/codegenerator/utils/error.dart';
import 'package:gen_yaml/codegenerator/utils/support_classes.dart';
import 'package:gen_yaml/run.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:recase/recase.dart';
import 'package:yaml/yaml.dart';

typedef u = Utility;

class Utility {
  static YamlMap? contentFromSchema(YamlMap schema) {
    YamlMap? contentJson = schema[con.cont]?[con.json];
    YamlMap? contentMultipart = schema[con.cont]?[con.multipart];
    YamlMap? content = contentJson ?? contentMultipart;
    return content;
  }

  static YamlMap? propFromSchema(YamlMap schema) {
    YamlMap? content = contentFromSchema(schema)?['schema'];
    YamlMap? props = schema.value[con.prop] ?? content?[con.prop];
    return props;
  }

  static String packageName() {
    String path = 'pubspec.yaml';
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('no pubspec: $path');
    }
    String yaml = file.readAsStringSync();
    return Pubspec.parse(yaml).name;
  }

  static SchemasType getFieldType(YamlMap fieldValue, YamlMap schemas) {
    SchemeDeclaration dec = getSchemaDeclaration(fieldValue);
    if (dec.isAnyReference) {
      YamlMap schema = getSchemaFromRef(fieldValue, schemas);
      return _getSchemaType(schema, schemas);
    } else {
      return _getSchemaType(fieldValue, schemas);
    }
  }

  static void error() {
    throw Exception('asdf');
  }

  static SchemasType _getSchemaType(YamlMap fieldValue, YamlMap schemas) {
    SchemeDeclaration dec = getSchemaDeclaration(fieldValue);
    YamlMap? content = contentFromSchema(fieldValue);
    if (dec.isAnyReference) {
      e.refOnRef(fieldValue.toString());
    }
    if (fieldValue[con.type] == con.arr) {
      return SchemasType.array;
    }
    if (fieldValue[con.prop] != null ||
        fieldValue[con.req] != null ||
        content != null) {
      return SchemasType.model;
    }
    return SchemasType.field;
  }

  static SchemeDeclaration getSchemaDeclaration(YamlMap yamlMap) {
    YamlMap? content = u.contentFromSchema(yamlMap);
    if (content != null) {
      return SchemeDeclaration.here;
    }
    if (yamlMap[con.ref] != null) {
      return SchemeDeclaration.ref;
    }
    if (yamlMap[con.all] != null) {
      return SchemeDeclaration.allOf;
    }
    if (yamlMap[con.one] != null) {
      return SchemeDeclaration.oneOf;
    }
    if (yamlMap[con.prop] != null || yamlMap[con.type] != null) {
      return SchemeDeclaration.here;
    }

    return SchemeDeclaration.unknown;
  }

  static YamlMap getSchemaFromRef(YamlMap fieldValue, YamlMap schemas) {
    String? flatRef = getRefFromMap(fieldValue);
    if (flatRef == null) {
      throw Exception('NO FLAT REF');
    }
    return schemas[formatReference(flatRef)];
  }

  static String? getRefFromMap(YamlMap fieldValue) {
    YamlList? list = fieldValue[con.one] ?? fieldValue[con.all];
    String? flatRef = fieldValue[con.ref] ?? list?.first[con.ref];
    return flatRef;
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

  static String classNameOfPath(
    String path, {
    bool isResponse = false,
  }) {
    String suf = isResponse ? 'Response' : 'Request';
    String res = _re('${path.replaceAll('/', '')}$suf').pascalCase;
    // print('GEN CLASS NAME OF PATH $res');
    return res;
  }

  static String apiMethodNameOfPath(String path) {
    path = path.replaceAll('/', '_');
    return _re(path).camelCase;
  }

  static ReCase _re(String value) {
    return ReCase(value);
  }

  static String formatReference(String reference) {
    return reference.split('/').last;
  }

  static String generateType(String? type, String? format) {
    if (type == null && format == null) {
      throw Exception('PARSE FIELD TYPE ERROR\ntype:$type\nformat:$format');
    }
    switch (type) {
      case 'string':
        return 'String';
      case 'integer':
      case 'number':
        if (format == 'double' || format == 'float') {
          return 'double';
        } else {
          return 'int';
        }
      case 'boolean':
        return 'bool';
      case 'array':
      case 'object':
        throw Exception('FIELD TYPE ERROR');
      default:
        return 'dynamic';
    }
  }

  static StringBuffer clientClass() {
    StringBuffer buffer = StringBuffer();
    buffer.writelnIfNotEmpty(u.part('api_client'));
    buffer.writelnIfNotEmpty('@RestApi()\nabstract class ApiClient {\n');
    buffer.writelnIfNotEmpty(
        '  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;\n');

    return buffer;
  }

  static StringBuffer clientFile() {
    StringBuffer buffer = StringBuffer();

    buffer.writelnIfNotEmpty("import 'package:retrofit/retrofit.dart';");
    buffer.writelnIfNotEmpty("import 'package:dio/dio.dart';");

    return buffer;
  }

  static StringBuffer generateModelDefinition(ApiModel model) {
    return _initModel(model)
      ..writelnIfNotEmpty(_modelFields(model))
      ..writelnIfNotEmpty(_modelConstructor(model))
      ..writelnIfNotEmpty(_jsonMethods(model.name));
  }

  static StringBuffer _initModel(ApiModel model) {
    StringBuffer modelDefinition = StringBuffer();
    modelDefinition.writelnIfNotEmpty('@JsonSerializable()');
    _addDescription(model.description, modelDefinition);
    if (model.superModel != null) {
      modelDefinition.writelnIfNotEmpty(
          'class ${model.name} extends ${model.superModel!.name} {');
    } else {
      modelDefinition.writelnIfNotEmpty('class ${model.name} {');
    }
    return modelDefinition;
  }

  static String generateModelImport(String path) {
    path = path.replaceAll('lib/', '');
    return "import 'package:$appName/$path';";
  }

  static void maybeAddImport(String path, StringBuffer clientImports) {
    if (path.isNotEmpty) {
      String import = u.generateModelImport(path);
      if (!clientImports.containsLine(import)) {
        clientImports.writelnIfNotEmpty(import);
      }
    }
  }

  static void createApiClientFile(StringBuffer client, String basePath) {
    // Убедимся, что директория существует
    client.writelnIfNotEmpty('}');
    String directoryPath = '$basePath/data';
    Directory directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    String filePath = '${directory.path}/api_client.dart';

    File file = File(filePath);
    file.writeAsStringSync(client.toString());
  }

  static StringBuffer _modelFields(ApiModel model) {
    StringBuffer buf = StringBuffer();
    for (final field in model.fields) {
      String description = field.description;
      String originalName = field.name;
      String processedName = processFieldName(originalName);
      _addDescription(description, buf);
      if (processedName != originalName) {
        buf.writelnIfNotEmpty('  @JsonKey(name: \'$originalName\')');
      }
      buf.writelnIfNotEmpty('  final ${field.type}? $processedName;');
    }
    return buf;
  }

  static void _addDescription(String desc, StringBuffer buf) {
    if (desc.isNotEmpty) {
      List<String> lines = desc.split('\n');
      for (String line in lines) {
        String trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty) {
          buf.writeln('  /// $trimmedLine');
        }
      }
    }
  }

  static StringBuffer _modelConstructor(ApiModel model) {
    StringBuffer buf = StringBuffer();
    if (model.fields.isNotEmpty || model.superModel != null) {
      // Генерируем конструктор
      buf.writelnIfNotEmpty('  ${model.name}({');
      // Добавляем поля из супермодели, если она есть
      if (model.superModel != null) {
        for (final field in model.superModel!.fields) {
          String processedName = processFieldName(field.name);
          buf.writelnIfNotEmpty('    super.$processedName,');
        }
      }
      // Добавляем поля текущей модели
      for (final field in model.fields) {
        String processedName = processFieldName(field.name);
        buf.writelnIfNotEmpty('    this.$processedName,');
      }
      buf.writelnIfNotEmpty('  });');
    } else {
      buf.writelnIfNotEmpty('  ${model.name}();');
    }
    return buf;
  }

  static String processFieldName(String name) {
    name = _re(name).camelCase;
    name = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return name;
  }

  static StringBuffer _jsonMethods(String modelName) {
    StringBuffer buf = StringBuffer();
    buf.writelnIfNotEmpty(
        '  factory $modelName.fromJson(Map<String, dynamic> json) => _\$${modelName}FromJson(json);');
    buf.writelnIfNotEmpty(
        '  Map<String, dynamic> toJson() => _\$${modelName}ToJson(this);');
    buf.writelnIfNotEmpty('}');
    return buf;
  }

  static StringBuffer generateApiMethodBuffer(ApiMethod method) {
    StringBuffer buffer = StringBuffer();

    // Определяем HTTP метод и путь
    String httpMethod = method.apiType.toUpperCase();
    String apiPath = method.apiPath;

    // Определяем возвращаемый тип и тип запроса
    String returnType = method.response.name;
    String requestType = method.request.name;
    if (method.response.isArray) {
      returnType = 'List<$returnType>';
    }
    if (method.request.isArray) {
      requestType = 'List<$requestType>';
    }

    // Записываем аннотацию HTTP метода
    buffer.writelnIfNotEmpty('  @$httpMethod(\'$apiPath\')');

    // Записываем сигнатуру метода
    u._addDescription(method.summary, buffer);
    buffer.write('  Future<$returnType> ${method.methodName}(');
    if (!method.request.isEmpty) {
      buffer.writeln();
      buffer.writelnIfNotEmpty('    @Body() $requestType request,');
      buffer.write('  ');
    }
    buffer.writeln(');');
    return buffer;
  }

  static String get projDir {
    Directory currentDirectory = Directory.current;
    String currentPath = currentDirectory.path;
    String folderName = currentPath.split(Platform.pathSeparator).last;
    return folderName;
  }

  static VirtualModel mergeModels(
    List<ApiModel> models, {
    String? newName,
    String? methodPath,
  }) {
    // Используем Map для хранения уникальных полей
    Map<String, ApiField> uniqueFields = {};

    // Используем Set для отслеживания конфликтующих полей
    Set<String> conflictingFields = {};

    // Используем Set для отслеживания уникальных superModel
    Set<String> uniqueSuperModels = {};

    // Список для объединения usages
    List<String> combinedUsages = [];

    for (var model in models) {
      // Добавляем superModel в Set
      if (model.superModel != null) {
        uniqueSuperModels.add(model.superModel!.name);
      }

      // Объединяем usages
      combinedUsages.addAll(model.usages);

      for (var field in model.fields) {
        String fieldName = field.name;
        String fieldType = field.type;

        if (uniqueFields.containsKey(fieldName)) {
          // Если поле уже существует, проверяем на конфликт
          if (uniqueFields[fieldName]!.type != fieldType) {
            // Если типы не совпадают, добавляем в конфликтующие
            conflictingFields.add(fieldName);
          }
        } else {
          // Если поле уникально, добавляем его
          uniqueFields[fieldName] = field;
        }
      }
    }

    // Проверяем количество уникальных superModel
    if (uniqueSuperModels.length > 1) {
      throw Exception(
          'More than one unique superModel found: ${uniqueSuperModels.join(', ')}');
    }

    // Удаляем конфликтующие поля из уникальных
    for (var fieldName in conflictingFields) {
      uniqueFields.remove(fieldName);
    }

    // Создаем новую модель с уникальными полями и объединенными usages
    return VirtualModel(
      name: newName ?? 'MergedModel',
      fields: uniqueFields.values.toList(),
      superModel: uniqueSuperModels.isNotEmpty
          ? models.firstWhere((model) => model.superModel != null).superModel
          : null,
      usages: methodPath != null ? [methodPath] : combinedUsages,
    );
  }

  static String part(String of) {
    return "\npart '$of.g.dart';";
  }
}

extension FindMapExtension on Iterable<MapEntry> {
  dynamic operator [](Object? key) => where((el) => el.key == key).firstOrNull;
}

// extension YamlListExtension on YamlList {
//   void forEachReverse(void Function(YamlMap e, YamlMap? prevE) callBack) {
//     for (int index = length - 1; index > -1; index--) {
//       callBack(elementAt(index), elementAtOrNull(index + 1));
//     }
//   }
// }
extension StringBufferExt on StringBuffer {
  bool containsLine(String line) {
    String content = toString();
    return content.contains(line);
  }

  void writelnIfNotEmpty([Object obj = ""]) {
    if (obj.toString().trim().isNotEmpty) {
      writeln(obj);
    }
  }
}

extension ApiModelListExtensions on List<ApiModel> {
  ApiModel? itemByName(String name) => where((el) => el.name == name).firstOrNull;

  List<ApiModel> childrenFromName(String parentName) {
    return where((el) => el.superModel?.name == parentName).toList();
  }

  // bool exist(String name) => where((e) => e.name == name).firstOrNull != null;

  // bool get hasSingleUsageModel => any((e) => e.isBase);

  bool get hasEmpty => any((el) => el.isEmpty);

  void get removeDuplicates {
    Set<String> seenNames = <String>{};
    removeWhere((ApiModel model) {
      if (seenNames.contains(model.name)) {
        // Если имя модели уже встречалось, удаляем её
        return true;
      } else {
        // Если имя модели уникально, добавляем его в набор
        seenNames.add(model.name);
        return false;
      }
    });
  }

  void setVirtualModel(VirtualModel virtualModel) {
    for (int i = 0; i < length; i++) {
      this[i] = this[i].copyWith(superModel: virtualModel);
    }
  }

  void replaceSingle(ApiModel newModel) {
    int index = indexWhere(
      (element) => element.name == newModel.name,
    );
    if (index != -1) {
      this[index] = newModel;
    } else {
      throw Exception('NO MODEL TO REPLACE');
    }
  }

  void removeMatchingModel(VirtualModel virtualModel) {
    removeWhere((model) {
      bool allFieldsMatch = true;
      // Проверяем, покрываются ли все поля модели из списка полями модели для сравнения
      for (final field in model.fields) {
        final matchingField = virtualModel.fields.any(
          (targetField) =>
              targetField.name == field.name && targetField.type == field.type,
        );
        if (!matchingField) {
          allFieldsMatch = false;
        }
      }
      // Если все поля совпадают, удаляем модель
      if (allFieldsMatch) {
        return true;
      } else {
        // Удаляем совпадающие поля из модели
        model.fields.removeWhere((field) {
          return virtualModel.fields.any((targetField) =>
              targetField.name == field.name && targetField.type == field.type);
        });
        return false;
      }
    });
  }

  void replaceModels(List<ApiModel> inputModels) {
    for (var inputModel in inputModels) {
      int index = indexWhere((model) => model.name == inputModel.name);
      if (index != -1) {
        this[index] = inputModel;
      } else {
        throw Exception('NO MODEL FOR REPLACING');
      }
    }
  }
}
