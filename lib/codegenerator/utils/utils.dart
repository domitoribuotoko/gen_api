import 'dart:io';

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
        if (format == 'double' || format == 'float')
          return 'double';
        else
          return 'int';
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

    buffer.writeln("\npart 'api_client.g.dart';\n");
    buffer.writeln('@RestApi()\nclass ApiClient {\n');
    buffer.writeln(
        '  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;\n');

    return buffer;
  }

  static StringBuffer clientFile() {
    StringBuffer buffer = StringBuffer();

    buffer.writeln("import 'package:retrofit/retrofit.dart';");
    buffer.writeln("import 'package:dio/dio.dart';");

    return buffer;
  }

  static StringBuffer _initModel(ApiModel model) {
    StringBuffer modelDefinition = StringBuffer();
    // Добавляем аннотацию для сериализации
    modelDefinition.writeln('@JsonSerializable()');
    // Проверяем, есть ли супермодель, и добавляем её в определение класса
    if (model.superModel != null) {
      modelDefinition
          .writeln('class ${model.name} extends ${model.superModel!.name} {');
    } else {
      modelDefinition.writeln('class ${model.name} {');
    }
    return modelDefinition;
  }

  static StringBuffer generateModelDefinition(ApiModel model) {
    return _initModel(model)
      ..writeln(_modelFields(model))
      ..writeln(_modelConstructor(model))
      ..writeln(_jsonMethods(model.name));
  }

  static StringBuffer _modelFields(ApiModel model) {
    StringBuffer buf = StringBuffer();
    for (final field in model.fields) {
      String originalName = field.name;
      String processedName = processFieldName(originalName);
      if (processedName != originalName) {
        buf.writeln('  @JsonKey(name: \'$originalName\')');
      }
      buf.writeln('  final ${field.type}? $processedName;');
    }
    return buf;
  }

  static StringBuffer _modelConstructor(ApiModel model) {
    StringBuffer buf = StringBuffer();
    if (model.fields.isNotEmpty || model.superModel != null) {
      // Генерируем конструктор
      buf.writeln('  ${model.name}({');
      // Добавляем поля из супермодели, если она есть
      if (model.superModel != null) {
        for (final field in model.superModel!.fields) {
          String processedName = processFieldName(field.name);
          buf.writeln('    super.$processedName,');
        }
      }
      // Добавляем поля текущей модели
      for (final field in model.fields) {
        String processedName = processFieldName(field.name);
        buf.writeln('    this.$processedName,');
      }
      buf.writeln('  });');
    } else {
      buf.writeln('  ${model.name}();');
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
    buf.writeln(
        '  factory $modelName.fromJson(Map<String, dynamic> json) => _\$${modelName}FromJson(json);');
    buf.writeln(
        '  Map<String, dynamic> toJson() => _\$${modelName}ToJson(this);');
    buf.writeln('}');
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

    // Записываем аннотацию HTTP метода
    buffer.writeln('  @$httpMethod(\'$apiPath\')');

    // Записываем сигнатуру метода
    buffer.writeln('  Future<$returnType> ${method.methodName}(');
    buffer.writeln('    @Body() $requestType request,');
    buffer.writeln('  );\n');

    return buffer;
  }

  static String get projDir => _getCurrentProjectFolderName();

  static String _getCurrentProjectFolderName() {
    Directory currentDirectory = Directory.current;
    String currentPath = currentDirectory.path;
    String folderName = currentPath.split(Platform.pathSeparator).last;
    return folderName;
  }

  static ApiModel mergeModels(List<ApiModel> models, {String? newName}) {
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
    return ApiModel(
      name: newName ?? 'MergedModel',
      fields: uniqueFields.values.toList(),
      superModel: uniqueSuperModels.isNotEmpty
          ? models.firstWhere((model) => model.superModel != null).superModel
          : null,
      usages: combinedUsages,
    );
  }
}

extension FindMapExtension on Iterable<MapEntry> {
  dynamic operator [](Object? key) => where((e) => e.key == key).firstOrNull;
}

extension ApiModelList on List<ApiModel> {
  ApiModel? item(String key) => where((e) => e.name == key).firstOrNull;

  bool exist(String name) => where((e) => e.name == name).firstOrNull != null;

  bool hasValidRequestModels() => any((e) => e.usages.length == 1);
}

extension YamlListExtension on YamlList {
  void forEachReverse(void Function(YamlMap e, YamlMap? prevE) callBack) {
    for (int index = length - 1; index > -1; index--) {
      callBack(elementAt(index), elementAtOrNull(index + 1));
    }
  }
}

extension ApiModelListExtensions on List<ApiModel> {
  void removeMatchingModel(ApiModel targetModel) {
    removeWhere((model) {
      bool allFieldsMatch = true;

      // Проверяем, покрываются ли все поля модели из списка полями модели для сравнения
      for (final field in model.fields) {
        final matchingField = targetModel.fields.any(
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
          return targetModel.fields.any(
            (targetField) =>
                targetField.name == field.name &&
                targetField.type == field.type,
          );
        });
        return false;
      }
    });
  }

  void replaceModels(List<ApiModel> inputModels) {
    for (var inputModel in inputModels) {
      // Найти индекс модели с таким же именем в основном списке
      int index = indexWhere((model) => model.name == inputModel.name);

      if (index != -1) {
        // Логирование замены модели
        print(
            'Replacing model: ${this[index]} with new model from input list.');

        // Заменить модель в основном списке на модель из входного списка
        this[index] = inputModel;
      } else {
        // Логирование, если модель не найдена
        print('Model not found in the main list: $inputModel');
      }
    }
  }
}
