import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiz_olcer/video/local_video_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/local_video');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'platform source preserves source PTS and closes exactly once',
    () async {
      final calls = <MethodCall>[];
      var frame = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'pickVideo' => {
                'reference': 'content://approved/video',
                'displayName': 'test.mp4',
              },
              'openVideo' => {
                'sessionId': 'session-1',
                'width': 2,
                'height': 1,
                'durationUs': 9000,
              },
              'nextFrame' =>
                frame++ == 0
                    ? {
                        'width': 2,
                        'height': 1,
                        'timestampUs': 7123,
                        'rgb': Uint8List(6),
                      }
                    : null,
              'closeVideo' => null,
              _ => throw MissingPluginException(),
            };
          });

      final source = MethodChannelLocalVideoSource(channel: channel);
      final selection = await source.pickVideo();
      final session = await source.open(selection!);
      final decoded = await session.nextFrame();
      expect(decoded!.capture.timestampUs, 7123);
      expect(decoded.capture.lensId, 'local-video:session-1');
      expect(await session.nextFrame(), isNull);
      await session.close();
      await session.close();
      expect(calls.where((call) => call.method == 'closeVideo'), hasLength(1));
    },
  );

  test(
    'platform source rejects malformed bytes and non-monotonic PTS',
    () async {
      var next = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return switch (call.method) {
              'openVideo' => {
                'sessionId': 'session-2',
                'width': 1,
                'height': 1,
                'durationUs': 3,
              },
              'nextFrame' => switch (next++) {
                0 => {
                  'width': 1,
                  'height': 1,
                  'timestampUs': 2,
                  'rgb': Uint8List(3),
                },
                1 => {
                  'width': 1,
                  'height': 1,
                  'timestampUs': 2,
                  'rgb': Uint8List(3),
                },
                _ => {
                  'width': 1,
                  'height': 1,
                  'timestampUs': 3,
                  'rgb': Uint8List(2),
                },
              },
              'closeVideo' => null,
              _ => null,
            };
          });
      final source = MethodChannelLocalVideoSource(channel: channel);
      final selection = LocalVideoSelection(
        reference: 'ref',
        displayName: 'bad.mp4',
      );
      final session = await source.open(selection);
      await session.nextFrame();
      await expectLater(session.nextFrame(), throwsFormatException);
      await expectLater(session.nextFrame(), throwsFormatException);
      await session.close();
    },
  );
}
