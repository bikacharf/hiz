import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiz_olcer/offline/harness.dart';

Map<String, Object?> detection(
  String id, {
  String label = 'person',
  double x = .1,
}) => {
  'id': id,
  'label': label,
  'box': [x, .1, .3, .5],
  'score': .9,
  'modelVersion': 'synthetic-test-only',
};
Map<String, Object?> frame(
  int time,
  List<Map<String, Object?>> detections, {
  String lens = 'wide',
  double zoom = 1,
  String? selection,
}) => {
  'capture': {
    'timestampUs': time,
    'lensId': lens,
    'zoom': zoom,
    'width': 640,
    'height': 480,
  },
  'detections': detections,
  'selectDetectionId': selection,
};
String source(List<Map<String, Object?>> frames) => jsonEncode({
  'schemaVersion': 1,
  'origin': 'synthetic',
  'fixtureId': 'test',
  'frames': frames,
});
List<Map<String, dynamic>> run(List<Map<String, Object?>> frames) =>
    const LineSplitter()
        .convert(OfflineHarness().run(DetectionFixture.parse(source(frames))))
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();

void main() {
  test('authored fixture is repeatable byte-for-byte and matches reviewed evidence', () {
    final fixture = DetectionFixture.parse(
      File('assets/fixtures/occlusion.json').readAsStringSync(),
    );
    final harness = OfflineHarness();
    final output = harness.run(fixture);
    expect(harness.run(fixture), output);
    expect(
      output,
      File('test/fixtures/occlusion.expected.jsonl').readAsStringSync(),
    );
    final records = const LineSplitter()
        .convert(output)
        .map((s) => jsonDecode(s) as Map)
        .toList();
    expect(records.map((r) => r['state']), [
      'acquired',
      'tracked',
      'occluded',
      'tracked',
      'occluded',
      'occluded',
      'lost',
      'acquired',
      'tracked',
    ]);
    expect(records[3]['trackId'], records[0]['trackId']);
    expect(records[7]['trackId'], isNot(records[0]['trackId']));
    expect(records[2]['observedDetectionId'], isNull);
    expect(
      records.every(
        (r) => r['measurementAvailable'] == false && !r.containsKey('speed'),
      ),
      isTrue,
    );
  });
  test(
    'coarse class mapping is explicit; unknown labels remain unsupported',
    () {
      for (final label in [
        'person',
        'bicycle',
        'vehicle',
        'car',
        'ball',
        'dog',
      ]) {
        final result = run([
          frame(0, [detection('a', label: label)]),
        ]).single;
        expect(result['state'], label == 'dog' ? 'unsupported' : 'acquired');
        expect(
          (result['inputDetections'] as List).single['class'],
          label == 'car'
              ? 'vehicle'
              : label == 'dog'
              ? null
              : label,
        );
      }
    },
  );
  test('association uses geometry rather than observation ID and expires after gap', () {
    final result = run([
      frame(0, [detection('a')]),
      frame(1, []),
      frame(2, [detection('new-id', x: .12)]),
      frame(3, []),
      frame(4, []),
      frame(5, []),
      frame(6, [detection('a')]),
    ]);
    expect(result[2]['state'], 'tracked');
    expect(result[2]['trackId'], result[0]['trackId']);
    expect(result[5]['state'], 'lost');
    expect(result[5]['endedTrackId'], result[0]['trackId']);
    expect(result[6]['trackId'], isNot(result[0]['trackId']));
  });
  test('ambiguous initial target requires an explicit supported selection', () {
    final choices = [detection('a'), detection('b', x: .6)];
    expect(run([frame(0, choices)]).single['state'], 'ambiguous');
    final selected = run([frame(0, choices, selection: 'b')]).single;
    expect(selected['observedDetectionId'], 'b');
    expect(
      () => DetectionFixture.parse(
        source([frame(0, choices, selection: 'missing')]),
      ),
      throwsFormatException,
    );
  });
  test(
    'multiple spatial matches fail closed regardless of order, then expire',
    () {
      for (final choices in [
        [detection('b'), detection('c', x: .12)],
        [detection('c', x: .12), detection('b')],
      ]) {
        final records = run([
          frame(0, [detection('a')]),
          frame(1, choices),
          frame(2, choices),
          frame(3, choices),
        ]);
        expect(records[1]['state'], 'ambiguous');
        expect(records[1]['observedDetectionId'], isNull);
        expect(records[1]['lastObservedTimestampUs'], 0);
        expect(records[3]['state'], 'lost');
      }
    },
  );
  test('class changes end identity rather than silently relabeling it', () {
    final records = run([
      frame(0, [detection('a')]),
      frame(1, [detection('b', label: 'bicycle')]),
      frame(2, [detection('c', label: 'bicycle')]),
    ]);
    expect(records[1]['state'], 'classChanged');
    expect(records[1]['trackId'], isNull);
    expect(records[2]['trackId'], isNot(records[0]['trackId']));
    expect(
      run([
        frame(0, [detection('a')]),
        frame(1, [detection('b', label: 'dog')]),
      ])[1]['state'],
      'unsupported',
    );
  });
  test(
    'lens and zoom discontinuities end tracks; changed frame is not associated',
    () {
      for (final changed in [
        frame(1, [detection('b')], lens: 'tele'),
        frame(1, [detection('b')], zoom: 2),
      ]) {
        final records = run([
          frame(0, [detection('a')]),
          changed,
        ]);
        expect(records[1]['state'], 'opticsChanged');
        expect(records[1]['trackId'], isNull);
        expect(records[1]['observedDetectionId'], isNull);
        expect(records[1]['endedTrackId'], records[0]['trackId']);
      }
    },
  );
  test(
    'timestamps, provenance, duplicate IDs, geometry and policy are validated',
    () {
      for (final time in [0, -1]) {
        expect(
          () => DetectionFixture.parse(source([frame(0, []), frame(time, [])])),
          throwsFormatException,
        );
      }
      expect(
        () => DetectionFixture.parse(
          source([
            frame(0, [detection('a'), detection('a')]),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => DetectionFixture.parse(
          source([
            frame(0, [detection('a', x: .9)]),
          ]),
        ),
        throwsFormatException,
      );
      expect(() => DetectionFixture.parse(source([])), throwsFormatException);
      expect(
        () => DetectionFixture.parse(
          source([frame(0, [])]).replaceFirst('synthetic', 'video'),
        ),
        throwsFormatException,
      );
      expect(() => OfflineHarness(minimumIou: double.nan), throwsArgumentError);
      expect(() => OfflineHarness(maxMissedFrames: -1), throwsArgumentError);
    },
  );
  test('unsupported explicit selection terminates a previous target', () {
    final records = run([
      frame(0, [detection('a')]),
      frame(1, [
        detection('unsupported', label: 'dog'),
      ], selection: 'unsupported'),
    ]);
    expect(records[1]['state'], 'unsupported');
    expect(records[1]['trackId'], isNull);
    expect(records[1]['endedTrackId'], records[0]['trackId']);
  });
}
