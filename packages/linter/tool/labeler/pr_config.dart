// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:linter/src/utils.dart';

import '../machine.dart';

/// Generate PR labeler workflow config data.
void main(List<String> args) async {
  var rulesFile = machineJsonFile();
  var req = rulesFile.readAsStringSync();

  var machine = json.decode(req) as Iterable<Object?>;

  var coreLints = <String>[];
  var recommendedLints = <String>[];
  var flutterLints = <String>[];
  for (var entry in machine) {
    if (entry case {'name': String name, 'sets': List<Object?> sets}) {
      if (sets.contains('core')) {
        coreLints.add(name);
      } else if (sets.contains('recommended')) {
        recommendedLints.add(name);
      } else if (sets.contains('flutter')) {
        flutterLints.add(name);
      }
    }
  }

  // TODO(pq): consider a local cache of internally available rules.

  printToConsole('# Auto-generated by `tool/labeler/pr_config.dart`');

  printToConsole('\nset-core:');
  for (var lint in coreLints.sorted()) {
    printToConsole('- lib/**/$lint.dart');
  }
  printToConsole('\nset-recommended:');
  for (var lint in recommendedLints.sorted()) {
    printToConsole('- lib/**/$lint.dart');
  }
  printToConsole('\nset-flutter:');
  for (var lint in flutterLints.sorted()) {
    printToConsole('- lib/**/$lint.dart');
  }
}
