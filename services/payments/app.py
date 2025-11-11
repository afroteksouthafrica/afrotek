from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel
import hmac, hashlib, os, json

app = FastAPI()

class IntentRequest(BaseModel):
    amount: int  # in kobo/cents
    currency: str = "ZAR"
    reference: str
    email: str

PAYSTACK_SECRET = os.getenv('PAYSTACK_SECRET_KEY', '')

@app.get('/health')
async def health():
    return {"ok": True}

@app.post('/payments/intent')
async def create_intent(body: IntentRequest):
    # TODO: call Paystack Transaction Initialize API
    return {
        "status": "ok",
        "provider": "paystack",
        "data": {
            "reference": body.reference,
            "amount": body.amount,
            "currency": body.currency,
            "email": body.email
        }
    }

@app.post('/payments/webhook')
async def webhook(req: Request):
    sig = req.headers.get('x-paystack-signature')
    raw = await req.body()
    if not PAYSTACK_SECRET or not sig:
        raise HTTPException(status_code=400, detail="missing secret or signature")
    calc = hmac.new(PAYSTACK_SECRET.encode('utf-8'), raw, hashlib.sha512).hexdigest()
    if not hmac.compare_digest(calc, sig):
        raise HTTPException(status_code=401, detail="invalid signature")
    event = json.loads(raw.decode('utf-8'))
    # TODO: update order status using event['event'] & event['data']
    return {"received": True}
