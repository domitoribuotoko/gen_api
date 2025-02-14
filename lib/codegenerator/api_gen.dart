import 'dart:io';
import 'package:colorize/colorize.dart';
import 'package:gen_yaml/codegenerator/utils/enums.dart';
import 'package:gen_yaml/codegenerator/utils/error.dart';
import 'package:gen_yaml/codegenerator/utils/support_classes.dart';
import 'package:gen_yaml/codegenerator/utils/utils.dart';
import 'package:gen_yaml/codegenerator/utils/consts.dart';
import 'package:gen_yaml/run.dart';
import 'package:recase/recase.dart';
import 'package:yaml/yaml.dart';

part 'generator.dart';

part 'printer.dart';

class ApiGen {
  final String _outputPath;
  final YamlMap _schemas;
  final YamlMap _paths;
  final YamlMap? _responses;

  ApiGen({
    required YamlMap yaml,
    required String outputPath,
  })  : _outputPath = outputPath,
        _schemas = yaml['components']['schemas'],
        _responses = yaml['components']['responses'],
        _paths = yaml['paths'] {
    _run();
  }

  void _run() {
    _ModelsGenerator generator = _ModelsGenerator(api: this);
    _Printer(generated: generator.generate(), outDir: _outputPath);
  }
}
