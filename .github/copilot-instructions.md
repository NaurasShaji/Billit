# Copilot Instructions for Billit

## Project Overview
- **Flutter app** for retail billing, inventory, and business management.
- Uses **SQLite** (`package:sqlite3`, WASM on web) for local storage; supports **web and mobile** platforms.
- Main features: Billing, Products, Reports, Settings (with backup/restore).

## Architecture & Key Files
- `lib/data/`: SQLite schema (`schema.dart`), stores (`database.dart`, `entity_stores.dart`) and the one-time import of old Hive data (`legacy_hive_import.dart`).
- `lib/models/`: Data models (e.g., `product.dart`, `sale.dart`, `employee.dart`).
- `lib/services/`: Business logic (e.g., `auth_service.dart`, `pdf_service.dart`).
- `lib/screens/`: UI screens, organized by feature and tabs.
- `lib/models/models.dart`: Barrel file for model exports.
- `main.dart`: App entry point, navigation, and initialization.

## Data Flow & Patterns
- **Data Access**: Use `Db.users`, `Db.products`, `Db.sales`, `Db.expenses`, `Db.employees` (records keyed by id) and `Db.settings`, `Db.session`, `Db.deviceSettings` (key/value). Each has `listenable()` for `ValueListenableBuilder`.
- **Multi-step writes**: Wrap them in `Db.transaction(...)` so a failure rolls everything back.
- **Schema changes**: Add a migration in `schema.dart`, bump `schemaVersion`, and update the row mapping in `entity_stores.dart`. No code generation.
- **Authentication**: Default login is `admin/admin123` (seeded on first launch).
- **Backup/Restore**: Settings tab provides JSON backup/restore, compatible with mobile and web.

## Developer Workflows
- **Install dependencies**: `flutter pub get`
- **Run app (web)**: `flutter run -d chrome`
- **Run app (android)**: `flutter run -d emulator-5554`
- **Testing**: Tests in `test/` (e.g., `widget_test.dart`).

## Conventions & Patterns
- **Product units**: Support for both `pcs` and `kg` in product models and UI.
- **Billing**: Each sale updates stock and records profit; payment methods are Cash/Card/UPI.
- **Reports**: Revenue, profit, and invoice count are aggregated by day/month/year.
- **Settings**: Backup/restore uses simple file dialogs for cross-platform compatibility.

## Integration Points
- **SQLite**: All persistent data goes through `lib/data/`; keep the table definitions in sync with the models.
- **Flutter Navigation**: Screens are organized by tabs and features; see `main.dart` and `lib/screens/tabs/`.

## Examples
- To add a new model: create in `lib/models/`, update `models.dart`, add its table in `schema.dart` and a store in `entity_stores.dart`.
- To add a new screen: create in `lib/screens/`, update navigation in `main.dart`.

---
For questions or unclear patterns, check `README.md` or ask for clarification.
