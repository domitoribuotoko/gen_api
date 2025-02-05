import 'dart:io';
import 'package:gen_yaml/codegenerator/utils/support_classes.dart';
import 'package:recase/recase.dart';

class Printer {
  final List<ApiMethod> _methods;
  final List<ApiModel> _models;
  final String _basePath = 'lib/generated';

  Printer({
    required List<ApiMethod> methods,
    required List<ApiModel> models,
  })  : _methods = methods,
        _models = models {
    _print();
  }

  Future<void> _print() async {
    await _createDirectories();
    await _generateModels();
    await _generateApiClient();
  }

  Future<void> _createDirectories() async {
    final directories = <String>{};

    // Создаем директории для каждого тега
    final tags = _methods
        .expand((method) => method.tags.isEmpty ? ['_untagged'] : [method.tags.first.snakeCase])
        .toSet();
    
    for (final tag in tags) {
      directories.add('$_basePath/data/models/$tag');
    }

    // Создаем директории для методов внутри соответствующих тегов, только если они не пустые
    for (final method in _methods) {
      final tag = method.tags.isNotEmpty ? method.tags.first.snakeCase : '_untagged';
      final methodDir = method.methodName.snakeCase;
      if (!(method.request is EmptyModel) || !(method.response is EmptyModel)) {
        directories.add('$_basePath/data/models/$tag/$methodDir');
      }
    }

    for (final dir in directories) {
      await Directory(dir).create(recursive: true);
    }
  }

  Future<void> _generateModels() async {
    final processedModels = <String>{};

    // First generate base models (used more than once)
    for (final method in _methods) {
      await _processModel(method.request, processedModels);
      await _processModel(method.response, processedModels);
    }
  }

  Future<void> _processModel(ApiModel model, Set<String> processedModels) async {
    if (model is EmptyModel || processedModels.contains(model.name)) return;

    print('=== Processing model: ${model.name} ===');

    // Process parent model first if exists
    if (model.superModel != null) {
      print('Found superModel: ${model.superModel!.name}');
      await _processModel(model.superModel!, processedModels);
    }

    // Process nested models in fields
    for (final field in model.fields) {
      print('- Field: ${field.name}, Type: ${field.type}, Model: ${field.model?.name}');
      if (field.model != null && !processedModels.contains(field.model!.name)) {
        print('  Processing nested model: ${field.model!.name}');
        await _processModel(field.model!, processedModels);
      }
    }

    // Write model to appropriate location
    await _writeModelToLocation(model, processedModels);
    processedModels.add(model.name);
  }

  Future<void> _writeModelToLocation(ApiModel model, Set<String> processedModels) async {
    print('Writing model: ${model.name}');
    final uniqueUsages = model.usages.toSet();

    if (uniqueUsages.length > 1) {
      print('Model ${model.name} has multiple unique usages, writing to _base');
      await Directory('$_basePath/data/models/_base').create(recursive: true);
      await _writeModelToFile(
        model,
        '$_basePath/data/models/_base/${model.name.snakeCase}.dart',
      );
    } else {
      final method = _findMethodForModel(model);
      if (method != null) {
        final tag = method.tags.isNotEmpty ? method.tags.first.snakeCase : '_untagged';
        final methodDir = method.methodName.snakeCase;
        final isRequest = method.request.name == model.name;
        final fileName = isRequest ? 'request.dart' : 'response.dart';
        print('Writing model ${model.name} to method directory: $methodDir');
        await _writeModelToFile(
          model,
          '$_basePath/data/models/$tag/$methodDir/$fileName',
        );
      } else {
        print('No method found for model: ${model.name}, embedding in response file');
        // Embed the model directly in the response file
        final responseFilePath = '$_basePath/data/models/tasks/task_details/response.dart';
        await _embedModelInFile(model, responseFilePath);
      }
    }
  }

  Future<void> _embedModelInFile(ApiModel model, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      print('File $filePath does not exist. Creating a new file.');
      await file.create(recursive: true);
    }

    final content = await file.readAsString();
    final modelDefinition = _generateModelDefinition(model);

    // Check if the model is already embedded
    if (content.contains('class ${model.name}')) {
      print('Model ${model.name} is already embedded in $filePath.');
      return;
    }

    // Embed the model definition at the end of the file
    final updatedContent = '$content\n\n$modelDefinition';
    await file.writeAsString(updatedContent);
    print('Embedded model ${model.name} directly in file: $filePath');
  }

  String _generateModelDefinition(ApiModel model) {
    final buffer = StringBuffer();
    buffer.writeln('class ${model.name} {');
    for (final field in model.fields) {
      buffer.writeln('  final ${field.type} ${field.name.camelCase};');
    }
    buffer.writeln('\n  ${model.name}({');
    for (final field in model.fields) {
      buffer.writeln('    required this.${field.name.camelCase},');
    }
    buffer.writeln('  });');
    buffer.writeln('}');
    return buffer.toString();
  }

  ApiModel? _findContainingModel(ApiModel targetModel) {
    // Ищем во всех моделях
    for (final model in _models) {
      if (_modelContainsFieldModel(model, targetModel.name)) {
        return model;
      }
    }
    // Ищем в моделях методов
    for (final method in _methods) {
      if (_modelContainsFieldModel(method.request, targetModel.name)) {
        return method.request;
      }
      if (_modelContainsFieldModel(method.response, targetModel.name)) {
        return method.response;
      }
    }
    return null;
  }

  bool _modelContainsFieldModel(ApiModel model, String targetModelName) {
    if (model is EmptyModel) return false;
    
    for (final field in model.fields) {
      if (field.model?.name == targetModelName) {
        return true;
      }
      // Рекурсивно проверяем вложенные модели
      if (field.model != null && _modelContainsFieldModel(field.model!, targetModelName)) {
        return true;
      }
    }
    return false;
  }

  ApiMethod? _findMethodForModel(ApiModel model) {
    for (final method in _methods) {
      final tag = method.tags.isNotEmpty ? method.tags.first.snakeCase : '_untagged';
      if (method.request == model || method.response == model) {
        return method;
      }
    }
    return null;
  }

  Future<void> _generateApiClient() async {
    final buffer = StringBuffer();

    // Imports
    buffer.writeln("import 'package:retrofit/retrofit.dart';");
    buffer.writeln("import 'package:dio/dio.dart';");
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");

    // Import base models (models with usages > 1)
    final baseModels = _getAllModels().where((m) => m.usages.toSet().length > 1);
    for (final model in baseModels) {
      buffer.writeln("import 'models/_base/${model.name.snakeCase}.dart';");
    }

    // Import method models с учетом snake_case
    for (final method in _methods) {
      final tag = method.tags.isNotEmpty ? method.tags.first.snakeCase : '_untagged';
      final methodDir = method.methodName.snakeCase;
      if (!(method.request is EmptyModel) && method.request.usages.toSet().length <= 1) {
        buffer.writeln("import 'models/$tag/$methodDir/request.dart';");
      }
      if (!(method.response is EmptyModel) && method.response.usages.toSet().length <= 1) {
        buffer.writeln("import 'models/$tag/$methodDir/response.dart';");
      }
    }

    buffer.writeln('\npart \'api_client.g.dart\';');

    // API Client class
    buffer.writeln('\n@RestApi()\nabstract class ApiClient {');
    buffer.writeln('  factory ApiClient(Dio dio) = _ApiClient;\n');

    // Methods
    for (final method in _methods) {
      final httpMethod = method.apiType.toUpperCase();
      final returnType = method.response is EmptyModel ? 'void' : method.response.name;

      buffer.writeln('  @$httpMethod(\'${method.apiPath}\')');
      buffer.write('  Future<$returnType> ${method.methodName}(');

      if (!(method.request is EmptyModel)) {
        buffer.write('@Body() ${method.request.name} request');
      }

      buffer.writeln(');\n');
    }

    buffer.writeln('}');

    await File('$_basePath/data/api_client.dart').writeAsString(buffer.toString());
  }

  Set<ApiModel> _getAllModels() {
    final models = <ApiModel>{};

    void addModel(ApiModel model) {
      if (model is! EmptyModel) {
        models.add(model);
        for (final field in model.fields) {
          if (field.model != null) {
            addModel(field.model!);
          }
        }
      }
    }

    for (final method in _methods) {
      addModel(method.request);
      addModel(method.response);
    }

    return models;
  }

  Future<void> _writeModelToFile(ApiModel model, String path) async {
    final buffer = StringBuffer();
    
    print('\n=== Processing model: ${model.name} ===');
    print('Path: $path');
    
    // Imports
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
    
    // Collect all models that need to be imported
    final importsNeeded = <ApiModel>{};
    
    // Add superclass if exists
    if (model.superModel != null) {
      print('Found superModel: ${model.superModel!.name}');
      importsNeeded.add(model.superModel!);
    }
    
    // Add models from fields
    print('Fields:');
    for (final field in model.fields) {
      print('- Field: ${field.name}, Type: ${field.type}, Model: ${field.model?.name}');
      if (field.model != null && field.model != model) {  // Avoid self-reference
        print('  Adding model ${field.model!.name} to imports (usages: ${field.model!.usages})');
        importsNeeded.add(field.model!);
      }
    }
    
    print('\nGenerating imports for ${importsNeeded.length} models:');
    // Generate imports for all needed models
    for (final importModel in importsNeeded) {
      print('\nProcessing import for: ${importModel.name}');
      print('- Usages: ${importModel.usages.toSet().length}');
      
      if (importModel.usages.toSet().length > 1) {
        final importPath = "import 'package:gen_yaml/generated/data/models/_base/${importModel.name.snakeCase}.dart';";
        print('- Adding base import: $importPath');
        buffer.writeln(importPath);
      } else {
        final method = _findMethodForModel(importModel);
        if (method != null) {
          final tag = method.tags.isNotEmpty ? method.tags.first.snakeCase : '_untagged';
          final methodDir = method.methodName.snakeCase;
          final currentPath = path.split('/models/')[1];
          final targetPath = '$tag/$methodDir';
          
          if (!currentPath.startsWith(targetPath)) {
            final isRequest = method.request == importModel;
            final fileName = isRequest ? 'request.dart' : 'response.dart';
            final importPath = "import 'package:gen_yaml/generated/data/models/$targetPath/$fileName';";
            print('- Adding method import: $importPath');
            buffer.writeln(importPath);
          }
        } else {
          buffer.writeln("import 'package:gen_yaml/generated/data/models/_base/${importModel.name.snakeCase}.dart';");
        }
      }
    }
    
    buffer.writeln('\npart \'${path.split('/').last.split('.').first}.g.dart\';');
    
    // Model class with inheritance if needed
    buffer.writeln('\n@JsonSerializable()');
    buffer.write('class ${model.name}');
    if (model.superModel != null) {
      buffer.write(' extends ${model.superModel!.name}');
    }
    buffer.writeln(' {');

    // Fields
    for (final field in model.fields) {
      final originalName = field.name;
      final cleanFieldName = _cleanFieldName(originalName);
      
      buffer.writeln('  @JsonKey(name: \'$originalName\')');
      final fieldType = field.model != null ? field.model!.name : field.type;
      buffer.writeln('  final $fieldType? $cleanFieldName;');
    }

    // Constructor
    buffer.write('\n  ${model.name}({');
    for (final field in model.fields) {
      final cleanFieldName = _cleanFieldName(field.name);
      buffer.write('\n    this.$cleanFieldName,');
    }
    buffer.writeln('\n  });');

    // JSON serialization methods
    buffer.writeln(
        '\n  factory ${model.name}.fromJson(Map<String, dynamic> json) => '
        '_\$${model.name}FromJson(json);\n');
    buffer.writeln(
        '  Map<String, dynamic> toJson() => _\$${model.name}ToJson(this);');

    buffer.writeln('}');

    await File(path).writeAsString(buffer.toString());
  }

  String _cleanFieldName(String fieldName) {
    // Удаляем [] в конце
    var cleaned = fieldName.replaceAll(RegExp(r'\[\]$'), '');
    
    // Разбиваем строку по специальным символам
    var parts = cleaned.split(RegExp(r'[^a-zA-Z0-9]'));
    
    // Фильтруем пустые части и обрабатываем каждую часть
    parts = parts.where((part) => part.isNotEmpty).toList();
    
    if (parts.isEmpty) {
      return 'field';
    }
    
    // Первая часть в нижнем регистре
    var result = parts.first.toLowerCase();
    
    // Остальные части с заглавной буквы
    for (var i = 1; i < parts.length; i++) {
      var part = parts[i];
      if (part.isNotEmpty) {
        result += part[0].toUpperCase() + part.substring(1).toLowerCase();
      }
    }
    
    // Если начинается с цифры, добавляем префикс
    if (RegExp(r'^\d').hasMatch(result)) {
      result = 'field' + result[0].toUpperCase() + result.substring(1);
    }
    
    return result;
  }

  Set<String> _getDependencies(ApiModel model) {
    final dependencies = <String>{};

    for (final field in model.fields) {
      if (field.model != null) {
        final depModel = _findModelByName(field.model!.name);
        if (depModel != null && depModel.usages.toSet().length > 1) {
          dependencies.add(field.model!.name);
          dependencies.addAll(_getDependencies(field.model!));
        }
      }
    }

    return dependencies;
  }

  ApiModel? _findModelByName(String name) {
    for (final method in _methods) {
      if (method.request.name == name) return method.request;
      if (method.response.name == name) return method.response;
      
      final model = _findModelInFields(method.request.fields, name) ?? 
                   _findModelInFields(method.response.fields, name);
      if (model != null) return model;
    }
    return null;
  }

  ApiModel? _findModelInFields(List<ApiField> fields, String name) {
    for (final field in fields) {
      if (field.model?.name == name) return field.model;
      if (field.model != null) {
        final model = _findModelInFields(field.model!.fields, name);
        if (model != null) return model;
      }
    }
    return null;
  }

  Future<void> _generateImportsForModel(ApiModel model, String filePath) async {
    final uniqueUsages = model.usages.toSet();
    print('Generating imports for ${uniqueUsages.length} models:');

    for (final usage in uniqueUsages) {
      print('Processing import for: ${model.name}');
      // Logic to add import statements based on unique usages
      // Example: if (uniqueUsages.contains('some_path')) { addImport('some_path'); }
    }
  }
}
