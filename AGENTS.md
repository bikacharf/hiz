# Hız Ölçer repository instructions

## Product boundary

- Build a commercial iOS and Android camera application that detects and tracks people, bicycles, vehicles, and supported ball types.
- The user does not enter a distance and does not perform manual calibration.
- Do not claim radar-grade, legal, enforcement-grade, or certified accuracy.
- Do not show a speed when the available evidence is insufficient. Return an explicit unavailable/low-quality result instead.
- Treat UI mockups as product references, not proof that a measurement method works.

## Privacy and data

- Process camera frames on device by default.
- Do not upload images, video, telemetry, or identifiers without a separately reviewed product decision and explicit user consent.
- Never commit secrets, signing material, API keys, personal recordings, or production credentials.
- Test fixtures must be synthetic, licensed, or explicitly approved for repository use.

## Licensing

- This is intended to be a proprietary paid product.
- Before adding a dependency, model, weights file, dataset, or copied algorithm, record its exact license and source in `THIRD_PARTY_NOTICES.md`.
- Do not add AGPL/GPL code or weights, research-only assets, non-commercial assets, or components with unclear terms without explicit approval.
- Apache-2.0, MIT, BSD, and platform SDK components still require attribution and compatibility review.

## Architecture and verification

- Use Flutter for shared product UI and orchestration unless an accepted architecture decision changes this.
- Keep performance-sensitive camera, sensor, and inference code behind native Swift and Kotlin interfaces.
- Keep detection, tracking, scale estimation, speed estimation, and quality scoring as separate modules with typed outputs.
- Record timestamps from capture metadata; do not derive timing from UI frame rate.
- Every speed result must carry method, object class, quality signals, limitations, and traceable intermediate measurements.
- A confidence score must describe observable measurement quality. Do not label it accuracy unless validated against ground truth.
- Android changes must pass formatting, static analysis, tests, and a debug build in CI.
- iOS changes must include Mac/Xcode validation instructions. Do not report iOS as verified from a Linux-only environment.

## Agent workflow

- Read `docs/SPEC.md`, `docs/ARCHITECTURE.md`, `docs/MILESTONES.md`, `docs/RUNBOOK.md`, and `docs/STATUS.md` before implementation.
- Work on one milestone at a time.
- Keep diffs scoped to the active milestone.
- Run its validation commands before moving on; repair failures first.
- Update `docs/STATUS.md` with evidence, decisions, known limitations, and the next action.
- Stop for user input before publishing, merging to a protected branch, buying services, adding secrets, changing the business model, or making an unverified accuracy claim.

