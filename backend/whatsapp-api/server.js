import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import cors from 'cors';
import multer from 'multer';

const app = express();
const port = Number(process.env.PORT || 8080);
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 15 * 1024 * 1024, files: 1 } });

app.use(cors());
app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'billit-whatsapp-api' }));

function requireClientKey(req, res, next) {
  const expected = process.env.BILLIT_API_KEY || '';
  const supplied = req.header('x-billit-api-key') || '';
  const a = Buffer.from(expected);
  const b = Buffer.from(supplied);
  if (!expected) return res.status(503).json({ error: 'BILLIT_API_KEY is not configured.' });
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return res.status(401).json({ error: 'Invalid Billit API key.' });
  next();
}

function normalizePhone(value) {
  const digits = String(value || '').replace(/[^0-9]/g, '');
  const normalized = digits.length === 10 ? '91' + digits : digits;
  if (!/^\d{8,15}$/.test(normalized)) throw new Error('Enter a valid phone number with country code.');
  return normalized;
}

async function metaRequest(url, options) {
  const response = await fetch(url, options);
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload?.error?.message || 'Meta API request failed: HTTP ' + response.status);
    error.status = response.status;
    error.meta = payload;
    throw error;
  }
  return payload;
}

app.post('/api/whatsapp/send-invoice', requireClientKey, upload.single('invoice'), async (req, res) => {
  try {
    const token = process.env.META_ACCESS_TOKEN;
    const phoneNumberId = process.env.META_PHONE_NUMBER_ID;
    const version = process.env.META_GRAPH_API_VERSION || 'v23.0';
    if (!token || !phoneNumberId) return res.status(503).json({ error: 'WhatsApp Cloud API credentials are not configured.' });
    if (!req.file || req.file.mimetype !== 'application/pdf') return res.status(400).json({ error: 'Attach an invoice PDF.' });

    const to = normalizePhone(req.body.phone);
    const invoiceId = String(req.body.invoiceId || '').trim();
    const caption = String(req.body.caption || '').trim().slice(0, 1024);
    if (!invoiceId) return res.status(400).json({ error: 'Invoice ID is required.' });

    const form = new FormData();
    form.append('messaging_product', 'whatsapp');
    form.append('type', 'application/pdf');
    form.append('file', new Blob([req.file.buffer], { type: 'application/pdf' }), req.file.originalname || ('invoice-' + invoiceId + '.pdf'));

    const media = await metaRequest('https://graph.facebook.com/' + version + '/' + phoneNumberId + '/media', {
      method: 'POST', headers: { Authorization: 'Bearer ' + token }, body: form,
    });
    const sent = await metaRequest('https://graph.facebook.com/' + version + '/' + phoneNumberId + '/messages', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        messaging_product: 'whatsapp', recipient_type: 'individual', to, type: 'document',
        document: { id: media.id, filename: req.file.originalname || ('invoice-' + invoiceId + '.pdf'), caption: caption || ('Invoice ' + invoiceId) },
      }),
    });
    return res.json({ success: true, invoiceId, recipient: to, messageId: sent?.messages?.[0]?.id || null, status: 'accepted_by_whatsapp' });
  } catch (error) {
    const status = error.status && error.status >= 400 && error.status < 600 ? error.status : 502;
    return res.status(status).json({ error: error.message || 'Unable to send invoice.', metaError: error.meta?.error?.code || undefined });
  }
});

app.listen(port, () => console.log('Billit WhatsApp API listening on port ' + port));
