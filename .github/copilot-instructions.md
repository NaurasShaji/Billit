# Copilot Instructions for Floral Billing Refined

## Project Overview
- **Flutter app** for floral shop billing, inventory, and reporting.
- Uses **Hive** for local storage; supports **web and mobile** platforms.
- Main features: Billing, Products, Reports, Settings (with backup/restore).

## Architecture & Key Files
- `lib/models/`: Hive data models (e.g., `product.dart`, `sale.dart`, `employee.dart`).
- `lib/services/`: Business logic and data access (e.g., `auth_service.dart`, `boxes.dart`).
- `lib/screens/`: UI screens, organized by feature and tabs.
- `lib/models/models.dart`: Barrel file for model exports.
- `main.dart`: App entry point, navigation, and initialization.

## Data Flow & Patterns
- **Hive Adapters**: Run `flutter pub run build_runner build --delete-conflicting-outputs` after model changes.
- **Box Access**: Use `boxes.dart` for opening Hive boxes; models are stored/retrieved via adapters.
- **Authentication**: Default login is `admin/admin123` (seeded on first launch).
- **Backup/Restore**: Settings tab provides JSON backup/restore, compatible with mobile and web.

## Developer Workflows
- **Install dependencies**: `flutter pub get`
- **Build Hive adapters**: `flutter pub run build_runner build --delete-conflicting-outputs`
- **Run app (web)**: `flutter run -d chrome`
- **Run app (android)**: `flutter run -d emulator-5554`
- **Testing**: Tests in `test/` (e.g., `widget_test.dart`).

## Conventions & Patterns
- **Product units**: Support for both `pcs` and `kg` in product models and UI.
- **Billing**: Each sale updates stock and records profit; payment methods are Cash/Card/UPI.
- **Reports**: Revenue, profit, and invoice count are aggregated by day/month/year.
- **Settings**: Backup/restore uses simple file dialogs for cross-platform compatibility.

## Integration Points
- **Hive**: All persistent data is managed via Hive; adapters must be kept in sync with models.
- **Flutter Navigation**: Screens are organized by tabs and features; see `main.dart` and `lib/screens/tabs/`.

## Examples
- To add a new model: create in `lib/models/`, update `models.dart`, run build_runner.
- To add a new screen: create in `lib/screens/`, update navigation in `main.dart`.

---
For questions or unclear patterns, check `README.md` or ask for clarification.
