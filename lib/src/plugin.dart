import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/plugin/completion_mixin.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
// ignore: implementation_imports
import 'package:analyzer_plugin/src/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/utilities/completion/completion_core.dart';

import 'rules/import_rule.dart';

class MyPlugin extends ServerPlugin with CompletionMixin {
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
    final unit = await analysisContext.currentSession.getResolvedUnit(path);
    final errors = [
      if (unit is ResolvedUnitResult)
        ...validate(path, unit).map((e) => e.error),
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

  @override
  List<CompletionContributor> getCompletionContributors(String path) {
    return [MyCompletionContributor()];
  }

  @override
  Future<CompletionRequest> getCompletionRequest(
      CompletionGetSuggestionsParams parameters) async {
    var result = await getResolvedUnitResult(parameters.file);
    return DartCompletionRequestImpl(
      resourceProvider,
      parameters.offset,
      result,
    );
  }
}

class MyCompletionContributor implements CompletionContributor {
  @override
  Future<void> computeSuggestions(
    DartCompletionRequest request,
    CompletionCollector collector,
  ) async {
    // Check if the request is canceled before proceeding.
    request.checkAborted();

    // Add some simple keyword suggestions.
    // collector.addSuggestion(
    //   CompletionSuggestion(
    //     CompletionSuggestionKind.INVOCATION, // Type of suggestion.
    //     999999, // Relevance score.
    //     'void sayHello(String name) {\n print("Hello \$name"); \n}', // The code to insert.
    //     request.offset, // Offset for replacement.
    //     'void sayHello(String name) {\n print("Hello \$name"); \n}'
    //         .length, // Length of the completion.
    //     false, // Not deprecated.
    //     false, // Not potential.
    //     displayText: 'sayHello', // What is displayed in the suggestions list.
    //   ),
    // );

    collector.filterSuggestion((suggestion) => true);

    // If you need more suggestions, add them similarly.
  }
}
