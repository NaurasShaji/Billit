# Billit WhatsApp Cloud API backend

Node.js 20+ service that keeps Meta credentials on the server. It accepts a PDF from Billit, uploads it to Meta's media endpoint, then sends it as a WhatsApp document message.

## Setup
1. Copy .env.example to .env.
2. Set BILLIT_API_KEY, META_ACCESS_TOKEN and META_PHONE_NUMBER_ID. Choose a Graph API version supported by your Meta app.
3. Run npm install && npm start.
4. Deploy behind HTTPS. Never commit .env.

## API
- GET /health
- POST /api/whatsapp/send-invoice (multipart: phone, invoiceId, optional caption, PDF field invoice; header x-billit-api-key).

A 10-digit number is treated as an Indian mobile number (+91). Supply country code for other regions.

## Meta requirements and limitations
Configure a Meta app with WhatsApp enabled, a WhatsApp Business Account and a registered sender number. The token requires whatsapp_business_messaging permission.
This endpoint sends a free-form document message. It is subject to Meta's customer-service window (normally 24 hours after the customer last messaged the business). Outside that window an approved message template is required; template creation/submission and template sending are not included.
A successful response means Meta accepted the request, not that the recipient received/read it. Delivery receipts require a webhook, not included here.

## Security
Keep META_ACCESS_TOKEN only in backend environment variables. Use HTTPS and a unique BILLIT_API_KEY. The shared client key is only a basic gate, not user identity; add rate limiting and proper authentication before public production deployment.
