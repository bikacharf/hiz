# Cloud Task 01 — M0 repository and development shell

## Objective

Create the reproducible, license-safe Flutter/native project shell for the Hız Ölçer feasibility prototype. This task establishes architecture and verification only. It must not invent or claim a working speed-estimation method.

## Required reading

Read and follow:

- `AGENTS.md`
- `docs/SPEC.md`
- `docs/ARCHITECTURE.md`
- `docs/MILESTONES.md`
- `docs/RUNBOOK.md`
- `docs/STATUS.md`

## Work

1. Inspect the Cloud environment and report installed Flutter, Dart, Java, Android SDK, Gradle, Swift/Xcode availability before changing files.
2. Propose the exact M0 implementation plan and identify any environment blocker.
3. Create a Flutter application with Android and iOS targets using neutral placeholder bundle identifiers documented for later replacement.
4. Add typed Dart interfaces/data models for capture metadata, detection observations, tracking observations, quality signals, measurement candidates, and evidence records. Do not implement fake inference or fake speed values.
5. Add a minimal dark/mint application shell with placeholder routes for Camera, History, and Profile. Clearly label nonfunctional prototype areas.
6. Add meaningful unit tests for data validation and quality-gate behavior.
7. Add CI or equivalent commands for formatting, static analysis, tests, dependency/license checks where feasible, and Android debug build.
8. Inventory every dependency and its license in `THIRD_PARTY_NOTICES.md`.
9. Document Linux/Android validation results and the exact Mac/Xcode steps still required for iOS.
10. Update `docs/STATUS.md` with evidence and the next task.

## Constraints

- Do not add a detector, model weights, dataset, backend, analytics SDK, advertising SDK, subscription SDK, or cloud upload.
- Do not add AGPL/GPL, research-only, non-commercial, or unclear-license components.
- Do not state that camera capture, object detection, tracking, automatic scale, or speed estimation works.
- Do not require secrets.
- Keep the diff limited to M0.

## Done when

- clean setup and validation commands are documented
- formatting, analysis, unit tests, and Android debug build pass in the available environment, or a precise reproducible environment blocker is reported
- interfaces preserve the module boundaries in `docs/ARCHITECTURE.md`
- all dependencies are inventoried
- iOS remains explicitly marked as requiring Mac/Xcode verification
- `docs/STATUS.md` contains concrete evidence rather than a narrative claim

