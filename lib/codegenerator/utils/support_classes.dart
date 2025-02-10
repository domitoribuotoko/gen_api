import 'package:equatable/equatable.dart';

class GeneratedModels extends Equatable {
  final List<ApiMethod> methods;
  final List<ApiModel> models;

  const GeneratedModels({
    required this.methods,
    required this.models,
  });

  @override
  List<Object?> get props => [models];
}

class ApiField extends Equatable {
  final String name;
  final String type;
  final String example;
  final String description;
  final ApiModel? model;

  const ApiField({
    required this.name,
    required this.type,
    required this.example,
    required this.description,
    this.model,
  });

  @override
  List<Object?> get props => [name, type, '${model?.name.toString()}', example];
}

class ApiModel extends Equatable {
  final String name;
  final List<ApiField> fields;
  final ApiModel? superModel;
  final String description;
  final List<String> usages;
  final bool isArray;

  const ApiModel({
    required this.description,
    required this.name,
    required this.fields,
    this.isArray = false,
    this.superModel,
    this.usages = const [],
  });

  bool get isBase => usages.length > 1;

  bool get isVirtual => this is VirtualModel;

  bool get isEmpty => this is EmptyModel;

  @override
  List<Object?> get props =>
      [name, 'super ${superModel?.name}', usages, fields];

  ApiModel copyWith({
    String? name,
    List<ApiField>? fields,
    ApiModel? superModel,
    List<String>? usages,
    String? newUsage,
    bool? isArray,
  }) {
    List<String>? newUsages = usages ?? this.usages;
    if (newUsage != null && !newUsages.contains(newUsage)) {
      newUsages.add(newUsage);
    }
    return ApiModel(
      name: name ?? this.name,
      fields: fields ?? this.fields,
      superModel: superModel ?? this.superModel,
      description: description,
      usages: newUsages,
      isArray: isArray ?? this.isArray,
    );
  }
}

class EmptyModel extends ApiModel {
  const EmptyModel({
    super.name = '',
    super.fields = const [],
    super.description = '',
  });
}

class VirtualModel extends ApiModel {
  const VirtualModel({
    required super.name,
    super.fields = const [],
    super.superModel,
    super.usages,
    super.description = '',
  });
}

class ApiMethod extends Equatable {
  final List<String> tags;
  final String apiType;
  final String apiPath;
  final String methodName;
  final ApiModel response;
  final ApiModel request;
  final String summary;

  const ApiMethod({
    required this.tags,
    required this.apiType,
    required this.apiPath,
    required this.methodName,
    required this.request,
    required this.response,
    required this.summary,
  });

  // @override
  // List<Object?> get props => [
  //       u.newLine('tag: $tags'),
  //       u.newLine('type: $apiType'),
  //       u.newLine('path: $apiPath'),
  //       u.newLine('name: $methodName'),
  //       u.newLine(request),
  //       u.newLine(response),
  //     ];
  @override
  List<Object?> get props => [
        tags,
        apiType,
        apiPath,
        methodName,
        request,
        response,
      ];
}

class ModelDefinition {
  final StringBuffer definition;
  final String import;

  const ModelDefinition({
    required this.definition,
    required this.import,
  });
}
