# M1 first slice: synthetic observation harness

M1 is **partial**, not complete. This module consumes hand-authored detection
annotations; it does not decode video, inspect pixels, run MediaPipe, detect an
object, estimate scale, or produce speed. Real-world tracking is unvalidated.
No model weights, runtime, decoder, dataset, plugin or dependency was added.

## License decision

The official google-ai-edge/mediapipe runtime repository is Apache-2.0:
https://github.com/google-ai-edge/mediapipe/blob/master/LICENSE
That runtime license does not establish redistribution rights for separately
published EfficientDet/MediaPipe weights. No weights have been downloaded or
accepted. A specific model artifact needs a verifiable accompanying license,
commercial redistribution review and provenance before integration.
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

## Input schema 1

`schemaVersion: 1`, `origin: synthetic`, nonempty `fixtureId`, nonempty `frames`.
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

## Evidence schema 1

One JSON object per supplied frame, always in input order. Records include fixture
and synthetic provenance, harness version, frame index, original capture metadata,
all input observations/model identities, selection, unsupported IDs, policy,
state/reason, active/ended track ID, misses, observed observation ID and last
observed capture time. Current observation is null during gaps or ambiguity.
`measurementAvailable` is always false; no numeric speed field is exported.
The expected JSONL is a regression artifact, checked alongside independent state,
identity and fail-closed assertions, not proof of detector or speed performance.

## Remaining M1 blockers

- Accept a specific model's verifiable commercial redistribution license and
  artifact provenance, then review the runtime/model as separate components.
- Implement local video import/decoder and capture metadata adapter. Preserve
  timestamps, rotation/image transforms, lens/zoom provenance and frame lifetime.
- Connect a licensed real detector to observations and validate tracking on
  approved videos. No real-video detection or tracking success is claimed here.
- iOS compilation/runtime still require Mac/Xcode; use DEVELOPMENT.md checklist
  and also run the offline screen and synthetic scenario on the simulator.
