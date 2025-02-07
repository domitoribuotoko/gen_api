part of 'api_gen.dart';

class _ModelsGenerator {
  final YamlMap _schemas;
  final YamlMap _paths;

  _ModelsGenerator({
    required ApiGen api,
  })  : _paths = api._paths,
        _schemas = api._schemas;

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
    YamlList? tags = content[c.ts];
    String? summary = content[c.sum];
    List<String> tagList =
        tags != null ? tags.map((tag) => tag.toString()).toList() : [];
    // print('METHOD HAS TAG $tagList');
    String methodName = u.apiMethodNameOfPath(apiPath);
    YamlMap? requestBody = content[c.reqB];
    YamlMap? response = content[c.res];

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
    YamlMap? body = response?[c.code200] ?? response?[c.cs200];
    if (body == null) {
      throw Exception('generate response null body\n$response');
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
    YamlMap? contentJson = body[c.cont][c.json];
    YamlMap? contentMultipart = body[c.cont][c.multipart];
    YamlMap? content = contentJson ?? contentMultipart;

    if (content != null) {
      YamlMap schema = content[c.sch];
      SchemasType type = u.getFieldType(schema, _schemas);
      String modelName = u.classNameOfPath(path, isResponse: isResponse);
      switch (type) {
        case SchemasType.model:
          return _getModelFromDeclaration(schema, propModelName: modelName);
        case SchemasType.array:
          //todo array generating
          return _getModelFromDeclaration(schema, propModelName: modelName);
        case SchemasType.field:
          throw Exception('METHOD CLASS IS FIELD OR REF ON REF');
      }
    } else {
      throw Exception('no contend body for class\nbody: $body');
    }
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
        return _generateModelOfRef(schema[c.ref]);
      case SchemeDeclaration.allOf:
        return _generateModelOfAll(schema);
      case SchemeDeclaration.oneOf:
        return _generateModelOfOne(schema, propModelName: propModelName);
      case SchemeDeclaration.unknown:
        //print('$dec\n$schema');
        throw Exception(
            'UNKNOWN MODEL DECLARATION:\n$schema\npropName:$propModelName');
    }
  }

  ApiField _generateFieldFromDeclaration(MapEntry fieldMap) {
    YamlMap value = fieldMap.value as YamlMap;
    SchemeDeclaration dec = u.getSchemaDeclaration(value);
    switch (dec) {
      case SchemeDeclaration.here:
        return _generateFieldBase(fieldMap);
      case SchemeDeclaration.ref:
        return _generateFieldOfRef(value[c.ref], fieldName: fieldMap.key);
      case SchemeDeclaration.allOf:
        return _generateFieldOfAll(fieldMap);
      case SchemeDeclaration.oneOf:
        return _generateFieldOfOne(fieldMap);
      case SchemeDeclaration.unknown:
        throw Exception('UNKNOWN FIELD DECLARATION:\n$value');
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
      // print('generate model of ref $ref');
      ApiModel model = _generateModel(
        modelMap,
        supModelMap: supModel,
      );
      return model;
    } else {
      throw Exception('model $ref not found in schemas');
    }
  }

  ApiModel _generateModelOfAll(YamlMap schema) {
    YamlList? list = schema[c.all];
    if (list == null) {
      throw Exception('EXCEPTION list allOf is $list');
    }
    if (list.length == 1) {
      schema[c.ref];
      String ref = list.first[c.ref];
      return _generateModelOfRef(ref);
    } else {
      throw Exception('cases allOf not covered length:\n---${list.length}---');
    }
  }

  ApiModel _generateModelOfOne(YamlMap schema, {propModelName = ''}) {
    YamlList? list = schema[c.one];
    if (list == null) {
      throw Exception('EXCEPTION list oneOf is $list');
    }
    if (list.length == 1) {
      schema[c.ref];
      String ref = list.first[c.ref];
      return _generateModelOfRef(ref);
    } else if (list.length > 1) {
      List<ApiModel> childrenModels = [];
      YamlList list = schema[c.one];
      for (YamlMap schema in list) {
        ApiModel forMerge = _generateModelOfRef(schema[c.ref]);
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
    } else {
      throw Exception(
          'EXCEPTION cases oneOf not covered len:\n---${list.length}---');
    }
  }

  ApiModel _generateModel(
    MapEntry modelMap, {
    MapEntry? supModelMap,
  }) {
    YamlMap properties = modelMap.value[c.prop] as YamlMap;
    YamlList? additionalProps = modelMap.value[c.all];
    List<ApiField> fields = _generateFields(properties);
    if (additionalProps != null) {
      for (YamlMap additionalMap in additionalProps) {
        String reference = additionalMap[c.ref];
        MapEntry? map = _getMapFromRef(reference);
        if (map == null) {
          throw Exception('no map for reference $reference');
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
      description: modelMap.value[c.desc] ?? '',
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
    YamlMap itemScheme = arrayScheme[c.items];
    SchemasType itemType = u.getFieldType(itemScheme, _schemas);
    ApiModel? model;
    String? desc;
    switch (itemType) {
      case SchemasType.field:
        MapEntry entry = MapEntry('UNKNOWN', itemScheme);
        desc = itemScheme[c.desc];
        ApiField fieldModel = _generateFieldFromDeclaration(entry);
        type = 'List<${fieldModel.type}>';
      case SchemasType.model:
        String? arrayRef = u.getRefFromMap(fieldMap.value);
        String? itemRef = u.getRefFromMap(itemScheme);
        String className = genArrayModelName(fieldMap.key, arrayRef, itemRef);
        model = _getModelFromDeclaration(itemScheme, propModelName: className);
        type = 'List<${model.name}>';
        desc = itemScheme[c.desc];
      case SchemasType.array:
        throw Exception('ITEM OF ARRAY IS ARRAY');
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

  ApiField _generateFieldOfOne(fieldMap) {
    ///по идее такого кейса быть не может, так как это по сути неправильное описание api
    throw Exception('TRY GENERATE FIELD FROM ONE OF');
  }

  ApiField _generateFieldBase(MapEntry fieldMap) {
    YamlMap value = fieldMap.value as YamlMap;
    String? type = value[c.type];
    String? format = value[c.format];
    String? description = value[c.desc];
    String fieldType = u.generateType(type, format);
    return ApiField(
      name: fieldMap.key,
      description: description ?? '',
      type: fieldType,
      example: value[c.ex].toString(),
    );
  }

  ApiField _generateFieldOfAll(MapEntry fieldMap) {
    YamlList list = fieldMap.value[c.all];
    if (list.length == 1) {
      fieldMap.value[c.ref];
      String ref = list.first[c.ref];
      return _generateFieldOfRef(ref, fieldName: fieldMap.key);
    } else {
      throw Exception(
          'EXCEPTION cases allOf not covered length:\n---${list.length}---');
    }
  }

  ApiField _generateFieldOfRef(String reference, {required String fieldName}) {
    String ref = u.formatReference(reference);
    MapEntry? buf = _schemas.entries[ref];
    // print('generate field of ref \nname:$fieldName\nref:$ref\nschema:$buf');
    if (buf != null) {
      MapEntry map = MapEntry(fieldName, buf.value);
      ApiField field = _generateFieldBase(map);
      return field;
    } else {
      throw Exception('field $ref not found in schemas');
    }
  }

  ApiField _generateFieldFromModel(MapEntry fieldMap) {
    String type =
        u.classNameOfField([_currentMethodProcess!.methodName, fieldMap.key]);
    MapEntry mapModel = MapEntry(type, fieldMap.value);
    ApiModel model =
        _getModelFromDeclaration(mapModel.value, propModelName: mapModel.key);
    // print('GENERATE MODEL FROM PROP $type\n$mapModel ');
    String? desc = fieldMap.value[c.desc];
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
