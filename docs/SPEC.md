# Product specification

## Product outcome

Create a paid iOS and Android application that lets a person point the camera at a moving target, select or automatically identify its type, track it, and receive a clearly labeled estimated speed when measurement conditions are adequate.

## Supported target classes

- Person: walking and running
- Bicycle
- Vehicle: start with passenger cars; expand only after validation
- Ball: football, basketball, and tennis

Each class has a separate scale-estimation method, supported capture envelope, and validation report. Success for one class does not establish success for another.

## Core capture flow

1. Open the camera.
2. Leave target type on `Otomatik` or choose `İnsan`, `Bisiklet`, `Araç`, or `Top`.
3. When `Top` is selected, choose `Futbol`, `Basketbol`, or `Tenis`.
4. Keep the phone at the side of the motion path and approximately perpendicular to movement.
5. Tap a detected target if multiple targets are visible.
6. Track the target and evaluate capture quality.
7. Show an estimated speed only if the supported method and quality gates pass.
8. Save an optional local session and replay video.

## Required user guidance

- `Telefonu yolun yanında, hareket yönüne dik tut`
- `Telefonu sabit tut, mümkünse tripod kullan`
- `Nesnenin tamamı ekranda görünsün`
- `Güvenli mesafeden ölç, yola girme.`

## Result language

- Use `Tahmini hız` for all uncalibrated monocular results.
- Use `Ölçüm kalitesi` or `Takip kalitesi` until validation demonstrates that a quality band predicts actual error.
- Show a concrete corrective instruction for poor inputs, such as `Nesne çok uzak, biraz yaklaş`.
- If quality is inadequate, show no numeric speed.

## Product screens

- Home
- Camera and target-type selection
- First-use capture guidance
- Live tracking and estimated speed
- Replay
- Session history
- Video comparison
- Share/export editor
- Profile and settings
- Pro subscription and purchase restoration

## Monetization

- One app listing with a limited free tier and Pro subscription is the current product direction.
- Measurement quality must be identical across free and paid tiers.
- Paid differences may include limits, history, comparison, export styles, and advanced session tools.
- Pricing, trial terms, and entitlements remain undecided and are outside the technical prototype.

## Non-goals for the prototype

- Legal speed enforcement
- Police/radar replacement
- Guaranteed measurement on every device, distance, angle, or lighting condition
- Cloud accounts, public social feed, comments, followers, or messaging
- Automatic video upload
- Store submission or production payments

## Safety and privacy

- Capture from a safe location; never instruct a user to enter a road or motion path.
- Avoid plate or face identification. Detection is by object class, not identity.
- Keep recordings local by default and expose clear delete/export controls in the product phase.

