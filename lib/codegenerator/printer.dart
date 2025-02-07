part of 'api_gen.dart';

class _Printer {
  final List<ApiMethod> _methods;
  final List<ApiModel> _models;
  final String _basePath;
  final String _pathData;
  final String _pathModels;

  _Printer({
    required GeneratedModels generated,
    required String outDir,
  })  : _methods = generated.methods,
        _models = generated.models,
        _basePath = outDir,
        _pathData = '$outDir${c.data}',
        _pathModels = '$outDir${c.data}${c.models}' {
    _generate();
  }

  Future<void> _generate() async {
    if (Directory(_pathData).existsSync()) {
      Directory(_pathData).deleteSync(recursive: true);
    }
    StringBuffer clientImports = u.clientFile();
    StringBuffer clientClasses = u.clientClass();
    for (ApiMethod method in _methods) {
      StringBuffer apiMethod = u.generateApiMethodBuffer(method);
      clientClasses.writelnIfNotEmpty(apiMethod);
      List<ApiModel> requestModels = getModelsInside(method.request);
      List<ApiModel> responseModels = getModelsInside(method.response);
      String requestPath = _maybeWriteManyModels(requestModels, method);
      String responsePath =
          _maybeWriteManyModels(responseModels, method, isRequest: false);
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
        if (parentModel.isBase && modelInside.isBase) {
          continue;
        } else {
          models.addAll(getModelsInside(modelInside));
        }
      }
    }
    models.removeDuplicates;
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
    ApiModel topLevelModel = isRequest ? method.request : method.response;
    if (topLevelModel.isBase) {
      return _generateBaseModel(topLevelModel);
    }

    // Определяем директорию и путь для файла
    String? tag = method.tags.firstOrNull?.snakeCase;
    String methodDir = method.methodName.snakeCase;
    String name = isRequest ? 'request' : 'response';
    String fileName = '$name.dart';
    String requestFilePath = tag != null
        ? '$_pathModels/$tag/$methodDir'
        : '$_pathModels/$methodDir';
    requestFilePath = '$requestFilePath/$name';

    // Создаем директорию, если она не существует
    Directory(requestFilePath).createSync(recursive: true);

    // Создаем StringBuffer для содержимого файла
    StringBuffer fileImports = StringBuffer();
    StringBuffer fileClasses = StringBuffer();
    fileImports.writelnIfNotEmpty(c.impJson);
    for (ApiModel model in models) {
      if (model.isBase) {
        String basePath = _generateBaseModel(model);
        u.maybeAddImport(basePath, fileImports);
      } else {
        fileClasses.writelnIfNotEmpty(u.generateModelDefinition(model));
      }
    }
    fileImports.writelnIfNotEmpty(u.part(name));
    fileImports.writelnIfNotEmpty(fileClasses);
    String requestPath = '$requestFilePath/$fileName';
    File(requestPath).writeAsStringSync(fileImports.toString());
    return requestPath;
  }

  String _generateBaseModel(ApiModel model) {
    String name = model.name.snakeCase;
    String modelPath = '$_pathModels${c.base}/$name/$name.dart';
    if (!File(modelPath).existsSync()) {
      _writeSingleModelToFile(model, modelPath);
    }
    return modelPath;
  }

  void _writeSingleModelToFile(ApiModel model, String path) async {
    Directory directory = Directory(path).parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    StringBuffer imports = StringBuffer();
    for (ApiField field in model.fields) {
      ApiModel? modelInside = field.model;
      if (modelInside != null && modelInside.isBase) {
        String basePath = _generateBaseModel(modelInside);
        u.maybeAddImport(basePath, imports);
      }
    }
    StringBuffer baseModelDefinition = StringBuffer();
    baseModelDefinition.writelnIfNotEmpty(c.impJson);
    String partOf = path.split('/').last.split('.').first;
    baseModelDefinition.writelnIfNotEmpty(u.part(partOf));
    baseModelDefinition.writelnIfNotEmpty(u.generateModelDefinition(model));
    imports.writelnIfNotEmpty(baseModelDefinition);
    if (!File(path).existsSync()) {
      File(path).writeAsStringSync(imports.toString());
    }
  }
}
