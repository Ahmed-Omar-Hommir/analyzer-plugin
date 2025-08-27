import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer_plugin/utilities/folding/folding.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'dart:convert';

class MyPlugin extends ServerPlugin {
  MyPlugin() : super(resourceProvider: PhysicalResourceProvider.INSTANCE);

  // Track processed files with their last modification time and content hash
  final Map<String, _FileInfo> _processedFiles = <String, _FileInfo>{};

  // Cache for parsed ASTs to avoid re-parsing unchanged files
  final Map<String, CompilationUnit> _astCache = <String, CompilationUnit>{};

  // Cache for generated content to avoid unnecessary file writes
  final Map<String, String> _generatedContentCache = <String, String>{};

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

      // Check if file exists
      final file = resourceProvider.getFile(path);
      if (!file.exists) {
        // Remove from cache if file was deleted
        _processedFiles.remove(path);
        _astCache.remove(path);
        return;
      }

      // Get current file info
      final currentContent = file.readAsStringSync();
      final currentHash = _calculateHash(currentContent);

      // Check if file has actually changed
      final previousInfo = _processedFiles[path];
      if (previousInfo != null && previousInfo.contentHash == currentHash) {
        // File content hasn't changed, skip processing
        print('🔄 Skipping unchanged file: ${path.split('/').last}');
        return;
      }

      print('⚡ Processing changed file: ${path.split('/').last}');

      // File has changed, process it
      final commandFunctions = _findCommandFunctions(currentContent, path);

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

      // Update processed files cache with new info
      _processedFiles[path] = _FileInfo(
        modificationTime: DateTime.now(),
        contentHash: currentHash,
      );

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

  String _calculateHash(String content) {
    return base64.encode(utf8.encode(content)).substring(0, 16);
  }

  void _cleanupCache() {
    // Keep only the last 100 processed files to prevent memory leaks
    if (_processedFiles.length > 100) {
      final sortedEntries = _processedFiles.entries.toList()
        ..sort((a, b) =>
            a.value.modificationTime.compareTo(b.value.modificationTime));

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

class _FileInfo {
  final DateTime modificationTime;
  final String contentHash;

  _FileInfo({
    required this.modificationTime,
    required this.contentHash,
  });
}
