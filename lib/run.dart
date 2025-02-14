import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:gen_yaml/codegenerator/api_gen.dart';
import 'package:gen_yaml/codegenerator/utils/utils.dart';
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

String appName = u.projDir;
bool isOverwriteFiles = false;

class Run {
  static Future<void> run(List<String> args) async {
    EquatableConfig.stringify = true;
    appName = u.packageName();
    final parser = ArgParser()
      ..addOption('input', abbr: 'i', defaultsTo: 'openapi.yaml')
      ..addOption('output', abbr: 'o', defaultsTo: 'lib')
      ..addFlag('run_build', abbr: 'b', defaultsTo: false)
      ..addFlag('is_overWrite', abbr: 'w', defaultsTo: false);

    ArgResults results = parser.parse(args);

    if (results['input'] == null) {
      throw Exception('Please provide input file path using --input or -i');
    }

    String inputPath = results['input'] as String;
    String outputPath = results['output'] as String? ?? 'lib/generated';
    bool isBuild = results['run_build'] ?? false;
    isOverwriteFiles = results['is_overWrite'] ?? false;
    final file = File(inputPath);
    if (!file.existsSync()) {
      throw Exception('${r('Input file not found:')} ${y(inputPath)}');
    }

    final yamlString = file.readAsStringSync();
    final yaml = loadYaml(yamlString);

    ApiGen(yaml: yaml, outputPath: outputPath);
    _maybeRunBuilder(inputIsBuild: isBuild);
  }
}

void _maybeRunBuilder({bool inputIsBuild = false}) {
  File pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    throw Exception('pubspec.yaml not found');
  }
  String pubspecContent = pubspecFile.readAsStringSync();
  YamlMap pubspec = loadYaml(pubspecContent);
  YamlMap? genYamlConfig = pubspec['gen_yaml'];
  bool? paramIsBuild = genYamlConfig?['isRunBuilder'] as bool?;
  bool isParamSet = paramIsBuild != null;
  bool isBuild = (paramIsBuild == true) || (inputIsBuild && !isParamSet);
  String booValue = isBuild ? g('true') : y('false');
  stdout.writeln(
      '${g('is generate .g.dart files')}: $booValue\ninputIsBuild: $inputIsBuild\nisParamSet: $isParamSet\nparamIsBuild: $paramIsBuild');
  if (isBuild) {
    Process.run('dart', ['run', 'build_runner', 'build', '-d']);
  }
}
