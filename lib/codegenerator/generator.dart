part of 'api_gen.dart';

class _ModelsGenerator {
  final YamlMap _paths;
  final YamlMap _schemas;

  _ModelsGenerator({
    required ApiGen api,
  })  : _paths = api._paths,
        _schemas =
            YamlMap.wrap(Map.from(api._schemas)..addAll(api._responses ?? {}));

  final List<ApiModel> _generateModelsList = [];
  final List<ApiMethod> _generateMethodList = [];
  ApiMethod? _currentMethodProcess;

  GeneratedModels generate() {
    _generateAllMethods();
    GeneratedModels models = GeneratedModels(
      methods: _generateMethodList,
      models: _generateModelsList,
    );
    return models;
  }

  void _generateAllMethods() {
    // _generateMethod(_paths.entries.elementAt(26));
    for (MapEntry path in _paths.entries) {
      _generateMethod(path);
    }
  }

  void _generateMethod(MapEntry pathMap) {
    String apiPath = pathMap.key;
    YamlMap apiMethod = pathMap.value;
    String apiType = apiMethod.value.keys.first;
    YamlMap content = apiMethod.value[apiType];
    YamlList? tags = content[con.ts];
    String? summary = content[con.sum];
    List<String> tagList =
        tags != null ? tags.map((tag) => tag.toString()).toList() : [];
    String methodName = u.apiMethodNameOfPath(apiPath);
    YamlMap? requestBody = content[con.reqB];
    YamlMap? response = content[con.res];

    _setCurrentMethod(
      tags: tagList,
      apiPath: apiPath,
      apiType: apiType,
      methodName: methodName,
    );

    ApiModel requestModel = _generateModelFromBody(requestBody, apiPath);
    ApiModel responseModel = _generateApiResponse(response, apiPath);

    ApiMethod method = ApiMethod(
      tags: tagList,
      apiType: apiType,
      apiPath: apiPath,
      summary: summary ?? '',
      methodName: methodName,
      request: requestModel,
      response: responseModel,
    );
    _generateMethodList.add(method);
  }

  void _setCurrentMethod({
    List<String>? tags,
    String? apiType,
    String? apiPath,
    String? methodName,
  }) {
    _currentMethodProcess = ApiMethod(
      tags: tags ?? [],
      apiType: apiType ?? '',
      apiPath: apiPath ?? '',
      methodName: apiPath != null ? u.apiMethodNameOfPath(apiPath) : '',
      request: EmptyModel(),
      response: EmptyModel(),
      summary: '',
    );
  }

  ApiModel _generateApiResponse(YamlMap? response, String apiPath) {
    // //print('generate response class $response');
    YamlMap? body = response?[con.code200] ?? response?[con.cs200];
    if (body == null) {
      e.nullBody(apiPath);
    }
    return _generateModelFromBody(body, apiPath, isResponse: true);
  }

  ApiModel _generateModelFromBody(
    YamlMap? body,
    String path, {
    bool isResponse = false,
  }) {
    if (body == null) {
      return EmptyModel();
    }
    //print('generate class $body');
    YamlMap? content = u.contentFromSchema(body);

    if (content != null) {
      YamlMap schema = content[con.sch];
      SchemasType type = u.getFieldType(schema, _schemas);
      String modelName = u.classNameOfPath(path, isResponse: isResponse);
      switch (type) {
        case SchemasType.model:
          return _getModelFromDeclaration(schema, propModelName: modelName);
        case SchemasType.array:
          return _generateModelFromArray(schema);
        case SchemasType.field:
          throw e.modelsIsFiled(content);
      }
    } else {
      throw e.nullBody(path);
    }
  }

  ApiModel _generateModelFromArray(YamlMap schema) {
    schema = schema[con.items];
    ApiModel model = _getModelFromDeclaration(schema);
    model = model.copyWith(isArray: true);
    _generateModelsList.replaceSingle(model);
    return model;
  }

  ApiModel _generateModelOfProp(YamlMap schema, String modelName) {
    MapEntry modelMap = MapEntry(modelName, schema);
    ApiModel model = _generateModel(modelMap);
    return model;
  }

  ApiModel _getModelFromDeclaration(
    YamlMap schema, {
    String propModelName = '',
  }) {
    SchemeDeclaration dec = u.getSchemaDeclaration(schema);
    switch (dec) {
      case SchemeDeclaration.here:
        return _generateModelOfProp(schema, propModelName);
      case SchemeDeclaration.ref:
        return _generateModelOfRef(schema[con.ref]);
      case SchemeDeclaration.allOf:
        return _generateModelOfAll(schema);
      case SchemeDeclaration.oneOf:
        return _generateModelOfOne(schema, propModelName: propModelName);
      case SchemeDeclaration.unknown:
        MapEntry map = MapEntry(propModelName, schema);
        throw e.unknownModel(map);
    }
  }

  ApiField _generateFieldFromDeclaration(MapEntry fieldMap) {
    YamlMap value = fieldMap.value as YamlMap;
    SchemeDeclaration dec = u.getSchemaDeclaration(value);
    switch (dec) {
      case SchemeDeclaration.here:
        return _generateFieldBase(fieldMap);
      case SchemeDeclaration.ref:
        return _generateFieldOfRef(value[con.ref], fieldName: fieldMap.key);
      case SchemeDeclaration.allOf:
        return _generateFieldOfAll(fieldMap);
      case SchemeDeclaration.oneOf:
        return _generateFieldOfOne(fieldMap);
      case SchemeDeclaration.unknown:
        throw e.unknownField(fieldMap);
    }
  }

  ApiModel _generateModelOfRef(
    String reference, {
    String? superRef,
  }) {
    // print('GEN MODEL OF REF $reference');
    String? supRef = superRef != null ? u.formatReference(superRef) : null;
    String ref = u.formatReference(reference);
    MapEntry? modelMap = _schemas.entries[ref];
    MapEntry? supModel = _schemas.entries[supRef];
    if (modelMap != null) {
      ApiModel model = _generateModel(modelMap, supModelMap: supModel);
      return model;
    } else {
      throw e.noSchemaRef(reference);
    }
  }

  ApiModel _generateModelOfAll(YamlMap schema) {
    YamlList? list = schema[con.all];
    if (list == null) {
      throw e.nullList(schema);
    }
    if (list.length == 1) {
      schema[con.ref];
      String ref = list.first[con.ref];
      return _generateModelOfRef(ref);
    } else {
      throw e.allOfLength(list.length);
    }
  }

  ApiModel _generateModelOfOne(YamlMap schema, {propModelName = ''}) {
    YamlList? list = schema[con.one];
    if (list == null) {
      throw e.nullList(schema);
    }
    if (list.length == 1) {
      schema[con.ref];
      String ref = list.first[con.ref];
      return _generateModelOfRef(ref);
    } else {
      List<ApiModel> childrenModels = [];
      YamlList list = schema[con.one];
      for (YamlMap schema in list) {
        ApiModel forMerge = _generateModelOfRef(schema[con.ref]);
        childrenModels.add(forMerge);
      }
      VirtualModel parentVirtualModel = u.mergeModels(
        childrenModels,
        newName: propModelName,
        methodPath: _currentMethodProcess!.apiPath,
      );
      childrenModels.removeMatchingModel(parentVirtualModel);
      childrenModels.setVirtualModel(parentVirtualModel);
      _generateModelsList.replaceModels(childrenModels);
      return parentVirtualModel;
    }
  }

  

  ApiModel _generateModel(
    MapEntry modelMap, {
    MapEntry? supModelMap,
  }) {
    YamlMap? props = u.propFromSchema(modelMap.value);
    if (props == null) {
      throw e.nullProp(modelMap);
    }
    YamlList? additionalProps = modelMap.value[con.all];
    List<ApiField> fields = _generateFields(props);
    if (additionalProps != null) {
      for (YamlMap additionalMap in additionalProps) {
        String reference = additionalMap[con.ref];
        MapEntry? map = _getMapFromRef(reference);
        if (map == null) {
          throw e.noSchemaRef(reference);
        }
        fields.addAll(_generateFields(map.value));
      }
    }
    ApiModel? superModel;
    if (supModelMap != null) {
      superModel = _generateModel(supModelMap);
    }
    ApiModel model = ApiModel(
      name: modelMap.key,
      fields: fields,
      description: modelMap.value[con.desc] ?? '',
      superModel: superModel,
      usages: [_currentMethodProcess!.apiPath],
    );
    //print('end generate model ${modelMap.key}');
    ApiModel? existed = _generateModelsList.itemByName(modelMap.key);
    if (existed != null) {
      String apiPath = _currentMethodProcess!.apiPath;
      _generateModelsList.replaceSingle(existed.copyWith(newUsage: apiPath));
      return existed;
    } else {
      _generateModelsList.add(model);
    }
    //print('end generate model ${model}');
    return model;
  }

  List<ApiField> _generateFields(YamlMap properties) {
    return List.generate(properties.length, (index) {
      return generateField(properties.entries.elementAt(index));
    });
  }

  ApiField generateField(MapEntry fieldMap) {
    YamlMap value = fieldMap.value as YamlMap;
    // SchemasType schType = u.getSchemaType(value);
    SchemasType schType = u.getFieldType(value, _schemas);
    switch (schType) {
      case SchemasType.model:
        return _generateFieldFromModel(fieldMap);
      case SchemasType.array:
        return _generateFieldFromArray(fieldMap);
      case SchemasType.field:
        return _generateFieldFromDeclaration(fieldMap);
    }
  }

  ApiField _generateFieldFromArray(MapEntry fieldMap) {
    String type;
    SchemeDeclaration declaration = u.getSchemaDeclaration(fieldMap.value);
    YamlMap arrayScheme;
    if (declaration.isAnyReference) {
      arrayScheme = u.getSchemaFromRef(fieldMap.value, _schemas);
    } else {
      arrayScheme = fieldMap.value;
    }
    YamlMap itemScheme = arrayScheme[con.items];
    SchemasType itemType = u.getFieldType(itemScheme, _schemas);
    ApiModel? model;
    String? desc;
    switch (itemType) {
      case SchemasType.field:
        MapEntry entry = MapEntry('UNKNOWN', itemScheme);
        desc = itemScheme[con.desc];
        ApiField fieldModel = _generateFieldFromDeclaration(entry);
        type = 'List<${fieldModel.type}>';
      case SchemasType.model:
        String? arrayRef = u.getRefFromMap(fieldMap.value);
        String? itemRef = u.getRefFromMap(itemScheme);
        String className = genArrayModelName(fieldMap.key, arrayRef, itemRef);
        model = _getModelFromDeclaration(itemScheme, propModelName: className);
        type = 'List<${model.name}>';
        desc = itemScheme[con.desc];
      case SchemasType.array:
        throw e.arrayInArray(fieldMap);
    }
    ApiField field = ApiField(
      name: fieldMap.key,
      type: type,
      description: desc ?? '',
      example: '',
      model: model,
    );
    return field;
  }

  String genArrayModelName(
    String fieldName,
    String? arrayRef,
    String? itemRef,
  ) {
    String className;
    if (itemRef != null) {
      className = u.formatReference(itemRef);
    } else if (arrayRef != null) {
      className = u.formatReference(arrayRef);
      className = className.replaceAll(RegExp(r'[Ll]ist'), '');
    } else {
      className =
          u.classNameOfField([_currentMethodProcess!.methodName, fieldName]);
    }
    return className;
  }

  ApiField _generateFieldOfOne(MapEntry fieldMap) {
    ///по идее такого кейса быть не может, так как это по сути неправильное описание api
    throw e.oneOfField(fieldMap);
  }

  ApiField _generateFieldBase(MapEntry fieldMap) {
    YamlMap value = fieldMap.value as YamlMap;
    String? type = value[con.type];
    String? format = value[con.format];
    String? description = value[con.desc];
    String fieldType = u.generateType(type, format);
    return ApiField(
      name: fieldMap.key,
      description: description ?? '',
      type: fieldType,
      example: value[con.ex].toString(),
    );
  }

  ApiField _generateFieldOfAll(MapEntry fieldMap) {
    YamlList list = fieldMap.value[con.all];
    if (list.length == 1) {
      fieldMap.value[con.ref];
      String ref = list.first[con.ref];
      return _generateFieldOfRef(ref, fieldName: fieldMap.key);
    } else {
      throw e.allOfLength(list.length);
    }
  }

  ApiField _generateFieldOfRef(String reference, {required String fieldName}) {
    String ref = u.formatReference(reference);
    MapEntry? buf = _schemas.entries[ref];
    if (buf != null) {
      MapEntry map = MapEntry(fieldName, buf.value);
      ApiField field = _generateFieldBase(map);
      return field;
    } else {
      throw e.noSchemaRef(reference);
    }
  }

  ApiField _generateFieldFromModel(MapEntry fieldMap) {
    String type =
        u.classNameOfField([_currentMethodProcess!.methodName, fieldMap.key]);
    MapEntry mapModel = MapEntry(type, fieldMap.value);
    ApiModel model =
        _getModelFromDeclaration(mapModel.value, propModelName: mapModel.key);
    // print('GENERATE MODEL FROM PROP $type\n$mapModel ');
    String? desc = fieldMap.value[con.desc];
    return ApiField(
      name: fieldMap.key,
      type: model.name,
      description: desc ?? '',
      example: '',
      model: model,
    );
  }

  MapEntry? _getMapFromRef(String reference) {
    String ref = u.formatReference(reference);
    MapEntry? buf = _schemas.entries[ref];
    return buf;
  }
}
