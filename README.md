# Zipro mobile (Flutter)

This folder contains the Flutter client for Zipro. It mirrors flows from `zipro_website_new` and calls the same API as `zipro-app-services`.

## Prerequisites

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (includes Dart). This machine may not have `flutter` on `PATH` until you install it.

## First-time setup

From the repository root:

```bash
cd zipro_mobile
flutter create . --project-name zipro_mobile --org in.zipro.mobile
flutter pub get
```

`flutter create` adds `android/`, `ios/`, `web/`, etc., next to the existing `lib/` and `pubspec.yaml`.

## Run

Point the app at your API (same as `NEXT_PUBLIC_API_BASE_URL` in the web app):

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

## Checks

```bash
flutter analyze
flutter test
```
