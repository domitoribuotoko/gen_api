import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:gen_yaml/codegenerator.dart';
import 'package:gen_yaml/codegenerator/api_gen.dart';
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Path to OpenAPI yaml file')
    ..addOption('output', abbr: 'o', help: 'Output directory path');

  final results = parser.parse(args);

  if (results['input'] == null) {
    print('Please provide input file path using --input or -i');
    exit(1);
  }

  final inputPath = results['input'] as String;
  final outputPath = results['output'] as String? ?? 'lib/generated';

  final file = File(inputPath);
  if (!file.existsSync()) {
    print('Input file not found: $inputPath');
    exit(1);
  }

  final yamlString = await file.readAsString();
  final yaml = loadYaml(yamlString);

  await generateCode(yaml, outputPath);
}

Future<void> generateCode(YamlMap yaml, String outputPath) async {
  EquatableConfig.stringify = true;
  ApiGen(yaml: yaml, outputPath: outputPath);
  // final generator = CodeGenerator(yaml, outputPath);
  //
  // // Generate data layer
  // await generator.generateDataModels('$outputPath/data');
  // await generator.generateApiClient('$outputPath/data');
  //
  // // Generate domain layer
  // await generator.generateDomainEntities('$outputPath/domain');
}
