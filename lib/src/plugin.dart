import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/src/dart/analysis/file_content_cache.dart';
import 'package:analyzer_plugin/channel/channel.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'dart:io' as io;
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer/dart/ast/ast.dart';

// Define your plugin class, extending ServerPlugin
class MyPlugin extends ServerPlugin {
  MyPlugin({required ResourceProvider resourceProvider})
      : super(resourceProvider: resourceProvider);

  final Map<String, String> _generatedContentCache = <String, String>{};
  AnalysisContextCollection? _contextCollection;

  @override
  List<String> get fileGlobsToAnalyze => <String>['**/*_provider.dart'];

  @override
  String get name => 'host_plugin';

  @override
  String get version => '1.0.0';

  List<String> get methods => <String>[];

  @override
  void start(PluginCommunicationChannel channel) {
    super.start(channel);
    _contextCollection = AnalysisContextCollectionImpl(
      resourceProvider: resourceProvider,
      includedPaths: [resourceProvider.pathContext.current],
      sdkPath: null,
      byteStore: MemoryByteStore(),
      fileContentCache: FileContentCache(resourceProvider),
    );
  }

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    // This is a required method but we don't need to implement error analysis
    // for our code generation plugin
  }

  // This is the key method to override for real-time updates
  @override
  Future<AnalysisUpdateContentResult> handleAnalysisUpdateContent(
      AnalysisUpdateContentParams parameters) async {
    print('🔍 [PLUGIN] handleAnalysisUpdateContent called');
    print('🔍 [PLUGIN] Files changed: ${parameters.files.keys}');

    // Process the overlay changes first, as the base class does
    final baseResult = await super.handleAnalysisUpdateContent(parameters);

    // After the base class updates the resourceProvider's overlay,
    // we can access the content and trigger our generation.
    var changedPaths = <String>{};
    parameters.files.forEach((String path, Object? overlay) {
      print('🔍 [PLUGIN] Checking path: $path');
      // Only process files matching your glob
      if (_matchesFileGlob(path)) {
        print('🔍 [PLUGIN] Path matches glob: $path');
        changedPaths.add(path);
      }
    });

    print('🔍 [PLUGIN] Changed paths to process: $changedPaths');

    // Trigger generation for each changed file
    var contextCollection = _contextCollection;
    if (contextCollection != null) {
      for (final path in changedPaths) {
        print('🔍 [PLUGIN] Processing generation for: $path');
        final analysisContext = contextCollection.contextFor(path);
        await _performGeneration(analysisContext, path);
      }
    } else {
      print('🔍 [PLUGIN] No context collection available');
    }

    return baseResult;
  }

  // You can also consider handleAnalysisHandleWatchEvents for disk saves
  // if handleAnalysisUpdateContent isn't sufficient for all scenarios.
  @override
  Future<AnalysisHandleWatchEventsResult> handleAnalysisHandleWatchEvents(
      AnalysisHandleWatchEventsParams parameters) async {
    final baseResult = await super.handleAnalysisHandleWatchEvents(parameters);

    var contextCollection = _contextCollection;
    if (contextCollection != null) {
      for (var event in parameters.events) {
        if (event.type == WatchEventType.MODIFY) {
          // Check if this path is one we care about
          if (_matchesFileGlob(event.path)) {
            final analysisContext = contextCollection.contextFor(event.path);
            await _performGeneration(analysisContext, event.path);
          }
        } else if (event.type == WatchEventType.REMOVE) {
          if (_matchesFileGlob(event.path)) {
            _handleFileDeletion(event.path);
          }
        }
      }
    }

    return baseResult;
  }

  // Centralized generation logic
  Future<void> _performGeneration(
      AnalysisContext analysisContext, String path) async {
    print('🔍 [PLUGIN] _performGeneration called for: $path');

    // Skip generated files and non-provider files as before
    if (path.endsWith('x.c.dart') ||
        !path.contains('_provider.dart') ||
        path.contains('.g.dart') ||
        path.contains('.freezed.dart') ||
        path.contains('.gen.dart')) {
      print('🔍 [PLUGIN] Skipping file: $path');
      return;
    }

    print('🔍 [PLUGIN] Processing file: $path');

    // Use getParsedUnit for efficient AST retrieval
    final parseResult = analysisContext.currentSession.getParsedUnit(path);

    if (parseResult is! ParsedUnitResult) {
      print('🔍 [PLUGIN] Failed to parse file: $path');
      // If parsing fails, we cannot proceed with generation for this file.
      return;
    }

    print('🔍 [PLUGIN] Successfully parsed file: $path');

    final commandFunctions = _findCommandFunctions(parseResult.unit);
    print('🔍 [PLUGIN] Found command functions: $commandFunctions');

    final folder =
        path.substring(0, path.lastIndexOf(io.Platform.pathSeparator));
    final newFilePath = '$folder/x.c.dart';
    final outputFile = resourceProvider.getFile(newFilePath);

    print('🔍 [PLUGIN] Output file path: $newFilePath');

    final generatedContent = _generateXCDartContent(commandFunctions);
    final existingCachedContent = _generatedContentCache[newFilePath];

    print('🔍 [PLUGIN] Generated content length: ${generatedContent.length}');
    print(
        '🔍 [PLUGIN] Cached content length: ${existingCachedContent?.length ?? 0}');

    if (existingCachedContent != generatedContent) {
      print('🔍 [PLUGIN] Content changed, writing to file');
      outputFile.writeAsStringSync(generatedContent);
      _generatedContentCache[newFilePath] = generatedContent;
      print('🔍 [PLUGIN] File written successfully');
    } else {
      print('🔍 [PLUGIN] Content unchanged, skipping write');
    }
  }

  // Helper to check against file globs (simplified for example)
  bool _matchesFileGlob(String path) {
    print('🔍 [PLUGIN] _matchesFileGlob checking: $path');
    // A more robust glob matching would be needed for complex patterns.
    // For now, let's assume it checks for '_provider.dart' as in your original.
    final matches = path.contains('_provider.dart');
    print('🔍 [PLUGIN] _matchesFileGlob result: $matches');
    return matches;
  }

  List<String> _findCommandFunctions(CompilationUnit unit) {
    final List<String> commandFunctions = [];

    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration) {
        bool hasCommandAnnotation = false;
        for (final meta in declaration.metadata) {
          final name = meta.name.name + (meta.constructorName?.name ?? '');
          if ({
            'command',
            'commandDroppable',
            'commandRestartable',
            'commandConcurrent',
            'commandSequential',
          }.contains(name)) {
            hasCommandAnnotation = true;
            break;
          }
        }
        if (hasCommandAnnotation) {
          commandFunctions.add(declaration.name.lexeme);
        }
      } else if (declaration is ClassDeclaration) {
        for (final member in declaration.members) {
          if (member is MethodDeclaration) {
            bool hasCommandAnnotation = false;
            for (final meta in member.metadata) {
              final name = meta.name.name + (meta.constructorName?.name ?? '');
              if ({
                'command',
                'commandDroppable',
                'commandRestartable',
                'commandConcurrent',
                'commandSequential',
              }.contains(name)) {
                hasCommandAnnotation = true;
                break;
              }
            }
            if (hasCommandAnnotation) {
              commandFunctions
                  .add('${declaration.name.lexeme}.${member.name.lexeme}');
            }
          }
        }
      }
    }
    return commandFunctions;
  }

  String _generateXCDartContent(List<String> commandFunctions) {
    final buffer = StringBuffer();

    buffer.writeln('// Generated file - do not edit manually');
    buffer
        .writeln('// Contains @command function names found in this directory');
    buffer.writeln();

    buffer.writeln('void printCommandFunctions() {');
    buffer.writeln('  print("Found @command functions:");');

    if (commandFunctions.isEmpty) {
      buffer.writeln('  print("  - No @command functions found");');
    } else {
      for (final functionName in commandFunctions) {
        buffer.writeln('  print("  - $functionName");');
      }
    }

    buffer.writeln('}');
    buffer.writeln();

    buffer.writeln('List<String> getCommandFunctions() {');
    buffer.writeln('  return [');
    for (final functionName in commandFunctions) {
      buffer.writeln('    "$functionName",');
    }
    buffer.writeln('  ];');
    buffer.writeln('}');

    return buffer.toString();
  }

  void _handleFileDeletion(String originalFilePath) {
    final folder = originalFilePath.substring(
        0, originalFilePath.lastIndexOf(io.Platform.pathSeparator));
    final generatedFilePath = '$folder/x.c.dart';
    final generatedFile = resourceProvider.getFile(generatedFilePath);
    if (generatedFile.exists) {
      try {
        generatedFile.delete();
        _generatedContentCache.remove(generatedFilePath);
      } catch (e) {
        // Log error if necessary
      }
    }
  }
}
