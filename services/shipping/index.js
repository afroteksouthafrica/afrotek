import express from 'express';
import crypto from 'crypto';

const app = express();
app.use(express.json());

app.get('/health', (_, res) => res.json({ ok: true }));

app.get('/rates', async (req, res) => {
  // TODO: call Pargo/Bobgo rates
  res.json({ provider: req.query.provider || 'pargo', rates: [] });
});

app.post('/labels', async (req, res) => {
  // TODO: create shipment & label via adapter
  res.json({ ok: true, labelId: 'stub' });
});

app.get('/track/:id', async (req, res) => {
  // TODO: fetch tracking events
  res.json({ id: req.params.id, events: [] });
});

const port = process.env.PORT || 3006;
app.listen(port, () => console.log('shipping-service listening on', port));
