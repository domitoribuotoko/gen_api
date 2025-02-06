import 'dart:io';
import 'package:gen_yaml/codegenerator/utils/enums.dart';
import 'package:gen_yaml/codegenerator/utils/support_classes.dart';
import 'package:gen_yaml/codegenerator/utils/utils.dart';
import 'package:gen_yaml/codegenerator/utils/consts.dart';
import 'package:recase/recase.dart';
import 'package:yaml/yaml.dart';

part 'generator.dart';

part 'printer.dart';

class ApiGen {
  final String? _outputPath;
  final YamlMap _yaml;
  final YamlList _tags;
  final YamlMap _schemas;
  final YamlMap _paths;

  ApiGen({
    required YamlMap yaml,
    required String? outputPath,
  })  : _outputPath = outputPath,
        _yaml = yaml,
        _tags = yaml['tags'],
        _schemas = yaml['components']['schemas'],
        _paths = yaml['paths'] {
    _run();
  }

  void _run() {
    _ModelsGenerator generator = _ModelsGenerator(api: this);
    _Printer(generated: generator.generate(), output: _outputPath);
  }
}
