import 'package:flutter/foundation.dart' show DiagnosticLevel;

abstract class FakeDiagnosticableMixin {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) =>
      super.toString();
}
