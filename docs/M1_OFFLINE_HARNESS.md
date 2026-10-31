# M1 first slice: synthetic observation harness

M1 is **partial**, not complete. This module consumes hand-authored detection
annotations; it does not decode video, inspect pixels, run MediaPipe, detect an
object, estimate scale, or produce speed. Real-world tracking is unvalidated.
No model weights, runtime, decoder, dataset, plugin or dependency was added.

## License decision — updated detector slice

The synthetic harness remains model independent. A later, separate adapter now
bundles the TensorFlow EfficientDet-Lite0 metadata variation 1 artifact and uses
tflite_flutter 0.12.1. The artifact byte size, SHA-256, exact download URL,
Apache-2.0 evidence, embedded COCO label map, tensor contract and limitations are
recorded in `docs/models/inventory.json` and checked offline. Runtime and model
licensing are tracked separately in `THIRD_PARTY_NOTICES.md`.

This closes the prototype's named-model provenance gate, not the full M1 gate.
No approved local video decoder or real-video fixture is present, and neither
Android nor iOS device inference has been validated. Commercial release still
requires a fresh generated-binary notice audit and legal review.
The fixture and expected output in this change are repository-authored synthetic
numbers and annotations, with no personal images, recordings or external dataset.
See THIRD_PARTY_NOTICES.md. Do not substitute this fixture for failed inference.

## Run and reproduce

Use the pinned M0 toolchain and writable state documented in DEVELOPMENT.md.
In Cloud all network-capable invocations (including loopback tests) require the
explicit command-level additional network permission.

```
dart tool/run_offline_harness.dart assets/fixtures/occlusion.json /tmp/evidence.jsonl
cmp /tmp/evidence.jsonl test/fixtures/occlusion.expected.jsonl
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub
python3 tool/check_licenses.py
flutter build apk --debug --no-pub
```

The CLI requires distinct input/output files, validates the complete fixture
before writing, and returns nonzero on malformed input. It exports locally;
there is no upload. The application has a labeled offline screen and a button
that runs this same bundled synthetic fixture and displays selectable JSON Lines.
It provides no video picker, real detection overlay or numeric speed.

## Input schema 2

`schemaVersion: 2`, `origin: synthetic`, nonempty `fixtureId`, nonempty `frames`.
The mandatory `sourceManifest` has exactly these supported field values:

```json
{
  "timestampSource": "sourcePtsUs",
  "coordinateSystem": "normalizedTopLeft",
  "rotationDegrees": 0,
  "declaredFrameCount": 9,
  "detectionAdapter": {"type": "syntheticAnnotations", "version": "1"}
}
```

`declaredFrameCount` is a positive integer equal to the actual frame list length;
9 above is only this repository fixture's count. Rotation must be integer 0;
nonzero rotation is rejected rather than silently transformed. Coordinates have
origin at the top left, x increasing right and y increasing down, normalized to
[0,1]. Only the named adapter type and string version are supported. Missing,
wrongly typed or unsupported manifest values reject the whole fixture. Schema 1
is no longer accepted because it lacks this provenance contract.

`timestampSource` describes the `capture.timestampUs` values: original source PTS
in microseconds. Here those PTS values are hand-authored synthetic annotations,
not decoder output. Future decoded PTS must be supplied by the adapter; no UI
clock, assumed FPS, resampling or replacement timing is accepted/generated.

Each frame contains `capture` (monotonic integer `timestampUs`, nonempty `lensId`,
positive finite `zoom`, positive integer `width`/`height`) and `detections`.
Each observation has a frame-local unique nonempty `id`, `label`, `modelVersion`,
finite score in [0,1], and normalized `[x,y,width,height]` box inside the image.
Optional `selectDetectionId` must name an observation in that frame.
Missing/wrong types, invalid geometry, duplicate IDs and non-increasing timestamps
reject the complete fixture with FormatException. Timing never comes from the UI.

Exact case-sensitive annotation mapping: person -> person, bicycle -> bicycle,
vehicle/car -> vehicle (car means passenger-car annotation), ball -> coarse ball.
All other labels are unsupported; no detector-specific numeric class mapping or
ball subtype inference is assumed. In particular, a runtime's class-index table
must be independently reviewed before an adapter can use this mapping.

## Deterministic single-target policy

- An explicit selection starts a fresh identity. Without selection, exactly one
  supported annotation may start a track. Multiple supported annotations return
  ambiguous; no score-based or input-order tie breaking occurs.
- Existing tracks associate only when exactly one observation overlaps the last
  observed box with IoU >= 0.2 and has the same coarse class. Observation IDs are
  frame-local and never treated as persistent target IDs.
- More than one spatial candidate is ambiguous, including mixed/unsupported
  candidates. No candidate is selected or written as a current observation.
- Zero matches is a missed observation. Two missing/ambiguous frames are allowed;
  the third ends the identity as lost. Recovery inside this budget keeps the ID;
  recovery after loss acquires a new sequential ID. The budget counts supplied
  frames, not elapsed time, so omitted frames/long gaps are not simulated.
  **There is no elapsed-time timeout.** Even a very large PTS gap can retain an
  identity when the supplied frame miss budget has not expired and one spatial
  match exists. `lost` means that the configured count of supplied missed frames
  was exceeded, not that a real-time loss duration was measured. A time-based
  expiry policy remains unimplemented and must be chosen before real-video use.
- A unique spatial match with changed class ends the identity with classChanged
  (or unsupported). No silent target relabeling. A selected unsupported annotation
  also terminates the old track. Explicit selection always creates a new ID.
- Lens, zoom or image-size changes end any track and produce opticsChanged. That
  frame is not associated; a following unambiguous frame may acquire a fresh ID.
- A run always starts with fresh state; no wall-clock times or random IDs occur.
  IoU/budget are fixture association parameters, not measurement quality thresholds
  or evidence of accuracy. They are recorded in every exported frame.

No motion prediction, interpolation or fabricated boxes are emitted during gaps.
IoU alone cannot guarantee identity when objects cross, disappear or move far;
a unique overlap can still be wrong in real video. This limitation is explicit.

## Evidence schema 2

One JSON object per supplied frame, always in input order. Records include fixture
and synthetic provenance, harness version, frame index, original capture metadata,
all input observations/model identities, selection, unsupported IDs, policy,
state/reason, active/ended track ID, misses, observed observation ID and last
observed capture time. Every record includes the complete validated `sourceManifest` (timestamp source,
coordinate system, rotation, declared total frame count and adapter type/version).
Current observation is null during gaps or ambiguity. An all-empty sequence still
emits exactly one record per frame, with empty inputDetections; frames are not
filtered out. Variable PTS values and long gaps are preserved without invented FPS.

Canonical JSONL here means the deterministic writer's key order and encoding
under the pinned Dart SDK, not RFC 8785 canonicalization. Parsing, re-encoding
and parsing again preserves nested JSON meaning; a regression test also checks
byte stability of the writer's own output. It does not normalize arbitrary
third-party JSON key orders or provide cryptographic integrity.
`measurementAvailable` is always false; no numeric speed field is exported.
The expected JSONL is a regression artifact, checked alongside independent state,
identity and fail-closed assertions, not proof of detector or speed performance.

## Remaining M1 blockers

### Local-video prototype

The app now has a separate `Yerel video analizi` route. It uses the platform
document picker, decodes upright RGB frames on device, preserves source PTS and
runs up to the first 120 frames through the bundled EfficientDet adapter. The
screen reports only decoded-frame and coarse detection counts. It does not feed
the synthetic association harness, select a target, export real-video evidence,
or produce speed.

Android follows the platform `ACTION_OPEN_DOCUMENT` and MediaCodec path. iOS
uses a copied document-picker result and AVAssetReader BGRA output. Platform API
sources:

- https://developer.android.com/training/data-storage/shared/documents-files
- https://developer.android.com/reference/android/media/MediaExtractor
- https://developer.android.com/reference/android/media/MediaCodec
- https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller
- https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput

Required iOS Mac check:

1. Open `ios/Runner.xcworkspace` in the repository's pinned Xcode environment.
2. Build the `Runner` scheme for an iOS 15+ simulator and a physical reference
   iPhone; record Xcode, iOS and device model.
3. Open `Yerel video analizi`; verify picker cancellation returns without an
   error and a short portrait/landscape video starts analysis.
4. Verify decoded dimensions are upright, the UI remains responsive, the first
   120-frame limit is disclosed, and no numeric speed appears.
5. Repeat selection and a decoder failure to check sessions are released and no
   previous detections are reused.

GitHub Actions run 41252643668 compiled the Swift code into an iOS simulator app
with Xcode 16.4. Until the runtime checklist above is recorded, picker/decoder
behavior and performance on an iPhone are not verified.

- Runtime source-content hashing and binding a source artifact to each evidence
  record are deferred. fixtureId and adapter metadata are declarations, not
  cryptographic content identity. No crypto dependency was added. Repository
  validation-file SHA-256 values are build evidence only and do not close this
  harness provenance/integrity gap.

- Run the bundled model on physical Android and iOS devices and retain an
  approved non-personal smoke-test artifact; desktop unit tests do not establish
  mobile runtime compatibility or detection quality.
- Validate the local video import/decoder and capture metadata adapter on named
  reference devices with approved portrait and landscape fixtures.
- Connect a licensed real detector to observations and validate tracking on
  approved videos. No real-video detection or tracking success is claimed here.
- iOS compilation/runtime still require Mac/Xcode; use DEVELOPMENT.md checklist
  and also run the offline screen and synthetic scenario on the simulator.
