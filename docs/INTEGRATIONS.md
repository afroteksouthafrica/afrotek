# Payments (Paystack) — FastAPI scaffold

- `POST /payments/intent` — create an order payment intent via Paystack (server-side).
- `POST /payments/webhook` — handle Paystack webhooks with signature verification.
- `GET /health` — liveness.

# Shipping — adapters (Pargo, Bobgo)

- `GET /rates` — quote rates by provider.
- `POST /labels` — create shipment & label.
- `GET /track/:id` — track shipment.

See services for details.
