import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/plugin/folding_mixin.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer_plugin/utilities/folding/folding.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

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
    try {
      // Read the source file content
      final file = resourceProvider.getFile(path);
      final contents = file.readAsStringSync();

      // Parse the Dart file to find @command functions
      final commandFunctions = _findCommandFunctions(contents, path);

      // Create or overwrite a Dart file named "x.c.dart" in the same folder as [path].
      final folder = path.substring(0, path.lastIndexOf('/'));
      final newFilePath = '$folder/x.c.dart';
      final outputFile = resourceProvider.getFile(newFilePath);

      // Generate the content for x.c.dart
      final generatedContent = _generateXCDartContent(commandFunctions);
      outputFile.writeAsStringSync(generatedContent);
    } catch (e) {
      print('Error analyzing file $path: $e');
    }
  }

  List<String> _findCommandFunctions(String contents, String filePath) {
    final List<String> commandFunctions = [];

    try {
      final unit = parseString(content: contents).unit;

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
      print('Error parsing file $filePath: $e');
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
