# Billit WhatsApp Cloud API backend

This Node.js 20+ service is the server-side bridge between Billit and Meta's official WhatsApp Business Cloud API. It keeps the Meta access token out of the Flutter application, receives a generated invoice PDF, uploads it to WhatsApp media storage, and sends the PDF as a document message.

## Configure Meta

1. Create a Meta app and add the WhatsApp product.
2. Connect a WhatsApp Business Account and register a sender phone number.
3. Obtain the sender **Phone Number ID** and a long-lived/system-user access token.
4. Ensure the token has the `whatsapp_business_messaging` permission.
5. Add the customer's number as an allowed recipient while using a Meta test number.

Meta's official documentation: https://developers.facebook.com/documentation/business-messaging/whatsapp/

## Run locally

1. Install Node.js 20 or newer.
2. Copy `.env.example` to `.env` and fill in all secrets and IDs.
3. Run:

   ```bash
   npm install
   npm start
   ```

4. The health check is available at `GET /health`.
5. Deploy behind HTTPS before connecting a production Billit installation.

## Environment variables

- `BILLIT_API_KEY`: long random key shared with Billit. Never commit it.
- `META_ACCESS_TOKEN`: Meta system-user access token. This stays on the server.
- `META_PHONE_NUMBER_ID`: WhatsApp sender Phone Number ID.
- `META_GRAPH_API_VERSION`: pinned Graph API version; default is `v26.0`.
- `WHATSAPP_INVOICE_TEMPLATE_NAME`: optional approved template name. Set this to use a document-header template for business-initiated invoice messages.
- `WHATSAPP_INVOICE_TEMPLATE_LANGUAGE`: template language code; defaults to `en`.
- `PORT`: HTTP port; default `8080`.
- `CORS_ORIGIN`: optional comma-separated allowed browser origins. Native mobile clients do not require CORS.

## Billit configuration

Open **App & Invoice Settings → WhatsApp Cloud API** and enter:
- The deployed backend's HTTPS base URL (without the endpoint path).
- The `BILLIT_API_KEY`.

The key is stored using Flutter Secure Storage. The Meta access token must never be entered in Billit.

## API

### Send invoice PDF

`POST /api/whatsapp/send-invoice`

Headers:
- `x-billit-api-key: <BILLIT_API_KEY>`

Multipart form fields:
- `phone`: customer phone number. A 10-digit number is treated as an Indian number and prefixed with 91; other numbers must include their country code.
- `invoiceId`: invoice identifier.
- `caption`: optional message caption.
- `invoice`: PDF file (maximum 15 MB).

The backend uploads the PDF to `/{PHONE_NUMBER_ID}/media`, then sends the resulting media ID through `/{PHONE_NUMBER_ID}/messages` as a document message.

The endpoint is rate-limited to 30 requests per IP per 15 minutes. A successful response means Meta accepted the send request; it does not prove delivery or that the customer read the message.

## WhatsApp policy constraints

- Free-form document messages are subject to WhatsApp's customer-service window, generally 24 hours after the customer last messages the business.
- For business-initiated messages outside that window, create and get approval for a WhatsApp utility template with a **document header** and three body placeholders, in this order: customer name, invoice ID, total amount. Then set `WHATSAPP_INVOICE_TEMPLATE_NAME` and `WHATSAPP_INVOICE_TEMPLATE_LANGUAGE` on the backend. The exact template name, language and parameter order must match the approved template in Meta.
- The customer must have provided the number and the business must follow WhatsApp opt-in and messaging policies.
- Delivery/read receipts and inbound replies require a configured webhook; webhook processing is not implemented here.

## Security and production notes

- Keep `.env` out of source control. Use your hosting provider's secret/environment-variable manager.
- Use HTTPS and a unique, high-entropy `BILLIT_API_KEY`.
- The Billit client key is a shared client credential, not per-user authentication. It can be extracted from a compromised device. For a multi-business/public deployment, replace it with authenticated per-business server sessions or short-lived tokens and add audit logging.
- The backend has request rate limiting and configurable CORS. Restrict `CORS_ORIGIN` to the deployed web app origin if using Flutter Web.
- Never log access tokens, API keys, invoice PDFs, or full customer phone numbers.
