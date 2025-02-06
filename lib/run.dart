import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:gen_yaml/codegenerator/api_gen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

String appName = '';

class Run {
  static Future<void> run(List<String> args) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appName = packageInfo.packageName;
    final parser = ArgParser()
      ..addOption('input', abbr: 'i', defaultsTo: 'openapi.yaml')
      ..addOption('output', abbr: 'o', defaultsTo: 'lib');

    final results = parser.parse(args);

    if (results['input'] == null) {
      throw Exception('Please provide input file path using --input or -i');
      // exit(1);
    }

    String inputPath = results['input'] as String;
    String? outputPath = results['output'] as String? ?? 'lib/generated';

    final file = File(inputPath);
    if (!file.existsSync()) {
      throw Exception('Input file not found: $inputPath');
      // exit(1);
    }

    final yamlString = await file.readAsString();
    final yaml = loadYaml(yamlString);

    await generateData(yaml, outputPath);
  }
}

Future<void> generateData(YamlMap yaml, String? outputPath) async {
  EquatableConfig.stringify = true;
  ApiGen(yaml: yaml, outputPath: outputPath);
}
