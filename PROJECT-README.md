# Afrotek – Project README (Canonical Memory)

> **Source of truth for architecture, environments, and running TODOs.**

---

## 1) Vision
Build an Africa-first marketplace for refurbished tech (Back Market inspired) with verified sellers, trustworthy grading, and sustainable logistics.

- Countries: Start **South Africa**; expand regionally.
- USPs: rigorous device grading, warranty & returns, carbon-aware shipping, localized payments & couriers.

---

## 2) High-level Architecture

**Frontend**: Nuxt 3 (Vue), Tailwind, Pinia, SSR/ISR via Nitro.

**Services**:
- `product-service` – catalog, grading, search adapters. (Node/Express)
- `auth-service` – accounts, sessions, JWT, OAuth (FastAPI).
- Future: order, seller, payments, shipping, review, CMS.

**Infra (staging)**: AWS af-south-1 – ECR, ECS/Fargate, ALB, Route53, ACM, CloudWatch.

**Integrations**: Paystack (card/bank/PayPal/ZAR), Pargo & BobGo (shipping), Mailgun (email).

**Security**: IAM least-privilege, TLS via ACM, HSTS, secret management via SSM/Secrets Manager, OAuth device-sign-in roadmap.

---

## 3) Environments

- **staging** (today): `afrotek.co.za` for product svc; `api.afrotek.co.za` ALB with :80→:443 redirect.
- **prod** (later): `www.afrotek.co.za`, `api.afrotek.co.za`.

**DNS/Certificates**
- ACM (af-south-1) certificate: `api.afrotek.co.za` (validated).
- ALB listeners: 80 (HTTP) redirect → 443 (HTTPS).

---

## 4) Service Conventions

### Health endpoints
- Canonical: `GET /health` → `{ ok: true, rev: <APP_REV> }` (uncacheable, HSTS).
- Scoped: `GET /<svc>/health` for dashboards.

### Release metadata
- Env var **`APP_REV`** set by deploy; exposed as `rev` header/body.
- Image pinning by **ECR digest** (immutable).

---

## 5) CI/CD & Deploy

- GitHub Actions: build, push to ECR, update ECS service.
- Script: `scripts/deploy-product.ps1` supports digest pin & APP_REV bump; can auto-read version from `package.json`.
- Observability: CW alarms for UnHealthyHostCount & 5XX; EventBridge→SNS for ECS deploy failures.

---

## 6) Configuration (env)

Create `.env` files or SSM parameters. **Never commit secrets.**

```ini
# Common
NODE_ENV=production
APP_REV=auto-by-deploy
LOG_LEVEL=info

# Paystack
PAYSTACK_SECRET_KEY=
PAYSTACK_PUBLIC_KEY=

# Shipping
PARGO_API_KEY=
BOBGO_API_KEY=

# Email
MAILGUN_DOMAIN=
MAILGUN_API_KEY=

# Auth
JWT_SECRET=
SESSION_TTL=604800
```

---

## 7) Endpoints (current)

- **Product**: `/health`, `/product/health`
- **Auth**: `/health`, `/auth/health`

---

## 8) Local Dev

```bash
# product-service
cd services/product-service && npm i && npm run dev
# auth-service
cd services/auth && uvicorn app.main:app --reload --host 0.0.0.0 --port 3001
# nuxt
cd frontend/nuxt-app && npm i && npm run dev
```

---

## 9) Roadmap / TODO (running)

### Platform
- [ ] Terraform IaC for VPC, ECS, ECR, ALB, Route53, ACM, CloudWatch.
- [ ] Add SSM Parameter Store & per-service secret wiring.
- [ ] CloudFront in front of ALB for caching & WAF.
- [ ] Dual-stack (IPv4/IPv6) ALB + AAAA Route53 record.

### Product
- [ ] Domain models (Device, Listing, Seller, Order, Grade).
- [ ] CRUD + validation; CSV import for seed listings.
- [ ] Search adapter (OpenSearch/Algolia) with filters like grade/price/state.

### Auth
- [ ] JWT & refresh tokens, password reset, email verify.
- [ ] Admin roles (seller vs buyer).

### Frontend
- [ ] Back Market style catalog & PDP; compare & condition badges.
- [ ] Checkout skeleton wired to Paystack sandbox.

### Integrations
- [ ] Paystack intents + webhook verifier endpoint.
- [ ] Pargo/BobGo rate quote + label purchase flow.

### Quality
- [ ] Unit tests (Vitest / Pytest) + integration tests (Playwright).
- [ ] Sentry + structured logs.

---

## 10) Ownership
- **Product/Infra**: Abel Sibusiso Khoza (@afrotekofficial)
- **Partner (AI)**: "Tebatso Khoza" (ChatGPT)

---

## 11) References
- See `infra/`, `services/`, `frontend/`, and GitHub Actions under `.github/workflows/`.

