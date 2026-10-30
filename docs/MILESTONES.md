# Milestones and acceptance criteria

## M0 — Repository and reproducible development shell

Deliver:

- Flutter project with Android and iOS targets
- pinned tool versions and setup instructions
- application package identifiers documented as placeholders
- architecture interfaces for capture, detection, tracking, quality, and evidence logging
- CI for formatting, analysis, tests, and Android debug build
- dependency and license inventory

Done when:

- a clean Linux environment can run setup, formatting check, static analysis, tests, and Android debug build
- no unreviewed model or restrictive dependency is bundled
- iOS Mac validation steps are documented

## M1 — Offline detection and tracking harness

Deliver:

- import a local test video
- detect supported coarse classes where the selected licensed model permits
- tap/select a target or select by deterministic test configuration
- preserve a stable track identity
- export per-frame evidence as JSON
- no numeric speed output

Done when:

- deterministic fixtures produce repeatable evidence files
- tracking tests cover temporary occlusion and target loss
- unsupported/ambiguous cases fail explicitly

## M2 — Live camera vertical slice

Deliver:

- Android live camera preview and native capture metadata
- target boxes, selection, and tracking overlay
- zoom-state handling
- blur, target-size, camera-motion, and track-duration quality gates
- iOS implementation prepared with a Mac test checklist

Done when:

- Android debug build runs on the named reference device
- the live overlay stays aligned across rotation/preview transforms
- lens or material zoom changes reset affected measurements
- no result is shown when gates fail

## M3 — Ball scale and speed feasibility

Deliver:

- football, basketball, and tennis subtype selection
- subtype-size prior with documented standards/source
- offline scale and speed candidates
- ground-truth comparison report

Done when:

- test protocol, fixtures, reference measurements, errors, and excluded cases are documented
- supported capture envelope and failure conditions are explicit
- product wording is based on evidence rather than target marketing claims

## M4 — Bicycle feasibility

Same evidence requirements as M3, with bicycle-specific keypoint/geometry research and validation.

## M5 — Person and vehicle feasibility

Validate each class independently. Do not combine results or quality thresholds without evidence.

## M6 — Product UI and local sessions

Implement approved screens, replay, local history, comparison, and local export after at least one target class passes the feasibility gate.

## M7 — Purchases and store preparation

Add StoreKit 2 and Google Play Billing only after the product value and supported-device policy are defined. Use sandbox purchases and require explicit approval before store submission.

