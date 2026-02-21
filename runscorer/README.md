# Run Scorer (Khelo)

This directory is the **Flutter app root** for Run Scorer (Khelo) — cricket scoring and team management. Run all Flutter commands from here (e.g. `flutter pub get`, `flutter run`).

It contains the main application, native integrations (Android/iOS), and the presentation layer. It depends on the workspace packages `style` and `data` (sibling directories at repo root).

## Structure

- **lib/ui/** — Screens and app routing (GoRouter).
- **lib/components/** — Reusable UI components.
- **lib/domain/** — Formatters, extensions, and shared domain logic.

## Development

From the repo root:

```bash
cd runscorer
flutter pub get
flutter run
```
