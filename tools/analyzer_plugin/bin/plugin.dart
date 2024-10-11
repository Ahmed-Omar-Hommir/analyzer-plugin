import 'dart:isolate';

import 'package:host_plugin/host.dart';

void main(List<String> args, SendPort sendPort) async {
  start(args, sendPort);
}
