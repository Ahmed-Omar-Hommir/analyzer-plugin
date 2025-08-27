import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/plugin/folding_mixin.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer_plugin/utilities/folding/folding.dart';

class MyPlugin extends ServerPlugin with DartFoldingMixin {
  MyPlugin() : super(resourceProvider: PhysicalResourceProvider.INSTANCE);

  @override
  List<String> get fileGlobsToAnalyze => <String>['**/*_provider.dart'];

  @override
  String get name => 'host_plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    // Create or overwrite a Dart file named "x.c.dart" in the same folder as [path].
    final folder = path.substring(0, path.lastIndexOf('/'));
    final newFilePath = '$folder/x.c.dart';
    final file = resourceProvider.getFile(newFilePath);
    file.writeAsStringSync('');
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

  @override
  List<FoldingContributor> getFoldingContributors(String path) => [];
}
