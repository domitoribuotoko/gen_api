import 'package:equatable/equatable.dart';
import 'package:gen_yaml/codegenerator/utils/utils.dart';

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
  final String? superVirtualModel;
  List<String> usages;

  ApiModel({
    required this.name,
    required this.fields,
    this.superModel,
    this.usages = const [],
    this.superVirtualModel,
  });

  bool get isVirtual => this is VirtualModel;

  @override
  List<Object?> get props =>
      [name, 'super ${superModel?.name ?? superVirtualModel}', usages, fields];

// ApiModel copyWith({
//   String? name,
//   List<ApiField>? fields,
//   List<ApiField>? superFields,
//   ApiModel? superModel,
//   int? usages,
// }) {
//   return ApiModel(
//     name: name ?? this.name,
//     fields: fields ?? this.fields,
//     superFields: superFields ?? this.superFields,
//     superModel: superModel ?? this.superModel,
//     usages: usages ?? this.usages,
//   );
// }
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
