# Technical architecture

## Proposed stack

- Flutter application shell for shared navigation, product screens, state, local history, and entitlement UI.
- Swift native package/plugin for AVFoundation capture, Vision/Core ML integration, motion sensors, and optional ARKit signals.
- Kotlin native package/plugin for CameraX capture, on-device inference, motion sensors, and optional ARCore signals.
- Local persistence for sessions and metadata. No backend is required for the feasibility prototype.

This is a starting decision, not a claim that all vision code can be shared. Platform-specific capture correctness takes priority over maximum code sharing.

## Module boundaries

1. `capture`: timestamped frames, camera metadata, lens/zoom state, exposure, and stabilization signals.
2. `detection`: object class, bounding box/keypoints, detection score, and model identity.
3. `tracking`: stable track identity, trajectory, missed frames, and track stability.
4. `camera_motion`: IMU and visual-background motion estimates.
5. `scale_estimation`: class-specific metric-scale hypotheses with assumptions and uncertainty.
6. `speed_estimation`: world displacement over capture timestamps with robust filtering.
7. `quality`: observable gates for target size, blur, occlusion, view angle, camera motion, track duration, and model support.
8. `evidence_log`: reproducible intermediate measurements for validation; disabled or minimized in production.
9. `product_ui`: guidance, target selection, live state, replay, history, and export.

## Class-specific scale research

- Balls: standardized subtype diameter is a strong prior; motion blur, depth direction, and partial detection remain risks.
- Bicycle: wheel/keypoint geometry may provide scale, but wheel sizes, occlusion, and perspective vary.
- Vehicle: class/keypoint/template methods may provide scale; vehicle dimensions and viewing geometry vary materially.
- Person: pose and anthropometric priors are highly variable; treat as an estimate with conservative quality gates.

No method is accepted until tested against independent ground truth across devices and capture conditions.

## Required result schema

Each candidate result should include at least:

- target class and subtype
- track identifier
- capture start/end timestamps
- lens and zoom state
- scale method and assumptions
- estimated scale and uncertainty
- estimated speed
- target pixel size and track duration
- blur, occlusion, camera motion, and angle indicators
- quality band and gate failures
- model/build versions

## Platform verification boundary

- Cloud/Linux can validate shared Dart code, pure algorithm code, Android builds when the SDK is configured, and offline video fixtures.
- iOS camera behavior, performance, signing, and native compilation require a Mac with Xcode.
- Device performance and thermal behavior require physical phones.


## M0 contract mapping

`lib/domain/measurement.dart` contains independent CaptureSource, Detector,
Tracker, CameraMotionEstimator, ScaleEstimator, SpeedEstimator, QualityEvaluator
and EvidenceLogger contracts, with typed immutable observations/evidence.
No contract has a production implementation in M0. Capture timestamps use
monotonic microseconds supplied by future native capture metadata. A lens/zoom
change requires a fresh track. Unknown quality gates cannot pass. Scale priors,
quality thresholds and speed algorithms are deliberately unspecified pending
milestone research. The UI never creates measurement candidates.

`lib/domain/contracts.dart` is the public export for the canonical measurement
contracts. There is one quality gate vocabulary; M0 supplies no empirical size
or duration thresholds. Original dependency notice hashes are checked offline.

## M1 synthetic observation boundary

`lib/offline/harness.dart` accepts only labeled synthetic detection fixtures.
It reuses CaptureMetadata, NormalizedBox and TargetClass; it does not implement
Detector or native capture. OfflineHarness has a local, fresh-per-run single-target
state machine with conservative spatial association and explicit gap/ambiguity/
loss/optics/class-change outcomes. JSON Lines preserve original per-frame inputs
and provenance; they never contain a speed estimate. See M1_OFFLINE_HARNESS.md
for schema, deterministic selection policy and unvalidated association limits.

## M1 model detector boundary

`lib/detection/efficientdet_lite0.dart` adds a model-specific but runtime-testable
adapter. It accepts complete upright RGB888 frames with source PTS, preserves
aspect ratio with deterministic 320x320 letterboxing, validates the exact input
and output tensor names/shapes/types, and converts model boxes back to normalized
source-image coordinates. Only reviewed COCO indexes become typed observations.
Other valid COCO categories are ignored rather than relabeled; malformed classes,
scores, counts, boxes or tensor contracts fail the frame.

`lib/detection/tflite_efficientdet_runtime.dart` is the mobile FFI boundary for
the bundled model. It is separate from the synthetic fixture harness. Neither
adapter decodes video, schedules frames, tracks targets, estimates metric scale,
or produces speed. A coarse ball observation has no subtype; the measurement
contract rejects numeric ball speed until a subtype is explicitly available.
