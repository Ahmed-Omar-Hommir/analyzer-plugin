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
    collector.addSuggestion(
      CompletionSuggestion(
        CompletionSuggestionKind.KEYWORD,
        1000, // Relevance score.
        'ahmed', // The keyword to suggest.
        0, // Offset for replacement.
        'import'.length, // Length of the completion.
        false, // Not deprecated.
        false, // Not potential.
        displayText: 'import',
      ),
    );

    collector.addSuggestion(
      CompletionSuggestion(
        CompletionSuggestionKind.KEYWORD,
        900, // Lower relevance for 'export'.
        'export',
        0,
        'export'.length,
        false,
        false,
        displayText: 'export',
      ),
    );

    collector.addSuggestion(
      CompletionSuggestion(
        CompletionSuggestionKind.KEYWORD,
        800, // Lower relevance for 'part'.
        'part',
        0,
        'part'.length,
        false,
        false,
        displayText: 'part',
      ),
    );

    // If you need more suggestions, add them similarly.
  }
}
