# 🗺️ Project Roadmap — **stream-retail-etl** (Local-first → Cloud-ready)

---

## Phase 1 — Local skeleton ✅ (done)

**Goal:** One-command local stack.  
**Deliverables:**

- Compose stack (Kafka KRaft, Postgres, Producer)
- Prometheus + Grafana
- README
- ADRs
- CI skeleton

**Tag:** `v0.1.0`

---

## Phase 2 — Persistence & observability *(in progress)*

**Goal:** Land events in Postgres via Kafka Connect and see health in Grafana.

**Deliverables:**

- ✅ Kafka Connect + JDBC Sink with auto-registration (value schemas enabled)
- ✅ Kafka & Postgres exporters + Prometheus scrapes
- ⏳ Grafana dashboards & alerts (throughput, consumer lag, rows/sec, connector/task errors)
- ⏳ Smoke-test & CI checks (row growth, connector RUNNING, targets UP)
- ⏳ Operator controls (minimal): pause/resume producer; adjust `RATE_PER_SEC` at runtime; safety cap

**Acceptance:**

- Rows increasing in `sales_raw`
- Connector status RUNNING with task RUNNING
- Prometheus targets UP
- Grafana shows starter panels
- Ability to pause/resume ingestion and change rate safely

**Tag (on completion):** `v0.2.0`

---

## Phase 3 — Stream processing *(real-time views)*

**Goal:** Transform raw events into useful aggregates in-stream.

**Choice:** ksqlDB (SQL-like) for teachability; fallback: Postgres materialized views if ksqlDB is skipped.

**Deliverables:**

- ksqlDB service + statements for `sales_hourly`, `top_skus`, `store_rolling_1h`
- *(Optional)* `sales_agg_minute` topic/table feeding dashboards

**Acceptance:**

- Derived Kafka topics and Postgres tables populated
- Dashboards show aggregates

**Tag:** `v0.3.0`

---

## Phase 4 — Data model & performance hardening

**Goal:** Keep Postgres fast and tidy at 1M+/day.

**Deliverables:**

- Native daily partitioning of `sales_raw`
- Essential indexes + retention job
- Optional upsert semantics (`pk.mode=record_key` + `insert.mode=upsert`)
- Query tuning + connection limits

**Acceptance:**

- P95 event-to-row < 5s
- Connector lag < 60s
- Key query P95 < 300 ms

**Tag:** `v0.4.0`

---

## Phase 5 — Load testing, reliability & ops UX

**Goal:** Prove throughput and stability; improve day-2 ops.

**Deliverables:**

- Producer load profiles (1×, 5×), k6 test script
- Backpressure & error-budget alerts in Prometheus
- ⏳ Lightweight web control panel (pause/resume, rate slider, safe limits, plain-language help)

**Acceptance:**

- Sustained 1M+/day with SLOs met
- Alerts fire correctly
- Control panel safely governs flow

**Tag:** `v0.5.0`

---

## Phase 6 — Cloud deployment

**Goal:** Same pipeline in the cloud.

**Deliverables:**

- **Path A:** Remote VM with Docker Compose + secrets + backups
- **Path B:** Kubernetes (Strimzi for Kafka, Helm charts; Postgres via RDS/Cloud SQL)

**Acceptance:**

- One-command deploy to chosen environment
- Runbook + cost notes

**Tag:** `v0.6.0`

---

## Phase 7 — Security & governance

**Goal:** Production-grade hygiene.

**Deliverables:**

- Network policies
- Least-privilege DB role
- Rotated secrets
- TLS/SASL for Kafka (cloud)
- Backup/restore runbook
- Audit logging
- Minimal GDPR DPIA notes

**Acceptance:**

- Checklist passed
- Restore drill succeeds

**Tag:** `v0.7.0`

---

## Phase 8 — Packaging & teaching materials

**Goal:** Make this a showcase + learning kit.

**Deliverables:**

- Step-by-step labs
- Annotated dashboards
- Demo script
- Slides
- “Why these choices” brief
- Short walkthrough video

**Acceptance:**

- New dev can go from zero → demo in ≤ 15 minutes
- Clear talking points for interviews

**Tag:** `v1.0.0`

---

## *(Optional)* Phase 9 — Analytics/ML add-on

**Goal:** Extra sparkle.

**Deliverables:**

- Simple demand-forecasting notebook from `sales_hourly`
- Or anomaly alerts

**Acceptance:**

- Reproducible notebook + Grafana panel

**Tag:** `v1.1.0`
