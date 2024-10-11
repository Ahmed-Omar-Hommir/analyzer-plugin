// import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';

// import 'rules/import_rule.dart';

class MyPlugin extends ServerPlugin {
  MyPlugin() : super(resourceProvider: PhysicalResourceProvider.INSTANCE);

  @override
  List<String> get fileGlobsToAnalyze => <String>['**/*.dart'];

  @override
  String get name => 'host_plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    // final unit = await analysisContext.currentSession.getResolvedUnit(path);
    final errors = [
      AnalysisError(
        AnalysisErrorSeverity.ERROR,
        AnalysisErrorType.LINT,
        Location(path, 0, 0, 0, 0),
        'Test',
        'Test',
        correction: 'Test',
        hasFix: false,
      ),
      // if (unit is ResolvedUnitResult)
      //   ...validate(path, unit).map((e) => e.error),
    ];
    channel
        .sendNotification(AnalysisErrorsParams(path, errors).toNotification());
  }

  @override
  Future<void> analyzeFiles({
    required AnalysisContext analysisContext,
    required List<String> paths,
  }) {
    if (paths.isEmpty) return Future.value();
    return super.analyzeFiles(
      analysisContext: analysisContext,
      paths: paths,
    );
  }
}
