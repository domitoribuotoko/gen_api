import 'package:gen_yaml/codegenerator/utils/support_classes.dart';

class Printer {
  List<ApiMethod> _methods;

  Printer({
    required List<ApiMethod> methods,
  }) : _methods = methods {
    _print();
  }

  void _print() {}
}
