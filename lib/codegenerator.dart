import 'dart:io';

import 'package:recase/recase.dart';
import 'package:yaml/yaml.dart';

class CodeGenerator {
  final YamlMap yaml;
  final String outputPath;
  final Set<String> baseModels = {};
  final Map<String, Set<String>> modelUsage = {};
  final Set<String> generatedModels = {};
  final String baseFolder = 'base';

  CodeGenerator(this.yaml, this.outputPath);

  Future<void> generateDataModels(String outputPath) async {
    final schemas = yaml['components']['schemas'] as YamlMap;

    // Сначала анализируем использование моделей
    final paths = yaml['paths'] as YamlMap;
    _analyzeModelUsage(paths);

    // Затем генерируем модели
    for (final entry in schemas.entries) {
      final className = entry.key;
      // Пропускаем модели, которые уже были сгенерированы как наследники
      if (generatedModels.contains(className)) continue;
      
      final schema = entry.value;
      final code = generateDataModel(className, schema);
      final modelFolder = baseModels.contains(className)
          ? 'base' 
          : (modelUsage[className]?.first ?? 'base');
            
      await writeFile('$outputPath/models/$modelFolder/${ReCase(className).snakeCase}.dart', code);
      generatedModels.add(className);
    }
  }

  Future<void> generateApiClient(String outputPath) async {
    final paths = yaml['paths'] as YamlMap;
    _analyzeModelUsage(paths);
    final code = generateRetrofitClient(paths);
    await writeFile('$outputPath/api_client.dart', code);
  }

  Future<void> generateDomainEntities(String outputPath) async {
    final schemas = yaml['components']['schemas'] as YamlMap;

    // Сначала анализируем использование моделей в API
    final paths = yaml['paths'] as YamlMap;
    _analyzeModelUsage(paths);

    for (final entry in schemas.entries) {
      final className = entry.key;
      final schema = entry.value;

      final code = generateDomainEntity(className, schema);
      
      // Определяем папку для сущности так же, как для моделей
      final entityFolder = baseModels.contains(className) 
          ? 'base' 
          : (modelUsage[className]?.first ?? 'base');
      
      // Сохраняем сущность в соответствующую папку
      await writeFile('$outputPath/entities/$entityFolder/${ReCase(className).snakeCase}_entity.dart', code);
    }
  }

  bool isModel(String name, YamlMap schema) {
    // Проверяем наличие properties или allOf/oneOf
    // Добавляем проверку для массивов с объектами
    return schema.containsKey('properties') ||
        schema.containsKey('allOf') ||
        schema.containsKey('oneOf') ||
        (schema['type'] == 'array' && 
         schema['items'] != null && 
         schema['items'] is Map && 
         schema['items'].containsKey('properties'));
  }

  String generateDataModel(String className, YamlMap schema) {
    final buffer = StringBuffer();
    final rc = ReCase(className);

    // Imports
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");

    // Добавляем импорты для вложенных моделей
    final nestedModels = _findNestedModels(schema);
    final addedImports = <String>{};
    for (final model in nestedModels) {
      if (model != className) {
        final importPath = _getModelImportPath(className, model);
        if (!addedImports.contains(importPath)) {
          buffer.writeln(importPath);
          addedImports.add(importPath);
        }
      }
    }

    buffer.writeln();
    buffer.writeln("part '${rc.snakeCase}.g.dart';");
    buffer.writeln();

    // Class documentation
    if (schema['description'] != null) {
      buffer.writeln('/// ${Utils.cleanDescription(schema['description'])}');
    }

    // Class declaration
    buffer.writeln('@JsonSerializable()');
    buffer.writeln('class ${rc.pascalCase} {');

    // Если это массив с объектами, генерируем поля из items.properties
    if (schema['type'] == 'array' && schema['items']?['properties'] != null) {
      _generateProperties(
        buffer,
        schema['items']['properties'],
        _ensureListType(schema['items']['required']),
      );
    } else {
      // Обычная обработка для не-массивов
      try {
        if (schema.containsKey('allOf')) {
          _generateAllOfProperties(buffer, schema['allOf']);
        } else if (schema.containsKey('oneOf')) {
          _generateOneOfProperties(buffer, schema['oneOf'], rc.pascalCase);
        } else if (schema.containsKey('properties')) {
          _generateProperties(
            buffer,
            schema['properties'],
            _ensureListType(schema['required']),
          );
        }
      } catch (e) {
        print('Warning: Error generating model $className: $e');
      }
    }

    // Constructor
    _generateConstructor(buffer, rc.pascalCase, schema);

    // fromJson
    buffer.writeln(
        '  factory ${rc.pascalCase}.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${rc.pascalCase}FromJson(json);');
    buffer.writeln();

    // toJson
    buffer.writeln(
        '  Map<String, dynamic> toJson() => _\$${rc.pascalCase}ToJson(this);');

    buffer.writeln('}');

    return buffer.toString();
  }
  String generateDomainEntity(String className, YamlMap schema) {
    final buffer = StringBuffer();
    final rc = ReCase(className);

    // Class documentation
    if (schema['description'] != null) {
      buffer.writeln('/// ${Utils.cleanDescription(schema['description'])}');
    }

    // Class declaration
    buffer.writeln('class ${rc.pascalCase}Entity {');

    // Fields
    if (schema['type'] == 'array' && schema['items']?['properties'] != null) {
      _generateEntityProperties(
        buffer,
        schema['items']['properties'],
        _ensureListType(schema['items']['required']),
      );
    } else if (schema.containsKey('properties')) {
      _generateEntityProperties(
        buffer,
        schema['properties'],
        _ensureListType(schema['required']),
      );
    } else if (schema.containsKey('allOf')) {
      _generateEntityAllOfProperties(buffer, schema['allOf']);
    }

    // Constructor
    _generateEntityConstructor(buffer, rc.pascalCase, schema);

    buffer.writeln('}');

    return buffer.toString();
  }

  void _generateEntityProperties(
      StringBuffer buffer, Map properties, List<String> required) {
    for (final property in properties.entries) {
      try {
        final fieldName = property.key;
        final fieldSchema = property.value;
        final camelCaseFieldName = ReCase(fieldName).camelCase;

        if (fieldSchema is! Map) {
          print('Warning: Field schema for $fieldName is not a Map, skipping...');
          continue;
        }

        if (fieldSchema['description'] != null) {
          buffer.writeln(
              '  /// ${Utils.cleanDescription(fieldSchema['description'])}');
        }

        final fieldType = _resolveEntityFieldType(fieldSchema);
        buffer.writeln('  final $fieldType $camelCaseFieldName;');
        buffer.writeln();
      } catch (e) {
        print('Warning: Error generating property ${property.key}: $e');
      }
    }
  }

  void _generateEntityAllOfProperties(StringBuffer buffer, List allOf) {
    for (final schema in allOf) {
      if (schema.containsKey('\$ref')) {
        final refModel = schema['\$ref'].split('/').last;
        buffer.writeln('  // Properties from $refModel');
        final refSchema = yaml['components']['schemas'][refModel];
        _generateEntityProperties(
            buffer, refSchema['properties'], refSchema['required'] ?? []);
      } else if (schema.containsKey('properties')) {
        _generateEntityProperties(
            buffer, schema['properties'], schema['required'] ?? []);
      }
    }
  }

  void _generateEntityConstructor(StringBuffer buffer, String className, YamlMap schema) {
    buffer.writeln('  ${className}Entity({');

    void addConstructorParams(Map properties, List required) {
      for (final property in properties.entries) {
        final fieldName = property.key;
        final camelCaseFieldName = ReCase(fieldName).camelCase;
        final isRequired = required.contains(fieldName);
        buffer.write(isRequired ? '    required ' : '    ');
        buffer.writeln('this.$camelCaseFieldName,');
      }
    }

    if (schema['type'] == 'array' && schema['items']?['properties'] != null) {
      addConstructorParams(
        schema['items']['properties'],
        _ensureListType(schema['items']['required']),
      );
    } else if (schema.containsKey('properties')) {
      addConstructorParams(schema['properties'], schema['required'] ?? []);
    } else if (schema.containsKey('allOf')) {
      for (final subSchema in schema['allOf']) {
        if (subSchema.containsKey('\$ref')) {
          final refModel = subSchema['\$ref'].split('/').last;
          final refSchema = yaml['components']['schemas'][refModel];
          addConstructorParams(
              refSchema['properties'], refSchema['required'] ?? []);
        } else if (subSchema.containsKey('properties')) {
          addConstructorParams(
              subSchema['properties'], subSchema['required'] ?? []);
        }
      }
    }

    buffer.writeln('  });');
    buffer.writeln();
  }

  String _resolveEntityFieldType(Map schema) {
    if (schema.containsKey('\$ref')) {
      final refModel = schema['\$ref'].split('/').last;
      final refSchema = _getSchemaByRef(schema['\$ref']);

      if (refSchema != null && refSchema['type'] == 'array') {
        final itemsSchema = refSchema['items'];
        if (itemsSchema != null) {
          if (itemsSchema['\$ref'] != null) {
            final itemRefModel = itemsSchema['\$ref'].split('/').last;
            return 'List<${itemRefModel}Entity>';
          }
          return 'List<${Utils.typeFromSchema(itemsSchema, nullable: false)}>';
        }
        return 'List<${refModel}Entity>';
      }

      return '${refModel}Entity';
    }

    if (schema['type'] == 'array') {
      final itemsSchema = schema['items'];
      if (itemsSchema != null) {
        if (itemsSchema['\$ref'] != null) {
          final refModel = itemsSchema['\$ref'].split('/').last;
          return 'List<${refModel}Entity>';
        }
        return 'List<${Utils.typeFromSchema(itemsSchema, nullable: false)}>';
      }
      return 'List<dynamic>';
    }

    return Utils.typeFromSchema(schema, nullable: true);
  }

  Set<String> _findNestedModels(YamlMap schema) {
    final nestedModels = <String>{};

    void processSchema(dynamic schema) {
      if (schema is! Map) return;

      if (schema.containsKey('\$ref')) {
        final ref = schema['\$ref'] as String;
        final modelName = ref.split('/').last;
        nestedModels.add(modelName);
        
        // Проверяем, является ли referenced схема массивом
        final refSchema = _getSchemaByRef(schema['\$ref']);
        if (refSchema != null && refSchema['type'] == 'array') {
          if (refSchema['items'] != null) {
            processSchema(refSchema['items']);
          }
        }
      }

      // Обрабатываем массивы
      if (schema['type'] == 'array' && schema['items'] != null) {
        processSchema(schema['items']);
      }

      // Рекурсивно обрабатываем свойства
      if (schema.containsKey('properties')) {
        for (final property in schema['properties'].values) {
          processSchema(property);
        }
      }

      // Обрабатываем allOf/oneOf
      for (final key in ['allOf', 'oneOf']) {
        if (schema.containsKey(key)) {
          for (final subSchema in schema[key]) {
            processSchema(subSchema);
          }
        }
      }
    }

    processSchema(schema);
    return nestedModels;
  }

  void _generateAllOfProperties(StringBuffer buffer, List allOf) {
    for (final schema in allOf) {
      if (schema.containsKey('\$ref')) {
        final refModel = schema['\$ref'].split('/').last;
        buffer.writeln('  // Properties from $refModel');
        final refSchema = yaml['components']['schemas'][refModel];
        _generateProperties(
            buffer, refSchema['properties'], refSchema['required'] ?? []);
      } else if (schema.containsKey('properties')) {
        _generateProperties(
            buffer, schema['properties'], schema['required'] ?? []);
      }
    }
  }

  void _generateOneOfProperties(StringBuffer buffer, dynamic oneOf, String className) {
    if (oneOf is! List) return;

    // Создаем абстрактный базовый класс
    buffer.writeln('abstract class $className {');

    // Добавляем поле type для различения типов
    buffer.writeln('  @JsonKey(name: "type")');
    buffer.writeln('  final String type;');
    buffer.writeln();

    // Конструктор
    buffer.writeln('  const $className({required this.type});');

    // Фабричный метод fromJson
    buffer.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    switch(json["type"]) {');

    // Генерируем case для каждого типа
    for (final schema in oneOf) {
      if (schema is! Map || !schema.containsKey('\$ref')) continue;
      final refModel = schema['\$ref'].split('/').last;
      buffer.writeln('      case "$refModel":');
      buffer.writeln('        return ${refModel}.fromJson(json);');
    }

    buffer.writeln('      default:');
    buffer.writeln('        throw Exception("Unknown type: \${json["type"]}");');
    buffer.writeln('    }');
    buffer.writeln('  }');

    buffer.writeln('  Map<String, dynamic> toJson();');
    buffer.writeln('}');

    // Генерируем классы-наследники
    for (final schema in oneOf) {
      if (schema is! Map || !schema.containsKey('\$ref')) continue;
      final refPath = schema['\$ref'];
      final refModel = refPath.split('/').last;
      final refSchema = _getSchemaByRef(refPath);

      if (refSchema != null) {
        // Определяем папку для модели на основе существующей логики
        final modelFolder = baseModels.contains(refModel) 
            ? 'base' 
            : (modelUsage[refModel]?.first ?? 'base');

        _generateOneOfChild(refModel, className, refSchema, modelFolder);
      }
    }
  }

  void _generateOneOfChild(String className, String parentClass, Map schema, String folder) {
    final buffer = StringBuffer();
    final importedModels = <String>{};

    // Собираем все вложенные модели
    _findNestedModels(schema as YamlMap).forEach((model) {
      if (model != className) {
        final modelFolder = baseModels.contains(model) 
            ? 'base' 
            : (modelUsage[model]?.first ?? 'base');
        importedModels.add("import '../$modelFolder/${ReCase(model).snakeCase}.dart';");
      }
    });

    // Imports
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
    // Импортируем базовый класс с учетом относительного пути
    if (folder == 'base') {
      buffer.writeln("import '${ReCase(parentClass).snakeCase}.dart';");
    } else {
      buffer.writeln("import '../base/${ReCase(parentClass).snakeCase}.dart';");
    }
    // Добавляем собранные импорты
    importedModels.forEach(buffer.writeln);

    buffer.writeln();
    buffer.writeln("part '${ReCase(className).snakeCase}.g.dart';");
    buffer.writeln();

    // Class declaration
    buffer.writeln('@JsonSerializable()');
    buffer.writeln('class $className extends $parentClass {');

    // Fields
    if (schema['properties'] != null) {
      _generateProperties(buffer, schema['properties'], 
          schema['required'] != null ? _ensureListType(schema['required']) : []);
    }

    // Constructor
    buffer.writeln('  $className({');
    buffer.writeln('    required super.type,');
    // Add constructor parameters
    if (schema['properties'] != null) {
      for (final property in schema['properties'].entries) {
        final fieldName = property.key;
        final camelCaseFieldName = ReCase(fieldName).camelCase;
        final isRequired = schema['required'] != null && 
            _ensureListType(schema['required']).contains(fieldName);
        if (isRequired) {
          buffer.writeln('    required this.$camelCaseFieldName,');
        } else {
          buffer.writeln('    this.$camelCaseFieldName,');
        }
      }
    }
    buffer.writeln('  });');

    // fromJson
    buffer.writeln('  factory $className.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${className}FromJson(json);');

    // toJson
    buffer.writeln('  @override');
    buffer.writeln('  Map<String, dynamic> toJson() => _\$${className}ToJson(this);');

    buffer.writeln('}');

    // Write to file в правильную папку с правильным путем
    writeFile('$outputPath/data/models/$folder/${ReCase(className).snakeCase}.dart', buffer.toString());
  }

  void _generateOneOfBaseClass(String baseClassName, List<dynamic> oneOfSchemas) {
    final buffer = StringBuffer();
    
    // Imports
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
    
    // Собираем импорты для всех наследников
    for (final schema in oneOfSchemas) {
      if (schema is! Map || !schema.containsKey('\$ref')) continue;
      final refModel = schema['\$ref'].split('/').last;
      final modelFolder = baseModels.contains(refModel) 
          ? 'base' 
          : (modelUsage[refModel]?.first ?? 'base');
      if (modelFolder == 'base') {
        buffer.writeln("import '${ReCase(refModel).snakeCase}.dart';");
      } else {
        buffer.writeln("import '../$modelFolder/${ReCase(refModel).snakeCase}.dart';");
      }
    }

    buffer.writeln();
    buffer.writeln("part '${ReCase(baseClassName).snakeCase}.g.dart';");
    buffer.writeln();
    
    // Генерируем базовый абстрактный класс
    buffer.writeln('@JsonSerializable()');
    buffer.writeln('abstract class $baseClassName {');
    buffer.writeln('  final String type;');
    buffer.writeln();
    buffer.writeln('  $baseClassName({required this.type});');
    buffer.writeln();
    buffer.writeln('  factory $baseClassName.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    switch(json["type"]) {');

    // Генерируем case для каждого типа
    for (final schema in oneOfSchemas) {
      if (schema is! Map || !schema.containsKey('\$ref')) continue;
      final refModel = schema['\$ref'].split('/').last;
      buffer.writeln('      case "$refModel":');
      buffer.writeln('        return ${refModel}.fromJson(json);');
    }

    buffer.writeln('      default:');
    buffer.writeln('        throw Exception("Unknown type: \${json["type"]}");');
    buffer.writeln('    }');
    buffer.writeln('  }');

    buffer.writeln('  Map<String, dynamic> toJson();');
    buffer.writeln('}');

    // Записываем базовый класс в правильную папку с правильным путем
    writeFile('$outputPath/data/models/$baseFolder/${ReCase(baseClassName).snakeCase}.dart', buffer.toString());

    // Генерируем классы-наследники
    for (final schema in oneOfSchemas) {
      if (schema is! Map || !schema.containsKey('\$ref')) continue;
      final refPath = schema['\$ref'];
      final refModel = refPath.split('/').last;
      final refSchema = _getSchemaByRef(refPath);

      if (refSchema != null) {
        // Определяем папку для модели на основе существующей логики
        final modelFolder = baseModels.contains(refModel) 
            ? 'base' 
            : (modelUsage[refModel]?.first ?? 'base');

        _generateOneOfChild(refModel, baseClassName, refSchema, modelFolder);
        // Добавляем модель в список сгенерированных
        generatedModels.add(refModel);
      }
    }
  }

  // Преобразуем required в List<String> безопасно
  List<String> _ensureListType(dynamic required) {
    if (required is YamlList) {
      return required.map((e) => e.toString()).toList();
    }
    if (required is List) {
      return required.map((e) => e.toString()).toList();
    }
    return [];
  }

  void _generateProperties(
      StringBuffer buffer, Map properties, List<String> required,
      {bool nullable = true}) { // Изменено значение по умолчанию на true
    for (final property in properties.entries) {
      try {
        final fieldName = property.key;
        final fieldSchema = property.value;
        final camelCaseFieldName = ReCase(fieldName).camelCase;

        if (fieldSchema is! Map) {
          print(
              'Warning: Field schema for $fieldName is not a Map, skipping...');
          continue;
        }

        if (fieldSchema['description'] != null) {
          buffer.writeln(
              '  /// ${Utils.cleanDescription(fieldSchema['description'])}');
        }

        // Всегда добавляем JsonKey с оригинальным именем поля
        buffer.writeln('  @JsonKey(name: "$fieldName")');

        final fieldType = _resolveFieldType(fieldSchema, nullable);
        buffer.writeln('  final $fieldType $camelCaseFieldName;');
        buffer.writeln();
      } catch (e) {
        print('Warning: Error generating property ${property.key}: $e');
      }
    }
  }

  String _resolveFieldType(Map schema, bool isNullable) {
    // Если есть прямая ссылка на другую схему
    if (schema.containsKey('\$ref')) {
      final refModel = schema['\$ref'].split('/').last;
      final refSchema = _getSchemaByRef(schema['\$ref']);
      
      // Проверяем, является ли referenced схема массивом
      if (refSchema != null && refSchema['type'] == 'array') {
        final itemsSchema = refSchema['items'];
        if (itemsSchema != null) {
          // Если items содержит properties напрямую
          if (itemsSchema['properties'] != null) {
            return 'List<$refModel>${isNullable ? '?' : ''}';
          }
          // Если items содержит ссылку
          else if (itemsSchema['\$ref'] != null) {
            final itemRefModel = itemsSchema['\$ref'].split('/').last;
            return 'List<$itemRefModel>${isNullable ? '?' : ''}';
          }
          // Если items содержит прямое определение типа
          else {
            final itemType = Utils.typeFromSchema(itemsSchema, nullable: false);
            return 'List<$itemType>${isNullable ? '?' : ''}';
          }
        }
        return 'List<$refModel>${isNullable ? '?' : ''}';
      }
      
      return '$refModel${isNullable ? '?' : ''}';
    }
    
    // Если это напрямую определенный массив
    if (schema['type'] == 'array') {
      final itemsSchema = schema['items'];
      if (itemsSchema != null) {
        // Если items содержит properties напрямую
        if (itemsSchema['properties'] != null) {
          // Здесь нужно использовать имя текущей модели
          final modelName = schema['title'] ?? 'Item'; // Используем title или дефолтное имя
          return 'List<$modelName>${isNullable ? '?' : ''}';
        }
        // Если items содержит ссылку
        else if (itemsSchema['\$ref'] != null) {
          final refModel = itemsSchema['\$ref'].split('/').last;
          return 'List<$refModel>${isNullable ? '?' : ''}';
        }
        // Если items содержит прямое определение типа
        else {
          final itemType = Utils.typeFromSchema(itemsSchema, nullable: false);
          return 'List<$itemType>${isNullable ? '?' : ''}';
        }
      }
      return 'List<dynamic>${isNullable ? '?' : ''}';
    }

    return Utils.typeFromSchema(schema, nullable: isNullable);
  }

  void _generateConstructor(StringBuffer buffer, String className, YamlMap schema) {
    buffer.writeln('  $className({');

    void addConstructorParams(Map properties, List required) {
      for (final property in properties.entries) {
        final fieldName = property.key;
        final camelCaseFieldName = ReCase(fieldName).camelCase;
        final isRequired = required.contains(fieldName);
        buffer.write(isRequired ? '    required ' : '    ');
        buffer.writeln('this.$camelCaseFieldName,');
      }
    }

    // Проверяем, является ли это массивом с объектами
    if (schema['type'] == 'array' && schema['items']?['properties'] != null) {
      addConstructorParams(
        schema['items']['properties'],
        _ensureListType(schema['items']['required']),
      );
    } else if (schema.containsKey('allOf')) {
      for (final subSchema in schema['allOf']) {
        if (subSchema.containsKey('\$ref')) {
          final refModel = subSchema['\$ref'].split('/').last;
          final refSchema = yaml['components']['schemas'][refModel];
          addConstructorParams(
              refSchema['properties'], refSchema['required'] ?? []);
        } else if (subSchema.containsKey('properties')) {
          addConstructorParams(
              subSchema['properties'], subSchema['required'] ?? []);
        }
      }
    } else if (schema.containsKey('oneOf')) {
      buffer.writeln('    required this.type,');
      for (final subSchema in schema['oneOf']) {
        if (subSchema.containsKey('\$ref')) {
          final refModel = subSchema['\$ref'].split('/').last;
          final refSchema = yaml['components']['schemas'][refModel];
          addConstructorParams(
              refSchema['properties'], []); // все поля nullable
        } else if (subSchema.containsKey('properties')) {
          addConstructorParams(
              subSchema['properties'], []); // все поля nullable
        }
      }
    } else if (schema.containsKey('properties')) {
      addConstructorParams(schema['properties'], schema['required'] ?? []);
    }

    buffer.writeln('  });');
    buffer.writeln();
  }

  String _generateOperationId(String path, String method) {
    // Убираем начальный слэш
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    // Разбиваем путь на части
    final parts = cleanPath.split('/');
    // Берем последнюю значимую часть пути
    String operationName = parts.last;
    // Если часть содержит параметр в фигурных скобках, берем предыдущую часть
    if (operationName.startsWith('{') && operationName.endsWith('}')) {
      operationName = parts[parts.length - 2];
    }
    // Возвращаем имя в camelCase без метода HTTP
    return ReCase(operationName).camelCase;
  }

  String generateRetrofitClient(YamlMap paths) {
    final buffer = StringBuffer();
    final importedModels = <String>{};

    // Базовые импорты
    buffer.writeln("import 'package:dio/dio.dart';");
    buffer.writeln("import 'package:retrofit/retrofit.dart';");

    // Импортируем все используемые модели
    for (final entry in paths.entries) {
      final methods = entry.value as Map;
      for (final method in methods.entries) {
        final operation = method.value;
        final path = entry.key;
        final httpMethod = method.key.toUpperCase();
        
        // Анализируем request body
        if (operation['requestBody'] != null) {
          final jsonSchema = operation['requestBody']['content']['application/json']?['schema'];
          final multipartSchema = operation['requestBody']['content']['multipart/form-data']?['schema'];
          
          if (jsonSchema != null) {
            _addImportedModels(jsonSchema, importedModels);
          }
          if (multipartSchema != null) {
            _addImportedModels(multipartSchema, importedModels);
            // Добавляем импорт базового класса для oneOf с правильным именем
            if (multipartSchema['properties']?['data']?['oneOf'] != null) {
              final methodName = _generateOperationId(path, httpMethod);
              final baseClassName = '${ReCase(methodName).pascalCase}DataModel';
              final modelFolder = baseModels.contains(baseClassName) 
                  ? 'base' 
                  : (modelUsage[baseClassName]?.first ?? 'base');
              buffer.writeln("import 'models/$modelFolder/${ReCase(baseClassName).snakeCase}.dart';");
            }
          }
        }

        // Анализируем response
        if (operation['responses']?['200']?['content']?['application/json']?['schema'] != null) {
          final schema = operation['responses']['200']['content']['application/json']['schema'];
          _addImportedModels(schema, importedModels);
        }
      }
    }

    // Генерируем импорты для всех используемых моделей
    for (final model in importedModels) {
      final modelFolder = baseModels.contains(model) 
          ? 'base' 
          : (modelUsage[model]?.first ?? 'base');
      buffer.writeln("import 'models/$modelFolder/${ReCase(model).snakeCase}.dart';");
    }

    buffer.writeln();
    buffer.writeln("part 'api_client.g.dart';");
    buffer.writeln();

    // Client class
    buffer.writeln('@RestApi()');
    buffer.writeln('abstract class ApiClient {');
    buffer.writeln('  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;');
    buffer.writeln();

    // Generate methods for each path
    for (final entry in paths.entries) {
      final path = entry.key;
      final methods = entry.value as Map;

      for (final method in methods.entries) {
        final httpMethod = method.key.toUpperCase();
        final operation = method.value;

        final operationId = _generateOperationId(path, httpMethod);
        final returnType = _getResponseType(operation['responses']);

        // Method documentation
        if (operation['description'] != null) {
          buffer.writeln('  /// ${Utils.cleanDescription(operation['description'])}');
        }

        // Method declaration
        buffer.writeln('  @$httpMethod("$path")');
        buffer.write('  Future<$returnType> $operationId(');

        // Используем _generateMethodParameters с путем и методом
        final parameters = _generateMethodParameters(operation, path: path, httpMethod: httpMethod);
        if (parameters.isNotEmpty) {
          buffer.writeln();
          buffer.write(parameters);
        }

        buffer.writeln('  );');
        buffer.writeln();
      }
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  void _addImportedModels(dynamic schema, Set<String> importedModels) {
    if (schema == null) return;

    if (schema['\$ref'] != null) {
      final modelName = schema['\$ref'].split('/').last;
      importedModels.add(modelName);

      // Рекурсивно добавляем вложенные модели
      final modelSchema = _getSchemaByRef(schema['\$ref']);
      if (modelSchema != null) {
        if (modelSchema['properties'] != null) {
          for (final prop in modelSchema['properties'].values) {
            _addImportedModels(prop, importedModels);
          }
        }
        if (modelSchema['items'] != null) {
          _addImportedModels(modelSchema['items'], importedModels);
        }
        if (modelSchema['allOf'] != null) {
          for (final subSchema in modelSchema['allOf']) {
            _addImportedModels(subSchema, importedModels);
          }
        }
        if (modelSchema['oneOf'] != null) {
          for (final subSchema in modelSchema['oneOf']) {
            _addImportedModels(subSchema, importedModels);
          }
        }
      }
    }

    // Обрабатываем массивы и вложенные объекты
    if (schema['items'] != null) {
      _addImportedModels(schema['items'], importedModels);
    }
    if (schema['properties'] != null) {
      for (final prop in schema['properties'].values) {
        _addImportedModels(prop, importedModels);
      }
    }
    if (schema['allOf'] != null) {
      for (final subSchema in schema['allOf']) {
        _addImportedModels(subSchema, importedModels);
      }
    }
    if (schema['oneOf'] != null) {
      for (final subSchema in schema['oneOf']) {
        _addImportedModels(subSchema, importedModels);
      }
    }
  }

  Future<void> writeFile(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  void _analyzeModelUsage(YamlMap paths) {
    for (final pathEntry in paths.entries) {
      final path = pathEntry.key;
      final methods = pathEntry.value as Map;
      for (final methodEntry in methods.entries) {
        final httpMethod = methodEntry.key.toUpperCase();
        final operation = methodEntry.value;
        final operationId = _generateOperationId(path, httpMethod);
        
        // Используем operationId как имя папки без преобразований
        final methodFolder = operationId;

        // Создаем группу для связанных моделей
        final relatedModels = <String>{};

        // Анализируем request body
        if (operation['requestBody'] != null) {
          final schema = operation['requestBody']['content']['application/json']?['schema'];
          final multipartSchema = operation['requestBody']['content']['multipart/form-data']?['schema'];
          
          if (schema != null) {
            _addModelUsageRecursive(schema, methodFolder, relatedModels);
          }
          if (multipartSchema != null) {
            _addModelUsageRecursive(multipartSchema, methodFolder, relatedModels);
            
            // Если есть oneOf, добавляем все модели из него в ту же папку
            if (multipartSchema['properties']?['data']?['oneOf'] != null) {
              for (final oneOfSchema in multipartSchema['properties']['data']['oneOf']) {
                if (oneOfSchema['\$ref'] != null) {
                  final refModel = oneOfSchema['\$ref'].split('/').last;
                  relatedModels.add(refModel);
                }
              }
            }
          }
        }

        // Анализируем response
        if (operation['responses']?['200']?['content']?['application/json']?['schema'] != null) {
          final schema = operation['responses']['200']['content']['application/json']['schema'];
          _addModelUsageRecursive(schema, methodFolder, relatedModels);
        }

        // Добавляем все связанные модели в папку метода
        for (final model in relatedModels) {
          if (!baseModels.contains(model)) {
            modelUsage.putIfAbsent(model, () => {}).add(methodFolder);
          }
        }
      }
    }
  }

  void _addModelUsageRecursive(dynamic schema, String methodFolder, Set<String> relatedModels) {
    if (schema == null) return;

    if (schema['\$ref'] != null) {
      final modelName = schema['\$ref'].split('/').last;
      if (!baseModels.contains(modelName)) {
        relatedModels.add(modelName);
      }

      // Получаем схему модели и проверяем, является ли она массивом
      final modelSchema = _getSchemaByRef(schema['\$ref']);
      if (modelSchema != null) {
        if (modelSchema['type'] == 'array' && modelSchema['items'] != null) {
          _addModelUsageRecursive(modelSchema['items'], methodFolder, relatedModels);
        }
        if (modelSchema['properties'] != null) {
          for (final prop in modelSchema['properties'].values) {
            _addModelUsageRecursive(prop, methodFolder, relatedModels);
          }
        }
        if (modelSchema['items'] != null) {
          _addModelUsageRecursive(modelSchema['items'], methodFolder, relatedModels);
        }
        if (modelSchema['allOf'] != null) {
          for (final subSchema in modelSchema['allOf']) {
            _addModelUsageRecursive(subSchema, methodFolder, relatedModels);
          }
        }
        if (modelSchema['oneOf'] != null) {
          for (final subSchema in modelSchema['oneOf']) {
            _addModelUsageRecursive(subSchema, methodFolder, relatedModels);
          }
        }
      }
    }

    // Обрабатываем массивы
    if (schema['type'] == 'array' && schema['items'] != null) {
      _addModelUsageRecursive(schema['items'], methodFolder, relatedModels);
    }

    // Обрабатываем свойства
    if (schema['properties'] != null) {
      for (final prop in schema['properties'].values) {
        _addModelUsageRecursive(prop, methodFolder, relatedModels);
      }
    }

    // Обрабатываем allOf/oneOf
    if (schema['allOf'] != null) {
      for (final subSchema in schema['allOf']) {
        _addModelUsageRecursive(subSchema, methodFolder, relatedModels);
      }
    }
    if (schema['oneOf'] != null) {
      for (final subSchema in schema['oneOf']) {
        _addModelUsageRecursive(subSchema, methodFolder, relatedModels);
      }
    }
  }

  String _getModelImportPath(String currentModel, String importedModel) {
    if (baseModels.contains(importedModel)) {
      return "import '../base/${ReCase(importedModel).snakeCase}.dart';";
    }

    final currentModelFolder = modelUsage[currentModel]?.first ?? 'base';
    final importedModelFolder = modelUsage[importedModel]?.first ?? 'base';

    if (currentModelFolder == importedModelFolder) {
      return "import '${ReCase(importedModel).snakeCase}.dart';";
    } else {
      return "import '../$importedModelFolder/${ReCase(importedModel).snakeCase}.dart';";
    }
  }

  Map<dynamic, dynamic>? _getSchemaByRef(String ref) {
    final parts = ref.split('/');
    if (parts.length < 4) return null;

    try {
      final schemas = yaml['components']?['schemas'];
      if (schemas is Map) {
        final modelName = parts.last;
        final schema = schemas[modelName];
        if (schema is Map) {
          return schema;
        }
      }
    } catch (e) {
      print('Warning: Error getting schema by ref $ref: $e');
    }
    return null;
  }

  String _generateMethodParameters(Map operation, {String path = '', String httpMethod = ''}) {
    final buffer = StringBuffer();
    
    if (operation['requestBody'] != null) {
      final content = operation['requestBody']['content'];
      
      // Обработка multipart/form-data
      if (content['multipart/form-data'] != null) {
        final schema = content['multipart/form-data']['schema'];
        
        // Обработка полей формы
        if (schema['properties'] != null) {
          for (final prop in schema['properties'].entries) {
            final fieldName = prop.key;
            final fieldSchema = prop.value;
            
            // Обработка oneOf
            if (fieldSchema['oneOf'] != null) {
              // Генерируем имя базового класса на основе пути и метода
              final methodName = _generateOperationId(path, httpMethod);
              final baseClassName = '${ReCase(methodName).pascalCase}${ReCase(fieldName).pascalCase}Model';
              
              // Генерируем базовый класс и его наследников
              _generateOneOfBaseClass(baseClassName, fieldSchema['oneOf']);
              
              // Используем сгенерированный базовый класс
              buffer.write('@Body() $baseClassName ${ReCase(fieldName).camelCase}, ');
            }
            // Обработка массивов файлов
            else if (fieldSchema['type'] == 'array' && 
                    fieldName.endsWith('[]')) {
              final baseName = fieldName.substring(0, fieldName.length - 2);
              buffer.write('@Part() List<MultipartFile>? ${ReCase(baseName).camelCase}, ');
            }
          }
        }
      }
      // Обработка application/json
      else if (content['application/json'] != null) {
        final schema = content['application/json']['schema'];
        if (schema['\$ref'] != null) {
          final refModel = schema['\$ref'].split('/').last;
          buffer.write('@Body() $refModel request,');
        }
      }
    }

    return buffer.toString();
  }
}

class Utils {
  static String typeFromSchema(dynamic schema, {bool nullable = true}) {
    if (schema is! Map) return 'dynamic';

    final type = schema['type'];
    final format = schema['format'];
    final nullableSuffix = nullable ? '?' : '';

    switch (type) {
      case 'string':
        return 'String$nullableSuffix';
      case 'integer':
      case 'number':
        if (format == 'double') return 'double$nullableSuffix';
        return 'int$nullableSuffix';
      case 'boolean':
        return 'bool$nullableSuffix';
      case 'array':
        final itemsType = typeFromSchema(schema['items'], nullable: false);
        return 'List<$itemsType>$nullableSuffix';
      case 'object':
        return 'Map<String, dynamic>$nullableSuffix';
      default:
        return 'dynamic';
    }
  }

  static String cleanDescription(String? description) {
    if (description == null) return '';
    return description
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', ' ');
  }

  static bool isRequired(Map schema, String propertyName) {
    final required = schema['required'];
    return required is List && required.contains(propertyName);
  }
}

String _getResponseType(Map responses) {
  final ok = responses['200'];
  if (ok == null) return 'void';

  final content = ok['content'];
  if (content == null) return 'void';

  final schema = content['application/json']['schema'];
  if (schema == null) return 'void';

  // Обработка oneOf
  if (schema.containsKey('oneOf')) {
    final types = schema['oneOf'] as List;
    for (final type in types) {
      if (type['\$ref'] != null) {
        final refModel = type['\$ref'].split('/').last;
        if (refModel != 'ErrorResponse') {
          return refModel;
        }
      }
    }
    return 'void';
  }

  // Обработка обычной схемы
  if (schema['\$ref'] != null) {
    final refModel = schema['\$ref'].split('/').last;
    return refModel;
  }

  return Utils.typeFromSchema(schema);
}