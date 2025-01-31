part of 'api_gen.dart';

class _ModelsGenerator {
  YamlMap _yaml;
  YamlList _tags;
  YamlMap _schemas;
  YamlMap _paths;

  _ModelsGenerator({
    required YamlMap yaml,
    required YamlList tags,
    required YamlMap paths,
    required YamlMap schemas,
  })  : _paths = paths,
        _schemas = schemas,
        _tags = tags,
        _yaml = yaml;

  List<ApiModel> _generateModelsList = [];
  List<ApiMethod> _generateMethodList = [];

  GeneratedModels generate() {
    MapEntry path = _paths.entries.first;

    _generateMethod(path);
    return GeneratedModels(
      generateMethodList: _generateMethodList,
      generateModelsList: _generateModelsList,
    );
  }

  ApiMethod _generateMethod(MapEntry pathMap) {
    String apiPath = pathMap.key;
    YamlMap apiMethod = pathMap.value;
    String apiType = apiMethod.value.keys.first;
    YamlMap content = apiMethod.value[apiType];
    YamlList? tags = content[c.ts];
    String? summary = content[c.sum];
    String? methodDescription = content[c.desc];
    YamlMap? requestBody = content[c.req];
    YamlMap? response = content[c.res];
    String requestClassName = _getClassNameFromBody(requestBody, apiPath);

    String responseClassName = _getClassNameFromResponse(response, apiPath);

    ApiMethod method = ApiMethod(
      tags: tags != null ? tags.map((tag) => tag.toString()).toList() : [],
      apiType: apiType,
      path: apiPath,
      name: u.apiMethodNameOf(apiPath),
      requestClassName: requestClassName,
      responseClassName: '',
    );
    return method;
  }

  String _getClassNameFromResponse(YamlMap? response, String path) {
    YamlMap? body = response?[c.code200];
    return _getClassNameFromBody(body, path);
  }

  String _getClassNameFromBody(YamlMap? body, String path) {
    YamlMap? contentJson = body?[c.cont][c.json];
    YamlMap? contentMultipart = body?[c.cont][c.multipart];
    YamlMap? content = contentJson ?? contentMultipart;

    if (content != null) {
      YamlMap schema = content[c.sch];
      // print('request schema $schema');
      SchemeDeclaration dec = u.getSchemaDeclaration(schema);
      switch (dec) {
        case SchemeDeclaration.ref:
          return _getModelNameOfRef(schema[c.ref]);
        case SchemeDeclaration.properties:
          return _getModelNameOfProp(schema, path);
        //todo all cases
        case SchemeDeclaration.allOf:
        case SchemeDeclaration.oneOf:
        case SchemeDeclaration.unknown:
          print('$dec\n$schema');
          throw Exception('EXCEPTION cases are not covered:\n---$dec---');
      }
    }
    return '';
  }

  String _getModelNameOfProp(YamlMap requestSchema, String path) {
    MapEntry modelMap = MapEntry(u.modelNameOfPath(path), requestSchema);
    ApiModel model = _generateModel(modelMap);
    return model.name;
  }

  String _getModelNameOfRef(String reference) {
    String ref = u.formatReference(reference);
    MapEntry? modelMap = _schemas.entries[ref];
    if (modelMap != null) {
      ApiModel model = _generateModel(modelMap);
      return model.name;
    } else {
      throw Exception('model $ref not found in schemas');
    }
  }

  ApiModel _generateModel(MapEntry modelMap) {
    // print('generate model ${modelMap.key}');
    YamlMap properties = modelMap.value[c.prop] as YamlMap;
    List<ApiField> fields = List.generate(properties.length, (index) {
      return generateField(properties.entries.elementAt(index));
    });

    ApiModel model = ApiModel(
      name: modelMap.key,
      fields: fields,
      //todo directory to generate
      directoryPath: '',
    );
    _generateModelsList.add(model);
    // print('end generate model ${model}');
    return model;
  }

  ApiField generateField(MapEntry fieldMap) {
    YamlMap value = fieldMap.value as YamlMap;
    SchemasType schType = u.getSchemaType(value);
    String fieldName = fieldMap.key;
    String type;
    String example;
    // print('generate field ${fieldName}');
    if (schType.isField) {
      type = value[c.type].toString();
      example = value[c.ex].toString();
    } else {
      type = u.modelNameOfField(fieldName);
      example = '';
      _generateModel(MapEntry(type, fieldMap.value));
    }
    ApiField modelField = ApiField(
      name: fieldName,
      type: type,
      example: example,
    );
    return modelField;
  }
}
