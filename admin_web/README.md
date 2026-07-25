# Journal Trend Admin Web

An independent administration console built with Flutter Web for the
`journal-trend-analyzer` Firebase project. It is separate from the mobile app
and does not require changes to the existing Android or iOS source.

## Firebase

The Firebase Web App is registered in the same project as the mobile app:

- Project ID: `journal-trend-analyzer`
- Auth domain: `journal-trend-analyzer.firebaseapp.com`
- Hosting target: `admin`
- Production API: same-origin at `/api/v1`

Do not create a second Firebase project. The Firebase Web configuration is the
app's public identifier; administrative access is protected by Firebase
Authentication, the `admin: true` custom claim, and `adminApi`.

## Requirements

- A Flutter/Dart version compatible with the SDK constraint in `pubspec.yaml`
- Chrome for local development
- Node.js 22 for `../functions`
- Firebase CLI for emulation and deployment

## Run locally

Start the Functions and Hosting emulators from the repository root:

```powershell
npx firebase-tools emulators:start --only functions,hosting
```

Then open `http://localhost:5000`. On localhost, the UI calls the Functions
Emulator directly on port `5001`. The production build continues to call
same-origin `/api/v1` through the Hosting rewrite.

Validate the Flutter project from the `admin_web` directory:

```powershell
flutter pub get
flutter analyze
flutter test
```

Only pass `API_BASE_URL` when integrating with a different gateway or staging
origin.

Chrome may log a `Cross-Origin-Opener-Policy ... window.closed` warning when
using `flutter run`. This is emitted by the development server when Firebase
Auth checks its pop-up. Firebase Hosting and the Hosting Emulator use the
`same-origin-allow-popups` header configured in `firebase.json`.

If App Check reCAPTCHA Enterprise is registered:

```powershell
flutter run -d chrome `
  --dart-define=APP_CHECK_SITE_KEY=PUBLIC_RECAPTCHA_ENTERPRISE_SITE_KEY
```

The site key is bundled for the browser and is not a secret. Never put service
account JSON, access tokens, or private keys in Dart source or `--dart-define`.

## Build production

From the repository root:

```powershell
dart run tool/build_admin_web.dart
```

The script runs in the `admin_web` directory and executes:

```powershell
flutter build web --release --csp --no-web-resources-cdn
```

The artifact is written to `admin_web/build/web`. To enable App Check during
predeploy:

```powershell
$env:APP_CHECK_SITE_KEY='PUBLIC_RECAPTCHA_ENTERPRISE_SITE_KEY'
$env:API_BASE_URL='/api/v1'
dart run tool/build_admin_web.dart
```

The script only forwards these variables as Dart defines; they are not backend
configuration.

## Grant administrator access

The user must already exist in Firebase Authentication. From the repository
root:

```powershell
npm --prefix functions ci
npm --prefix functions run set-admin -- `
  --email admin@example.com `
  --project journal-trend-analyzer
```

Sign out and sign in again so Firebase issues a new ID token containing the
claim.

## Deploy

`firebase.json` automatically builds Flutter Web before deploying Hosting:

```powershell
npx firebase-tools deploy --only functions:adminApi,hosting:admin `
  --project journal-trend-analyzer
```

The complete guide to Firebase services, backend parameters, emulators, Rules,
Remote Config, and rollback is available in
[`../ADMIN_WEB_SETUP.md`](../ADMIN_WEB_SETUP.md).
