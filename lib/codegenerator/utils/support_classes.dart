import 'package:equatable/equatable.dart';

class GeneratedModels extends Equatable {
  final List<ApiModel> generateModelsList;
  final List<ApiMethod> generateMethodList;

  const GeneratedModels({
    required this.generateMethodList,
    required this.generateModelsList,
  });

  @override
  List<Object?> get props => [generateMethodList, generateModelsList];
}

class ApiField extends Equatable {
  final String name;
  final String type;
  final String example;

  const ApiField({
    required this.name,
    required this.type,
    required this.example,
  });

  @override
  List<Object?> get props => [name, type, example];
}

class ApiModel extends Equatable {
  final String name;
  final List<ApiField> fields;
  final String directoryPath;

  const ApiModel({
    required this.name,
    required this.fields,
    required this.directoryPath,
  });

  @override
  List<Object?> get props => [name, fields, directoryPath];
}

class ApiMethod extends Equatable {
  final List<String> tags;
  final String apiType;
  final String path;
  final String name;
  final String responseClassName;
  final String requestClassName;

  const ApiMethod({
    required this.tags,
    required this.apiType,
    required this.path,
    required this.name,
    required this.requestClassName,
    required this.responseClassName,
  });

  @override
  List<Object?> get props => [
        tags,
        apiType,
        path,
        name,
        requestClassName,
        requestClassName,
      ];
}
