part of 'api_gen.dart';

class _Printer {
  final List<ApiMethod> _methods;
  final List<ApiModel> _models;
  final String _basePath;
  final String _pathModels;
  final List<String> _createdBaseModels = [];

  _Printer({
    required GeneratedModels generated,
    required String outDir,
  })  : _methods = generated.methods,
        _models = generated.models,
        _basePath = outDir,
        _pathModels = '$outDir${con.data}${con.models}' {
    _generate();
    stdout.writeln('${c('gen_yaml')} ${g('complete')}');
  }

  void _generate() {
    StringBuffer clientImports = u.clientFile();
    StringBuffer clientClasses = u.clientClass();
    for (ApiMethod method in _methods) {
      StringBuffer apiMethod = u.generateApiMethodBuffer(method);
      clientClasses.writelnIfNotEmpty(apiMethod);
      List<ApiModel> requestModels = getModelsInside(method.request);
      List<ApiModel> responseModels = getModelsInside(method.response);
      String requestPath = _maybeWriteManyModelsToFile(requestModels, method);
      String responsePath =
          _maybeWriteManyModelsToFile(responseModels, method, isRequest: false);
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

  String _maybeWriteManyModelsToFile(
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
    String methodName = method.methodName.snakeCase;
    String type = isRequest ? 'request' : 'response';
    String part = '${methodName}_$type';
    String fileName = '$part.dart';
    String requestFilePath = tag != null
        ? '$_pathModels/$tag/$methodName'
        : '$_pathModels/$methodName';
    requestFilePath = '$requestFilePath/$type';

    // Создаем директорию, если она не существует
    Directory(requestFilePath).createSync(recursive: true);

    // Создаем StringBuffer для содержимого файла
    StringBuffer imports = StringBuffer();
    StringBuffer fileClasses = StringBuffer();
    imports.writelnIfNotEmpty(con.impJson);
    for (ApiModel model in models) {
      if (model.isBase) {
        String basePath = _generateBaseModel(model);
        u.maybeAddImport(basePath, imports);
      } else {
        fileClasses.writelnIfNotEmpty(u.generateModelDefinition(model));
      }
    }
    imports.writelnIfNotEmpty(u.part(part));
    imports.writelnIfNotEmpty(fileClasses);
    String path = '$requestFilePath/$fileName';
    _maybeWriteFile(path, imports);
    return path;
  }

  String _generateBaseModel(ApiModel model) {
    String name = model.name.snakeCase;
    String modelPath = '$_pathModels${con.base}/$name/$name.dart';
    _writeSingleModelToFile(model, modelPath);
    return modelPath;
  }

  void _writeSingleModelToFile(ApiModel model, String path) {
    Directory(path).parent.createSync(recursive: true);
    StringBuffer imports = StringBuffer();
    for (ApiField field in model.fields) {
      ApiModel? modelInside = field.model;
      if (modelInside != null && modelInside.isBase) {
        String basePath = _generateBaseModel(modelInside);
        u.maybeAddImport(basePath, imports);
      }
    }
    StringBuffer baseModelDefinition = StringBuffer();
    baseModelDefinition.writelnIfNotEmpty(con.impJson);
    String partOf = path.split('/').last.split('.').first;
    baseModelDefinition.writelnIfNotEmpty(u.part(partOf));
    baseModelDefinition.writelnIfNotEmpty(u.generateModelDefinition(model));
    imports.writelnIfNotEmpty(baseModelDefinition);
    _maybeWriteFile(path, imports, isBase: true);
  }

  void _maybeWriteFile(
    String path,
    StringBuffer buffer, {
    bool isBase = false,
  }) {
    File newFile = File(path);
    if (newFile.existsSync()) {
      if (_createdBaseModels.contains(path)) {
        return;
      }
      if (isOverwriteFiles) {
        _writeFile(path, buffer);
        return;
      }
      stdout.write(
          '${y('file')} ${c(path)} ${y('already exist')}, overwrite? y/n/a:');
      String? line = stdin.readLineSync();
      bool isOverWrite = _parseInput(line);
      if (isOverWrite) {
        _writeFile(path, buffer);
      } else {
        stdout.writeln('file was skipped');
      }
    } else {
      _createdBaseModels.add(path);
      _writeFile(path, buffer, isOverWrite: false);
    }
  }

  void _writeFile(String path, StringBuffer buffer, {bool isOverWrite = true}) {
    String what = isOverWrite ? r('was overwrite') : g('was create');
    stdout.writeln('${y('file')} ${c(path)} $what');
    File(path).writeAsStringSync(buffer.toString());
  }

  bool _parseInput(String? input) {
    switch (input) {
      case 'y':
        return true;
      case 'n':
        return false;
      case 'a':
        isOverwriteFiles = true;
        return true;
      default:
        stdout.write('${r('input not recognized')}: "$input"');
        stdout.write('overwrite? y/n/a:');
        String? line = stdin.readLineSync();
        return _parseInput(line);
    }
  }
}

String r(String value) {
  return Colorize(value).red().toString();
}

String g(String value) {
  return Colorize(value).green().toString();
}

String y(String value) {
  return Colorize(value).yellow().toString();
}

String c(String value) {
  return Colorize(value).cyan().toString();
}
