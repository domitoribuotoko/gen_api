part of 'api_gen.dart';

class _Printer {
  final List<ApiMethod> _methods;
  final List<ApiModel> _models;
  final String _basePath;

  _Printer({
    required GeneratedModels generated,
    required String? output,
  })  : _methods = generated.methods,
        _models = generated.models,
        _basePath = output ?? 'lib' {
    // print('OUTPU IS $output');
    _generate();
  }

  Future<void> _generate() async {
    StringBuffer clientImports = u.clientFile();
    StringBuffer clientClasses = u.clientClass();
    for (ApiMethod method in _methods) {
      StringBuffer apiMethod = u.generateApiMethodBuffer(method);
      clientClasses.writelnIfNotEmpty(apiMethod);
      List<ApiModel> requestModels = getModelsInside(method.request);
      List<ApiModel> responseModels = getModelsInside(method.response);
      String requestPath = _maybeWriteManyModels(requestModels, method);
      String responsePath = _maybeWriteManyModels(
        responseModels,
        method,
        isRequest: false,
      );
      u.maybeAddImport(requestPath, clientImports);
      u.maybeAddImport(responsePath, clientImports);
    }

    clientImports.writelnIfNotEmpty(clientClasses);
    u.createApiClientFile(clientImports, _basePath);
  }

  List<ApiModel> getModelsInside(ApiModel parentModel) {
    List<ApiModel> models = [];
    if (ApiModel is EmptyModel) {
      return models;
    }
    models.add(parentModel);
    if (parentModel.isVirtual) {
      List<ApiModel> findChildren = _models.childrenFromName(parentModel.name);
      for (ApiModel child in findChildren) {
        models.addAll(getModelsInside(child));
      }
    }
    for (ApiField field in parentModel.fields) {
      ApiModel? modelInside = field.model;
      if (modelInside != null) {
        models.addAll(getModelsInside(modelInside));
      }
    }
    models.removeDuplicates();
    return models;
  }

  String _maybeWriteManyModels(
    List<ApiModel> models,
    ApiMethod method, {
    bool isRequest = true,
  }) {
    if (models.isEmpty || models.hasEmpty) {
      return '';
    }
    if (!models.hasValidRequestModels()) {
      ApiModel baseModel = isRequest ? method.request : method.response;
      return _generateBaseModel(baseModel);
    }

    // Определяем директорию и путь для файла реквеста
    String? tag = method.tags.firstOrNull?.snakeCase;
    String methodDir = method.methodName.snakeCase;
    String fileName = isRequest ? 'request.dart' : 'response.dart';
    String requestFilePath = tag != null
        ? '$_basePath/data/models/$tag/$methodDir'
        : '$_basePath/data/models/$methodDir';

    // Создаем директорию, если она не существует
    Directory(requestFilePath).createSync(recursive: true);

    // Создаем StringBuffer для содержимого файла
    StringBuffer fileImports = StringBuffer();
    StringBuffer fileClasses = StringBuffer();
    fileImports.writelnIfNotEmpty(c.impJson);
    for (ApiModel model in models) {
      fileClasses.writelnIfNotEmpty(u.generateModelDefinition(model));
    }
    fileImports.writelnIfNotEmpty(fileClasses);
    String requestPath = '$requestFilePath/$fileName';
    File(requestPath).writeAsStringSync(fileImports.toString());
    return requestPath;
  }

  String _generateBaseModel(ApiModel model) {
    String baseModelPath =
        '$_basePath/data/models/_base/${model.name.snakeCase}.dart';
    if (!File(baseModelPath).existsSync()) {
      _writeSingleModelToFile(model, baseModelPath);
    }
    return baseModelPath;
  }

  void _writeSingleModelToFile(ApiModel model, String path) async {
    final directory = Directory(path).parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final modelFile = StringBuffer();
    modelFile.writelnIfNotEmpty(
        "import 'package:json_annotation/json_annotation.dart';");
    modelFile.writelnIfNotEmpty(
        '\npart \'${path.split('/').last.split('.').first}.g.dart\';');
    modelFile.writelnIfNotEmpty(u.generateModelDefinition(model));
    File(path).writeAsStringSync(modelFile.toString());
  }
}
