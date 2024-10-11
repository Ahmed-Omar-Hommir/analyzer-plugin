import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
// import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';

Iterable<AnalysisErrorFixes> validate(
  String path,
  ResolvedUnitResult unit,
) sync* {
  final lib = unit.libraryElement;
  final topLevelClass = lib.topLevelElements.whereType<ClassElement>();
  for (var c in topLevelClass) {
    if (c.name.contains('Model')) {
      // final location = Location(path, c.nameOffset, c.nameLength, 0, 0);
      // yield AnalysisErrorFixes(
      //   AnalysisError(
      //     AnalysisErrorSeverity.ERROR,
      //     AnalysisErrorType.LINT,
      //     location,
      //     'The class contains Model',
      //     'class_contains_modelsdfsdfsfd',
      //     correction: 'Rename it',
      //     hasFix: false,
      //   ),
      // );
    }
  }
}
