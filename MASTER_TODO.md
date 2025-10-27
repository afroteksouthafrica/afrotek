# Afrotek — Master TODO (living plan)

_Saved by the assistant on 2025-10-24. This file contains the agreed program plan and standing preferences to follow for the Afrotek project._

Standing preferences
--------------------
- Market: South Africa (SA)
- Product style: Build like Back Market — marketplace + seller portal + 1-year warranty + 30-day returns + trade-in
- Default stack: Nuxt (frontend) + FastAPI microservices (backend) + Postgres/Redis + RabbitMQ
- Cloud: AWS af-south-1 using Terraform
- Observability: Datadog + Sentry
- Integrations: Paystack, Twilio, Bobgo, Pargo
- No canvas usage

Master TODO (live board)
========================

Legend: 🟡 Pending · 🔵 In Progress · ✅ Done

Program Setup & Foundations

* 🔵 Define repo & folder layout (mono-repo)
* 🟡 Create GitHub repo(s) and protection rules (main branch, PR checks)
* 🟡 Author global CONTRIBUTING.md, CODEOWNERS, PR templates
* 🟡 Initialize CI (GitHub Actions) for lint/test/build (frontend + services)
* 🟡 Terraform scaffold (AWS af-south-1): VPC, subnets, RDS Postgres, ElastiCache Redis, MQ (RabbitMQ on AWS MQ), S3, ECR, ECS or EKS baseline, CloudFront + ACM, IAM/OIDC for Actions
* 🟡 Observability baseline: Sentry DSNs, Datadog org keys, log drains

Frontend (Nuxt 3 + TS)

* 🟡 Bootstrap Nuxt app (SSR/hybrid) with Tailwind + Pinia + vue-i18n (en first)
* 🟡 Global UI: header/nav, footer, auth modals, cookie/consent
* 🟡 Catalog pages: PLP with filters (brand/model/storage/condition/price), PDP with grading + warranty
* 🟡 Cart/checkout, orders page, returns start flow
* 🟡 Seller portal (web) shell: inventory list/upload, pricing, orders
* 🟡 CMS wiring (Contentful/Strapi) for Help/FAQ/Journal

Backend Microservices (FastAPI)

* 🟡 Auth/User (JWT/OAuth2, profiles, addresses, roles: buyer/seller/admin)
* 🟡 Catalog (products, categories, specs, media, grading)
* 🟡 Inventory/Warehouse (stock, inspection 25-point, grades, barcodes/QR)
* 🟡 Orders/Checkout (cart, VAT, invoices, webhooks)
* 🟡 Payments (Paystack first; later PayFast/Peach if needed)
* 🟡 Trade-in (quote engine, intake, labels, payouts)
* 🟡 Shipping (Bobgo + Pargo integration; labels, rates, tracking, returns)
* 🟡 Notifications (email/SMS via SES/Twilio; templates + events)
* 🟡 Search (Algolia/Elasticsearch) + recommendations (phase 2)

Data & Compliance

* 🟡 Postgres schemas & migrations (Alembic)
* 🟡 Redis caches (sessions, listings)
* 🟡 POPIA compliance: data retention, encryption at rest/flight, DSR workflows
* 🟡 Audit logging & admin moderation

Go-Live

* 🟡 Seed data (brands/models/variants, sample inventory)
* 🟡 E2E tests on critical flows (browse→filter→PDP→cart→pay→fulfil)
* 🟡 SLOs/alerts (payments, checkout, latency, error rate)
* 🟡 DNS, TLS, CDN, soft launch

30-Day Plan (solo founder + AI assist)
-------------------------------------

Week 1 — Architecture & Scaffolding
* Day 1–2: Create mono-repo layout, base READMEs, commit lint, pre-commit hooks.
* Day 3–4: Nuxt 3 app init (TS, Tailwind, Pinia), layout + auth UI shell.
* Day 5–7: FastAPI boilerplates (auth, catalog), Postgres + Alembic, Redis, OpenAPI contracts, CI.

Week 2 — Core Domain (Catalog, Auth, Inventory)
* Day 8–10: Auth service: email+password, JWT, refresh, roles, rate limits.
* Day 11–14: Catalog data model, media upload (S3 presigned), Inventory service and frontend PLP/PDP.

Week 3 — Orders, Payments, Logistics, Trade-in
* Day 15–17: Orders service, payments integration (Paystack), invoice generation.
* Day 18–19: Shipping integrations (Bobgo, Pargo), returns RMA model.
* Day 20–21: Trade-in MVP.

Week 4 — Seller/Admin, CMS, Hardening & Launch
* Day 22–24: Seller portal MVP, admin moderation.
* Day 25–27: CMS, search indexing, rate limiting.
* Day 28–30: Load testing, Terraform apply, DNS/TLS/CDN, soft-launch.

Start Today checklist
---------------------
1. Create mono-repo (starter)
2. Frontend scaffold (Nuxt + Tailwind + Pinia)
3. Backend scaffold (FastAPI services skeletons)
4. Env templates (.env.example)
5. GitHub Actions CI skeleton
6. Terraform infra skeleton

If you want, the assistant will now create:
- Nuxt starter with Tailwind config (frontend/nuxt-app files)
- Reusable FastAPI service template (services/common/template)
- Initial Terraform module skeletons (infra/terraform/modules)

---

Notes about persistence
----------------------
I (the assistant) saved this plan to the repository at `MASTER_TODO.md`. I cannot permanently "remember" outside this workspace/session, but storing the plan in the repo ensures it's versioned and available to collaborators and CI.

---
If you want me to generate the 3 starter artifacts now, reply with `generate all` or pick which ones: `nuxt`, `fastapi`, `terraform`.
