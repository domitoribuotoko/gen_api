import 'dart:io';
import 'package:gen_yaml/codegenerator/utils/support_classes.dart';
import 'package:gen_yaml/codegenerator/utils/utils.dart';
import 'package:recase/recase.dart';

class Printer2 {
  final List<ApiMethod> _methods;
  final List<ApiModel> _models;
  final String _basePath = 'lib/generated';

  Printer2({
    required List<ApiMethod> methods,
    required List<ApiModel> models,
  })  : _methods = methods,
        _models = models {
    _generate();
  }

  Future<void> _generate() async {
    print('PROJ DIR IS ${u.projDir}');
    StringBuffer clientFile = u.clientFile();
    StringBuffer clientClass = u.clientClass();
    for (ApiMethod method in _methods) {
      StringBuffer apiMethod = u.generateApiMethodBuffer(method);
      clientClass.write(apiMethod);
      List<ApiModel> requestModels = getModelsInside(method.request);
      // List<ApiModel> responseModels = getModelsInside(method.response);
      _maybeCreateRequestFile(requestModels, method);
    }
  }

  List<ApiModel> getModelsInside(ApiModel parentModel) {
    List<ApiModel> models = [];
    if (ApiModel is EmptyModel) {
      return models;
    }
    if (parentModel.isVirtual) {
      List<ApiModel> findChildren = _models.where(
        (element) {
          return element.superVirtualModel == parentModel.name;
        },
      ).toList();
      print(
          'NOT COLLECT MODELS FOR VIRTUAL MODEL $parentModel\nfind ${findChildren.length} childs$findChildren');
    }
    models.add(parentModel);

    ApiModel? superModel = parentModel.superModel;
    if (superModel != null) {
      models.addAll(getModelsInside(superModel));
    }
    for (ApiField field in parentModel.fields) {
      ApiModel? modelInside = field.model;
      if (modelInside != null) {
        models.addAll(getModelsInside(modelInside));
      }
    }
    return models;
  }

  void _maybeCreateRequestFile(
    List<ApiModel> requestModels,
    ApiMethod method,
  ) {
    if (!requestModels.hasValidRequestModels()) {
      return;
    }
    // Определяем директорию и путь для файла реквеста
    String? tag = method.tags.firstOrNull?.snakeCase;
    String methodDir = method.methodName.snakeCase;
    String requestFileName = 'request.dart';
    String requestFilePath = tag != null
        ? '$_basePath/data/models/$tag/$methodDir'
        : '$_basePath/data/models/$methodDir';

    // Создаем директорию, если она не существует
    Directory(requestFilePath).createSync(recursive: true);

    // Создаем StringBuffer для содержимого файла
    StringBuffer requestImports = StringBuffer();
    StringBuffer requestClasses = StringBuffer();
    requestImports
        .writeln("import 'package:json_annotation/json_annotation.dart';");

    // Обрабатываем каждую модель
    for (ApiModel model in requestModels) {
      if (model.usages.length > 1) {
        String baseImport = _generateBaseModel(model);
        requestImports.writeln(baseImport);
      } else {
        // Иначе добавляем описание модели в файл реквеста
        requestClasses.writeln(u.generateModelDefinition(model));
        if (model.isVirtual) {
          model = model as VirtualModel;
          List<ApiModel> forVirtual = _models
              .where((element) => element.superVirtualModel == model.name)
              .toList();
        }
      }
    }
    requestImports.writeln(requestClasses);
    // Записываем содержимое в файл реквеста
    File('$requestFilePath/$requestFileName')
        .writeAsStringSync(requestImports.toString());
  }

  String _generateBaseModel(ApiModel model) {
    // Если модель используется более одного раза, создаем файл в _base
    String import =
        "import 'package:gen_yaml/generated/data/models/_base/${model.name.snakeCase}.dart';";
    String baseModelPath =
        '$_basePath/data/models/_base/${model.name.snakeCase}.dart';
    if (!File(baseModelPath).existsSync()) {
      _writeSingleModelToFile(model, baseModelPath);
    } else {
      return '';
    }
    return import;
  }

  void _writeSingleModelToFile(ApiModel model, String path) async {
    final directory = Directory(path).parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final buffer = StringBuffer();
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
    buffer
        .writeln('\npart \'${path.split('/').last.split('.').first}.g.dart\';');
    buffer.writeln(u.generateModelDefinition(model));
    File(path).writeAsStringSync(buffer.toString());
  }
}
