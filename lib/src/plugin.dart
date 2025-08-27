import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/plugin/folding_mixin.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer_plugin/utilities/folding/folding.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

class MyPlugin extends ServerPlugin with DartFoldingMixin {
  MyPlugin() : super(resourceProvider: PhysicalResourceProvider.INSTANCE);

  // Track processed files with their last modification time for incremental analysis
  final Map<String, DateTime> _processedFiles = <String, DateTime>{};

  // Cache for parsed ASTs to avoid re-parsing unchanged files
  final Map<String, CompilationUnit> _astCache = <String, CompilationUnit>{};

  // Cache for generated content to avoid unnecessary file writes
  final Map<String, String> _generatedContentCache = <String, String>{};

  @override
  List<String> get fileGlobsToAnalyze => <String>['**/*_provider.dart'];

  @override
  bool get isCompatibleWithDart2 => true;

  @override
  String get name => 'host_plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    try {
      // Skip if this is an x.c.dart file to avoid infinite loops
      if (path.endsWith('x.c.dart')) {
        return;
      }

      // Skip if this is not a provider file
      if (!path.contains('_provider.dart')) {
        return;
      }

      // Skip generated files
      if (path.contains('.g.dart') ||
          path.contains('.freezed.dart') ||
          path.contains('.gen.dart')) {
        return;
      }

      // Check if file needs processing (incremental analysis)
      final file = resourceProvider.getFile(path);
      if (!file.exists) {
        return;
      }

      // For now, we'll process files on every analysis cycle
      // In a more sophisticated implementation, you could track file hashes
      final lastProcessed = _processedFiles[path];
      final currentTime = DateTime.now();

      // Skip if file was processed very recently (within 1 second)
      if (lastProcessed != null &&
          currentTime.difference(lastProcessed).inSeconds < 1) {
        return;
      }

      // Read the source file content
      final contents = file.readAsStringSync();

      // Parse the Dart file to find @command functions
      final commandFunctions = _findCommandFunctions(contents, path);

      // Create or overwrite a Dart file named "x.c.dart" in the same folder as [path].
      final folder = path.substring(0, path.lastIndexOf('/'));
      final newFilePath = '$folder/x.c.dart';
      final outputFile = resourceProvider.getFile(newFilePath);

      // Generate the content for x.c.dart
      final generatedContent = _generateXCDartContent(commandFunctions);

      // Only write if content has changed
      final existingContent = _generatedContentCache[newFilePath];
      if (existingContent != generatedContent) {
        outputFile.writeAsStringSync(generatedContent);
        _generatedContentCache[newFilePath] = generatedContent;
      }

      // Update processed files cache
      _processedFiles[path] = currentTime;

      // Clean up old cache entries to prevent memory leaks
      _cleanupCache();
    } catch (e) {
      // Don't print errors to avoid flooding the console
      // print('Error analyzing file $path: $e');
    }
  }

  List<String> _findCommandFunctions(String contents, String filePath) {
    final List<String> commandFunctions = [];

    try {
      // Skip if content is empty or too large
      if (contents.isEmpty || contents.length > 1000000) {
        return commandFunctions;
      }

      // Check if we have a cached AST for this content
      CompilationUnit? unit;
      if (_astCache.containsKey(filePath)) {
        unit = _astCache[filePath];
      } else {
        // Parse asynchronously if possible, otherwise use sync
        unit = parseString(content: contents).unit;
        _astCache[filePath] = unit;
      }

      if (unit == null) return commandFunctions;

      for (final declaration in unit.declarations) {
        if (declaration is FunctionDeclaration) {
          // Check if function has @command annotation
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
          // Check for @command methods in classes
          for (final member in declaration.members) {
            if (member is MethodDeclaration) {
              bool hasCommandAnnotation = false;
              for (final meta in member.metadata) {
                final name =
                    meta.name.name + (meta.constructorName?.name ?? '');
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
    } catch (e) {
      // Don't print errors to avoid flooding the console
      // print('Error parsing file $filePath: $e');
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

    // Add a function to get the list of command functions
    buffer.writeln('List<String> getCommandFunctions() {');
    buffer.writeln('  return [');
    for (final functionName in commandFunctions) {
      buffer.writeln('    "$functionName",');
    }
    buffer.writeln('  ];');
    buffer.writeln('}');

    return buffer.toString();
  }

  void _cleanupCache() {
    // Keep only the last 100 processed files to prevent memory leaks
    if (_processedFiles.length > 100) {
      final sortedEntries = _processedFiles.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final toRemove = sortedEntries.take(_processedFiles.length - 100);
      for (final entry in toRemove) {
        _processedFiles.remove(entry.key);
        _astCache.remove(entry.key);
      }
    }

    // Clean up generated content cache for files that no longer exist
    final keysToRemove = <String>[];
    for (final key in _generatedContentCache.keys) {
      final file = resourceProvider.getFile(key);
      if (!file.exists) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _generatedContentCache.remove(key);
    }
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

  // Clear processed files cache (useful for testing)
  void clearProcessedFiles() {
    _processedFiles.clear();
    _astCache.clear();
    _generatedContentCache.clear();
  }
}
