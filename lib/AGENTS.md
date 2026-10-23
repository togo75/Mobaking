# Repository Guidelines

## Project Structure & Module Organization

Application code lives in `lib/`: place pages under `lib/screens/<feature>/`, reusable UI under `lib/widget/`, integrations and stateful logic under `lib/services/`, native/model helpers under `lib/core/`, and shared values under `lib/utils/`. The entry point is `lib/main.dart`.

Flutter tests belong in `test/`. Platform projects are in `android/`, `ios/`, and `web/`. On-device ASR, SLU, and VITS model files are stored under `assets/` and declared explicitly in `pubspec.yaml`. The embedded Flask service lives in `app/src/`; its packaged artifact is `app/app.zip`. Utility scripts are in `python-utils/`.

## Build, Test, and Development Commands

- `flutter pub get` installs Dart and Flutter dependencies.
- `flutter run` launches the app on a connected device or emulator.
- `flutter analyze` applies the `flutter_lints` rules from `analysis_options.yaml`.
- `dart format lib test` formats Dart sources and tests.
- `flutter test` runs the Flutter tests.
- `PYTHONPATH=build/site-packages/arm64-v8a python3 -m unittest app/test_main.py` tests the embedded API.
- `SERIOUS_PYTHON_SITE_PACKAGES=$PWD/build/site-packages flutter build apk` builds Android with packaged Python dependencies.
- `dart run serious_python:main package app/src -p Android` rebuilds `app/app.zip` after Python changes. Install `app/src/requirements.txt` into the architecture-specific package directory first, following `PACKAGING_SERIOUS_PYTHON_CODE`.

## Coding Style & Naming Conventions

Use Dart's standard two-space indentation and let `dart format` decide wrapping. Name files `snake_case.dart`, classes and widgets `UpperCamelCase`, and variables or methods `lowerCamelCase`. Prefer small feature widgets, `const` constructors, and service classes for Firebase, audio, speech, and storage behavior.

## Testing Guidelines

Use `flutter_test`; name files `*_test.dart` and group tests by widget or behavior. Add unit tests for service logic and widget tests for meaningful UI states. No coverage threshold is configured, but every bug fix should include a regression test when practical. Run `flutter analyze` and `flutter test` before submitting.

## Commit & Pull Request Guidelines

Git history is not included in this checkout, so no existing commit convention can be verified. Use concise, imperative subjects, optionally scoped, such as `feat(voice): add transfer confirmation` or `fix(auth): handle expired session`. Pull requests should explain the behavior change, list verification commands, link relevant issues, and include screenshots or recordings for UI changes. Mention model, Firebase configuration, native library, or `app.zip` updates explicitly.

## Security & Configuration

Do not commit new service-account files, credentials, or machine-specific `local.properties` values. Treat Firebase configuration changes carefully and avoid logging authentication, account, or recorded-audio data. Large model binaries should only change intentionally and must remain synchronized with `pubspec.yaml`.
