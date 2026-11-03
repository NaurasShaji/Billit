# Billit

Billit is a point-of-sale and retail management app for billing, inventory, GST, reporting, backups, and printer workflows. It uses Hive for local data storage and includes billing, inventory, reporting, backup, and printer workflows.

![Billit app logo](assets/icon/billit_logo.svg)

## Features

### Billing and invoices

- Search the product catalog and add items to a shopping cart.
- Track quantities against available stock and prevent adding more than the remaining stock.
- Enter customer name and phone number, apply a discount, and choose Cash, Card, or UPI.
- Calculate the sale total, product cost, and profit; completing a sale records the invoice and updates stock.
- Browse saved invoices, edit or delete an invoice, and generate a PDF or print a receipt.
- Send generated invoice PDFs to customers through the official WhatsApp Business Cloud API using a separately deployed backend.
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

### WhatsApp invoice delivery

Billit can send invoice PDFs to customers using the official Meta WhatsApp Business Cloud API. This is a server-mediated integration: the Flutter app sends the generated PDF to your Billit backend, and the backend communicates with Meta.

**In the app**

- Open **App & Invoice Settings → WhatsApp Cloud API**.
- Enter the deployed backend's HTTPS base URL and the Billit backend API key.
- The backend API key is stored locally using Flutter Secure Storage, rather than in the ordinary Hive settings box.
- In Invoice History, use the WhatsApp action on an invoice to send its PDF to the customer's saved phone number.
- Billit reports whether Meta accepted or rejected the send request. Acceptance is not confirmation of delivery or read status.

**Backend setup**

The backend is in `backend/whatsapp-api/` and requires Node.js 20 or newer.

1. Create a Meta app, add the WhatsApp product, connect a WhatsApp Business Account, and register a sender number.
2. Obtain the WhatsApp **Phone Number ID** and a long-lived/system-user access token with the `whatsapp_business_messaging` permission.
3. Copy `.env.example` to `.env` in `backend/whatsapp-api/` and configure:
   - `BILLIT_API_KEY`: a unique, high-entropy key also entered in Billit's Invoice Settings.
   - `META_ACCESS_TOKEN`: Meta access token. Keep this only on the backend.
   - `META_PHONE_NUMBER_ID`: the registered WhatsApp sender's Phone Number ID.
   - `META_GRAPH_API_VERSION`: Graph API version; the example defaults to `v26.0`.
   - `WHATSAPP_INVOICE_TEMPLATE_NAME` and `WHATSAPP_INVOICE_TEMPLATE_LANGUAGE`: optional approved template configuration.
   - `PORT` and optional `CORS_ORIGIN`: backend port and allowed browser origins.
4. Install dependencies and start the service:

   ```bash
   cd backend/whatsapp-api
   npm install
   npm start
   ```

5. Deploy the service behind HTTPS, then enter its base URL and the same `BILLIT_API_KEY` in Billit. The health endpoint is `GET /health`.

**Message-window and template rules**

- Without a template configured, the backend sends a free-form PDF document message. This is subject to WhatsApp's customer-service window, generally 24 hours after the customer last messages the business.
- For business-initiated invoice messages outside that window, configure an approved WhatsApp utility template with a **document header** and three body placeholders, in this order: customer name, invoice ID, and total amount.
- Set `WHATSAPP_INVOICE_TEMPLATE_NAME` and `WHATSAPP_INVOICE_TEMPLATE_LANGUAGE` to match the approved template in Meta exactly. Template creation and approval happen in Meta; Billit does not create or submit templates.
- Follow WhatsApp opt-in and messaging policies. A customer phone number alone does not establish consent to receive business messages.

**Backend API and limitations**

- `POST /api/whatsapp/send-invoice`: accepts the customer phone, invoice ID, optional caption, customer name, total amount, and a PDF upload in the `invoice` field.
- A 10-digit phone number is treated as an Indian number and prefixed with country code `91`; other numbers must include their country code.
- PDF uploads are limited to 15 MB. The endpoint applies request rate limiting and requires the `x-billit-api-key` header.
- Delivery/read receipts, inbound replies, automated retries, per-business authentication, and a WhatsApp webhook are not implemented in this version.
- The shared Billit API key is a basic backend gate, not per-user or per-business authentication. Add stronger authentication and tenant isolation before exposing this service to multiple businesses or a public production environment.

See [the WhatsApp backend README](backend/whatsapp-api/README.md) for the full configuration and deployment notes.
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

## Android launcher icon

The Android launcher icon is generated from `assets/icon/billit_icon.png` using the
`flutter_launcher_icons` configuration in `pubspec.yaml`. After changing the
icon artwork or launcher-icon configuration, regenerate the Android resources:

```powershell
flutter pub get
dart run flutter_launcher_icons
flutter clean
flutter build apk --release
```

If an already-installed Android launcher continues showing the previous icon,
uninstall the old Billit app before installing the newly built APK. Some launchers
cache application icons.
