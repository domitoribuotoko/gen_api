import 'package:equatable/equatable.dart';

class FileParts {}

class GeneratedModels {
  final List<ApiMethod> methods;
  final List<ApiModel> models;

  const GeneratedModels({
    required this.methods,
    required this.models,
  });
}

class ApiField extends Equatable {
  final String name;
  final String type;
  final String example;
  final ApiModel? model;

  const ApiField({
    required this.name,
    required this.type,
    required this.example,
    this.model,
  });

  @override
  List<Object?> get props => [name, type, '${model?.name.toString()}', example];
}

class ApiModel extends Equatable {
  final String name;
  final List<ApiField> fields;
  final ApiModel? superModel;
  final List<String> usages;

  const ApiModel({
    required this.name,
    required this.fields,
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
  }) {
    List<String>? newUsages = usages ?? this.usages;
    if (newUsage != null && !newUsages.contains(newUsage)) {
      newUsages.add(newUsage);
    }
    return ApiModel(
      name: name ?? this.name,
      fields: fields ?? this.fields,
      superModel: superModel ?? this.superModel,
      usages: newUsages,
    );
  }
}

class EmptyModel extends ApiModel {
  EmptyModel({
    super.name = '',
    super.fields = const [],
  });
}

class VirtualModel extends ApiModel {
  VirtualModel({
    required super.name,
    super.fields = const [],
    super.superModel,
    super.usages,
  });
}

class ApiMethod extends Equatable {
  final List<String> tags;
  final String apiType;
  final String apiPath;
  final String methodName;
  final ApiModel response;
  final ApiModel request;

  const ApiMethod({
    required this.tags,
    required this.apiType,
    required this.apiPath,
    required this.methodName,
    required this.request,
    required this.response,
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
