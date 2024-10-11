// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'common/service_test_common.dart';
import 'common/test_helper.dart';

// AUTOGENERATED START
//
// Update these constants by running:
//
// dart pkg/vm_service/test/update_line_numbers.dart <test.dart>
//
const LINE_A = 22;
// AUTOGENERATED END

const file = 'step_through_mixin_from_sdk_test.dart';

void code() {
  final foo = Foo(); // LINE_A
  if (foo.contains(43)) {
    print('Contains 43!');
  } else {
    print("Doesn't contain 43!");
  }
}

class Foo extends Object with ListMixin<int> {
  @override
  int length = 1;

  @override
  int operator [](int index) {
    return 42;
  }

  @override
  void operator []=(int index, int value) {}
}

// THIS TEST ASSUMES SPECIFIC CODE AT SPECIFIC LINES OF PLATFORM LIBRARIES.
// THE TEST IS FRAGILE AGAINST UNRELATED CHANGES.

// Print updated lines by setting `debugPrint` to `true` below.

final stops = <String>[];
const expected = <String>[
  '$file:${LINE_A + 0}:15', // on 'Foo' (in 'Foo()')
  '$file:${LINE_A + 1}:11', // on 'contains'
  'list.dart:89:25', // on parameter to 'contains'
  'list.dart:90:23', // on 'length' in 'this.length'
  'list.dart:91:16', // on '=' in 'i = 0'
  'list.dart:91:23', // on '<' in 'i < length'
  'list.dart:92:15', // on '[' in 'this[i]'
  '$file:${LINE_A + 13}:23', // on parameter in 'operator []'
  '$file:${LINE_A + 14}:5', // on 'return'
  'list.dart:92:19', // on '=='
  'list.dart:93:26', // on 'length' in 'this.length'
  'list.dart:93:18', // on '!='
  'list.dart:91:34', // on '++' in 'i++'
  'list.dart:91:23', // on '<' in 'i < length'
  'list.dart:97:5', // on 'return'
  '$file:${LINE_A + 4}:5', // on 'print'
  '$file:${LINE_A + 6}:1', // on ending '}'
];

final tests = <IsolateTest>[
  hasPausedAtStart,
  setBreakpointAtLine(LINE_A),
  runStepIntoThroughProgramRecordingStops(stops),
  checkRecordedStops(
    stops,
    expected,
    removeDuplicates: true,
    debugPrint: false,
  ),
];

void main([args = const <String>[]]) => runIsolateTests(
      args,
      tests,
      'step_through_mixin_from_sdk_test.dart',
      testeeConcurrent: code,
      pauseOnStart: true,
      pauseOnExit: true,
    );
