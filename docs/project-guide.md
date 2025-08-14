# Project Guide — **stream-retail-etl**

This guide is your single source of truth for running, understanding, and verifying the project. It serves both non-technical and technical readers: plain explanations first, exact commands and paths when you need them.

---

## 1) What this project does (plain-language)

We simulate retail sales events (e.g., “Store 42 sold 2 units of SKU 1234 at 10:32:15”).  
Events go into **Kafka** (a fast mailbox), then flow into **PostgreSQL** via **Kafka Connect (JDBC Sink)**.  
**Prometheus** + **Grafana** provide health and basic metrics.

Run everything locally with one command.

**Outcome:** a local, real-time streaming ETL pipeline that can process ~1M events/day and is cloud-ready later.

---

## 2) Prerequisites

### Hardware

- ≥ 4 GB free RAM for Docker (8 GB recommended).
- Stable internet (first run pulls container images).

### Software

- Docker (Desktop on macOS/Windows; Engine on Linux) with Docker Compose.
- **Windows:** use WSL2; run commands in Ubuntu shell.
- Git (optional but recommended).

### Ports used (ensure they’re free)

- Kafka: `9092`
- PostgreSQL: `5432`
- Kafka Connect (REST): `8083`
- Prometheus: `9090`
- Grafana: `3000`
- Exporters: Kafka `9308`, Postgres `9187`

---

## 3) Project structure (what’s where)

```
stream-retail-etl/
├─ docker-compose.yml              # main compose (root-level)
├─ .env.example                    # copy to .env (auto-loaded by Compose)
├─ compose/
│  ├─ prometheus.yml               # Prometheus scrape config (single source)
│  ├─ connect/
│  │  └─ Dockerfile                # builds Connect with JDBC plugin preinstalled
│  ├─ connectors/
│  │  ├─ pg_sink.json              # JDBC sink → sales_raw (always registered)
│  │  ├─ pg_agg_sink.json          # JDBC sink → sales_agg_minute (opt-in)
│  │  └─ register.sh               # idempotent registration script
│  └─ grafana/
│     └─ provisioning/
│        ├─ datasources/datasource.yml
│        ├─ dashboards/dashboards.yml
│        ├─ dashboards/stream_retail.json
│        └─ alerting/alert.yml
├─ ksql/
│  └─ statements.sql               # Phase 3 transforms; mounted when ksql profile on
├─ sql/                            # single SQL home
│  ├─ 01_sales_raw.sql             # base table used by raw sink
│  ├─ 02_indexes.sql               # indexes for sales_raw
│  └─ 03_sales_agg_minute.sql      # aggregate table
├─ producer/
│  ├─ app.py                       # synthetic events generator
│  ├─ requirements.txt
│  └─ Dockerfile
└─ docs/
   ├─ README.md
   ├─ project-guide.md
   ├─ project-roadmap.md
   ├─ journal.md
   └─ adr/
      ├─ 0001-choice-of-stack.md
      ├─ 0002-kraft-cluster-id.md
      ├─ 0003-kafka-connect-jdbc-sink.md
      └─ 0004-observability-exporters.md
```

---

## 4) Quick start (TL;DR)

```bash
git clone https://github.com/vbchivu/stream-retail-etl.git
cd stream-retail-etl

cp compose/.env.example compose/.env
# edit compose/.env and set:
# PGUSER=retail
# PGPASSWORD=retail_pw

docker compose -f compose/docker-compose.yml up --build -d
```

Open:

- Grafana → [http://localhost:3000](http://localhost:3000) (login `admin` / `admin`)
- Prometheus → [http://localhost:9090](http://localhost:9090)

First startup can take 1–3 minutes while images download. That’s normal.

---

## 5) Data model & flow

### 5.1 Event shape (producer → Kafka topic `sales`)

```json
{"event_id":"<uuid>","store_id":42,"sku":1234,"qty":2,"ts":1723456789000}
```

`ts` is epoch milliseconds.

### 5.2 PostgreSQL target (JDBC Sink → table `sales_raw`)

Current columns (from Phase 2 DDL):

- `event_id` TEXT
- `store_id` INT
- `sku` INT
- `qty` INT
- `ts` BIGINT (epoch ms)

The JDBC sink has value schemas enabled, which avoids schema-less insert errors. Keys are schema-less (fine for simple inserts).

### 5.3 Aggregates

`sales_agg_minute` belongs to Phase 3 (ksqlDB). It will be empty/not present until we enable stream processing.

---

## 6) Verifying it’s working

### 6.1 Containers are up

```bash
docker compose -f compose/docker-compose.yml ps
```

Look for STATUS `"Up"` on:

- kafka, postgres, kafka-connect, producer, prometheus, grafana, kafka-exporter, postgres-exporter

### 6.2 Kafka Connect is running and the connector is registered

```bash
curl -s http://localhost:8083/connectors | jq .
curl -s http://localhost:8083/connectors/pg-sales-jdbc-sink/status | jq .
```

Expect `"state": "RUNNING"` for connector and task.

### 6.3 Rows are flowing into Postgres

```bash
docker compose exec postgres   psql -U $PGUSER -d retail_ops -c "SELECT COUNT(*) FROM sales_raw;"
```

Run again after ~10–20 seconds — count should increase.

### 6.4 Prometheus is scraping targets

Open Prometheus → Status → Targets. You should see:

- prometheus (UP)
- kafka_exporter (UP)
- postgres_exporter (UP)

Technical quick check:

```bash
curl -s http://localhost:9090/api/v1/targets   | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

### 6.5 Grafana reachable

[http://localhost:3000](http://localhost:3000) → login `admin` / `admin`.

(Optional) Add Prometheus datasource: `http://prometheus:9090`.

**Success criteria recap:**

- All containers Up
- Connector RUNNING
- `sales_raw` count increasing
- Prometheus targets UP
- Grafana reachable

---

## 7) Control levers (pause/resume & rate)

### 7.1 Producer (data generation)

- Pause: `docker compose stop producer`
- Resume: `docker compose start producer`
- Change rate (default `RATE_PER_SEC=15`):  
  Edit `compose/docker-compose.yml` → `producer.environment.RATE_PER_SEC`  
  Then:  

  ```bash
  docker compose up -d --build producer
  ```

### 7.2 JDBC Sink connector

Pause:

```bash
curl -X PUT http://localhost:8083/connectors/pg-sales-jdbc-sink/pause
```

Resume:

```bash
curl -X PUT http://localhost:8083/connectors/pg-sales-jdbc-sink/resume
```

Restart task:

```bash
curl -X POST http://localhost:8083/connectors/pg-sales-jdbc-sink/restart
```

Delete / Recreate:

```bash
curl -X DELETE http://localhost:8083/connectors/pg-sales-jdbc-sink || true
```

---

## 8) Configuration you can change

In `compose/docker-compose.yml`:

**Producer speed:**

```yaml
producer:
  environment:
    RATE_PER_SEC: 15   # try 5 or 50
```

**Kafka essentials (pre-set):**

```yaml
CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qk"
KAFKA_NODE_ID: 1
```

**Ports (change host side if there are conflicts):**

```yaml
ports:
  - "3000:3000"  # change to "3300:3000" if 3000 is busy
```

In `compose/connectors/pg_sink.json`:

- Destination table (defaults to `sales_raw`)
- Insert mode (currently `insert`; Phase 4 may switch to `upsert`)
- Batch sizing, `auto.create`/`evolve` flags

---

## 9) Common operations

Start:

```bash
docker compose -f compose/docker-compose.yml up -d
```

Stop:

```bash
docker compose -f compose/docker-compose.yml down
```

Rebuild:

```bash
docker compose -f compose/docker-compose.yml up --build -d
```

Clean everything (drops volumes):

```bash
docker compose -f compose/docker-compose.yml down -v
```

Tail logs:

```bash
docker compose logs -f kafka
docker compose logs -f kafka-connect
docker compose logs -f producer
```

---

## 10) Troubleshooting

**A) Kafka Connect 404 for connector**  
Registration may not have finished. Wait 10–20s, then:

```bash
curl -s http://localhost:8083/connectors | jq .
```

**B) `sales_raw` stays at 0**  
Check connector status/logs:

```bash
curl -s http://localhost:8083/connectors/pg-sales-jdbc-sink/status | jq .
docker compose logs -f kafka-connect
```

Check producer:

```bash
docker compose logs -f producer
```

**C) Port in use**  
Change left side of mapping (e.g., `55432:5432`) and re-up.

**D) Prometheus file mount error**  
Ensure `compose/prometheus.yml` exists and mapping is:

```yaml
- ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
```

**E) Windows path / WSL2**  
Run from WSL Ubuntu shell. Keep project under `/home/<you>/...`, not under `C:\`.

**F) “NotCoordinator” flaps in Connect at startup**  
Harmless during first seconds. They settle once the group forms.

---

## 11) Security & persistence (dev notes)

- Dev-only credentials live in `compose/.env`. Don’t commit real secrets.
- Containers run as non-root where possible.
- Data persists in Docker volumes:
  - Postgres: `pgdata`
  - Grafana: `grafana-data`
- Resetting state: `docker compose down -v` clears all volumes.

---

## 12) What’s intentionally not there (yet)

- ksqlDB & aggregates (`sales_agg_minute`) — planned in Phase 3.
- Grafana dashboards and Prometheus alerts — planned next.
- Fine-grained DB schema management (migrations/partitions) — Phase 4.

---

## 13) Next steps (high level)

- Control UI: small web app to pause/resume producer & connector, adjust rate.
- Dashboards: Grafana JSON for throughput, consumer lag, rows/sec, connector errors.
- Alerts: Prometheus rules for connector failures, consumer lag, and zero-ingest detection.
- Stream processing: enable ksqlDB; materialize `sales_agg_minute`; optionally sink aggregates to Postgres.
- DB hygiene: partition `sales_raw` by day; add indexes; retention.
- CI checks: ensure connector RUNNING and row count growth on each PR.
