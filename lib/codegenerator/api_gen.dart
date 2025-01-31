import 'package:equatable/equatable.dart';
import 'package:gen_yaml/codegenerator/utils/enums.dart';
import 'package:gen_yaml/codegenerator/utils/support_classes.dart';
import 'package:gen_yaml/codegenerator/utils/utils.dart';
import 'package:yaml/yaml.dart';

import 'utils/consts.dart';

part 'generator.dart';

class ApiGen {
  String _outputPath;
  YamlMap _yaml;
  YamlList _tags;
  YamlMap _schemas;
  YamlMap _paths;

  ApiGen({
    required YamlMap yaml,
    required String outputPath,
  })  : _outputPath = outputPath,
        _yaml = yaml,
        _tags = yaml['tags'],
        _schemas = yaml['components']['schemas'],
        _paths = yaml['paths'] {
    _run();
  }

  void _run() {
    _ModelsGenerator generator = _ModelsGenerator(
      paths: _paths,
      schemas: _schemas,
      tags: _tags,
      yaml: _yaml,
    );
    GeneratedModels models = generator.generate();
    // print('api gen result\n${models}');
  }
}
