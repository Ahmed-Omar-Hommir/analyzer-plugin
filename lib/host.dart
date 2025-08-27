import 'dart:isolate';

import 'package:analyzer_plugin/starter.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:host_plugin/src/plugin.dart';

void start(List<String> args, SendPort sendPort) async {
  final resourceProvider = PhysicalResourceProvider.INSTANCE;
  ServerPluginStarter(
    MyPlugin(resourceProvider: resourceProvider),
  ).start(sendPort);
}
