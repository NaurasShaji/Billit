# Floral Billing

A Flutter app for managing floral-shop sales, products, and day-to-day business records. It uses Hive for local data storage and includes billing, inventory, reporting, backup, and printer workflows.

![Floral Billing app icon](assets/icon/floralbill_icon.jpg)

## Features

### Billing and invoices

- Search the product catalog and add items to a shopping cart.
- Track quantities against available stock and prevent adding more than the remaining stock.
- Enter customer name and phone number, apply a discount, and choose Cash, Card, or UPI.
- Calculate the sale total, product cost, and profit; completing a sale records the invoice and updates stock.
- Browse saved invoices, edit or delete an invoice, and generate a PDF or print a receipt.
- Look up customers by name or phone number and review their past invoices.

### Products and inventory

- Add and edit products with a name, selling price, cost price, stock quantity, category, and subcategory.
- Organize products with category, subcategory, and unit filters; search by product name.
- Track products sold by pieces (`pcs`), kilograms (`kg`), or square feet (`sqft`).
- View the calculated difference between selling and cost prices while editing a product.

### Sales reports

- Review daily sales summaries; admins can also view monthly and yearly summaries and navigate to other reporting periods.
- See revenue, profit, and invoice counts for the selected reporting period.
- Browse recorded sales and access invoice actions from the report views.

### Expenses and employee payroll

- Record business expenses with an amount, description, date, and category.
- Use built-in expense categories such as rent, utilities, transport, supplies, maintenance, and miscellaneous, or add a category.
- Browse expense history by day, month, or year; navigate between periods and filter salary expenses separately from other expenses.
- Add employees as daily-wage or monthly-salary staff, set their pay amount, edit their pay type or amount, and delete employee records.
- Record daily wage payments and monthly salary payments, with summaries of employees and payments for the current day or month.
- Review payroll/expense totals by day, month, or year, including daily wages, monthly salaries, other expenses, and net expenses.

### Backup, printer, and account tools

- Back up products, sales, expenses, and employee records to Google Drive, browse available backups, and restore a selected backup.
- Configure recurring Google Drive backups by interval. Restoring replaces current business data, so keep a current backup before restoring.
- Scan paired Bluetooth devices and select a default thermal printer.
- Change account passwords through the admin account.
- Access the in-app Help and FAQ.

### Accounts and access

- Admin and worker accounts are seeded on first launch.
- Admins have access to the Archive area for expenses, payroll, backups, customer lookup, and account tools. Workers see the Billing, Products, and Reports tabs, with daily reports.

## Requirements

- Flutter SDK with Dart **3.3 or later**
- A supported Flutter target, such as Chrome or an Android device/emulator

## Getting started

1. Clone this repository and open the project directory:

   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:

   ```bash
   # Web
   flutter run -d chrome

   # Android (replace with your connected device or emulator ID)
   flutter run -d <device-id>
   ```

On first launch, the app creates these local accounts:

| Role | Username | Initial password |
| --- | --- | --- |
| Admin | `admin` | `admin123` |
| Worker | `worker` | `worker123` |

These are default credentials for a new local installation. Change the admin password after signing in, and do not use these credentials for a shared or production deployment.

## Optional Supabase cloud snapshots

The Supabase integration is optional. Local Hive operation and the existing Google Drive workflow remain available when Supabase is not configured.

1. Create a Supabase project on the [Supabase dashboard](https://supabase.com/dashboard).
2. In **SQL Editor**, run [`supabase/setup.sql`](supabase/setup.sql). The table is protected by Row Level Security and expects Supabase Auth users.
3. Copy the Project URL and **publishable key** from Project Settings / API Keys. Never put a service-role or secret key in the app.
4. Build/run with your own values, for example:

   ```bash
   flutter pub get
   flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
   ```

   Keep actual keys out of source control. The `.env.example` file is a reference only; Flutter's `--dart-define-from-file` requires a JSON-formatted file, so create a local untracked `.env.json` with `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` if you prefer that approach.
5. Enable email/password in Supabase Auth. If email confirmation is enabled, confirm the account before syncing. Floral Bill's existing local `admin`/`worker` login is not a Supabase identity.
6. Open **Archive → Backup & Restore → Supabase Cloud Sync**. Upload local data creates/replaces that account's cloud snapshot; Restore replaces local products, sales, expenses, employees, and app settings. Make a backup first.

This is manual snapshot backup/restore, not real-time synchronization or conflict resolution. Test with disposable sample data before using live business records. Check [current Supabase pricing and limits](https://supabase.com/pricing) before relying on the free plan.

## Development

Hive adapters are checked into `lib/models/`. After changing a Hive model, regenerate the adapters:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run the test suite with:

```bash
flutter test
```

## Project structure

```text
lib/
  models/       Hive data models and generated adapters
  screens/      App screens and feature tabs
  services/     Authentication, billing, backups, PDFs, and printing
  widgets/      Reusable UI components
  main.dart     App initialization and root widget
test/           Flutter tests
assets/         App icons and other bundled assets
```

## Data and backups

The app stores business data locally with Hive. Export backups regularly and store them somewhere safe. Google Drive backup requires signing in to a Google account and an available Google Sign-In configuration for the target platform.
