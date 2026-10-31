import 'dart:io';

import 'package:hiz_olcer/offline/harness.dart';

void main(List<String> args) {
  if (args.length != 2 ||
      (File(args[1]).existsSync() &&
          FileSystemEntity.identicalSync(args[0], args[1]))) {
    stderr.writeln(
      'Usage: dart tool/run_offline_harness.dart input.json output.jsonl (distinct files)',
    );
    exitCode = 64;
    return;
  }
  try {
    final fixture = DetectionFixture.parse(File(args[0]).readAsStringSync());
    final output = OfflineHarness().run(fixture);
    File(args[1]).writeAsStringSync(output);
    stdout.writeln(
      '${fixture.frames.length} synthetic frames exported; no inference or speed.',
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
